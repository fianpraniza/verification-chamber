import ARKit
import SceneKit
import SwiftUI

enum ModeScan: String { case box, tumpuk, pegang }

/// Pengukuran wadah gaya app Measure: tanda bidik di tengah layar, tekan + di ujung awal dan + di ujung akhir.
/// Supaya akurat tanpa LiDAR:
/// 1. Semua titik dikunci ke bidang tutup box (garis bidik dipotong dengan bidang datar setinggi tutup), jadi titik di sudut
///    tidak "jatuh" ke lantai walaupun bidang tutup yang terdeteksi tidak sampai ke sudut.
/// 2. Tinggi = tinggi tutup − tinggi lantai (dua bidang ARKit), cukup satu tekan; tidak perlu membidik sudut bawah.
/// 3. Titik = median N frame terakhir, bukan satu frame.
/// Kondisi yang membuat ukuran meleset (tracking, cahaya, jarak, sudut, goyang) dicek tiap frame dan ditampilkan sebagai petunjuk.
/// Box: panjang, lebar, tinggi. Tumpuk: tinggi tumpukan. Pegang: tinggi kamera di atas lantai.
final class PengukurAR: NSObject, ObservableObject, ARSessionDelegate {
    struct Garis { var a: SIMD3<Float>; var b: SIMD3<Float>; var cm: Double { Double(simd_distance(a, b)) * 100 } }
    struct GarisLayar { var a: CGPoint; var b: CGPoint; var teks: String }

    @Published private(set) var garis: [Garis] = []
    @Published private(set) var awal: SIMD3<Float>?          // ujung awal garis yang sedang dibuat
    @Published private(set) var bidik: SIMD3<Float>?         // titik di tutup box pada tanda bidik (sudah dihaluskan)
    @Published private(set) var petunjuk: String?            // nil = kondisi siap ukur
    @Published private(set) var layar: [GarisLayar] = []     // garis selesai + garis live, koordinat layar
    @Published private(set) var titikLayar: [CGPoint] = []
    @Published private(set) var jarakCM: Double?
    @Published private(set) var lolosPegang = false
    @Published private(set) var petunjukPegang: String?
    @Published private(set) var info: [(String, String)] = []
    var viewport = CGSize(width: 390, height: 844)

    let session = ARSession()
    let mode: ModeScan
    private let a = AmbangVerifikasi.sekarang
    private var tercatat = false, tahanSejak: Date?
    private let lidar = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    private var lantaiY: Float?
    private var tutup: (id: UUID, y: Float)?                 // bidang tutup box; dikunci sejak titik pertama
    private var riwayat: [SIMD3<Float>] = []                 // bidikan mentah N frame terakhir
    private var kondisiTap: [String] = []                    // petunjuk saat tiap + ditekan, untuk log

    init(mode: ModeScan) { self.mode = mode }

    var nama: [String] { mode == .box ? ["Panjang", "Lebar", "Tinggi"] : ["Tinggi tumpukan"] }
    var selesai: Bool { mode != .pegang && garis.count == nama.count }
    /// Tinggi diukur dengan satu tekan: titik di tutup, ujung bawah diturunkan ke lantai.
    var satuTap: Bool { mode == .tumpuk || garis.count == 2 }

    var ukuran: UkuranBox? {
        guard mode == .box, selesai else { return nil }
        return UkuranBox(panjang: garis[0].cm, lebar: garis[1].cm, tinggi: garis[2].cm)
    }

    var lolos: Bool {
        switch mode {
        case .box: ukuran.map { Rumus.cekSpesifikasi($0, a: a).isEmpty } ?? false
        case .tumpuk: jarakCM.map(a.jarakKameraKeDasarCM.berisi) ?? false
        case .pegang: lolosPegang
        }
    }

    var langkah: String {
        if mode == .pegang { return "Arahkan HP ke lantai sampai lantai terdeteksi, lalu pegang HP di atas box seperti saat menghitung." }
        if selesai { return "Selesai. Tekan Lanjut, atau Ulangi kalau angkanya meleset." }
        let ujung = awal == nil ? "Tekan + di sudut pertama." : "Geser pelan ke sudut berikutnya, tekan + lagi."
        switch (mode, garis.count) {
        case (.box, 0): return "Ukur PANJANG di tutup box: sisi panjang, sudut ke sudut. \(ujung)"
        case (.box, 1): return "Ukur LEBAR di tutup box: sisi pendek, sudut ke sudut. \(ujung)"
        case (.box, 2): return "Ukur TINGGI: bidik tutup box dekat sudut, tekan +. Tinggi dari lantai dihitung otomatis."
        default: return "Ukur TINGGI tumpukan: bidik tutup box paling atas, tekan +. Tinggi dari lantai dihitung otomatis."
        }
    }

    func mulai() {
        let c = ARWorldTrackingConfiguration()
        c.planeDetection = [.horizontal]
        if lidar, ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { c.frameSemantics.insert(.sceneDepth) }
        session.delegate = self
        session.run(c, options: [.resetTracking, .removeExistingAnchors])
    }

    func tambah() {
        guard let b = bidik, !selesai else { return }
        kondisiTap.append(petunjuk ?? "siap")
        if satuTap, let l = lantaiY { garis.append(Garis(a: SIMD3(b.x, l, b.z), b: b)) }
        else if let a0 = awal { garis.append(Garis(a: a0, b: b)); awal = nil } else { awal = b }
        if mode == .tumpuk, selesai { jarakCM = Rumus.jarakTaruh(tinggiTumpukanCM: garis[0].cm, a: a) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func batal() {
        if awal != nil { awal = nil } else if !garis.isEmpty { garis.removeLast() }
        if mode == .tumpuk { jarakCM = nil }
    }

    func ulangi() { garis = []; awal = nil; riwayat = []; if mode == .tumpuk { jarakCM = nil } }

    /// Wajib dipanggil sebelum AVCaptureSession dimulai: ARKit dan AVCaptureSession tidak bisa memakai kamera bersamaan.
    /// Setiap percobaan dicatat sekali di log, lolos maupun tidak.
    func berhenti(lanjut: Bool = false) {
        session.pause()
        guard !tercatat else { return }
        tercatat = true
        var t: [String: Any] = ["mode": mode.rawValue, "lanjut": lanjut, "lolos": lolos, "garisCM": garis.map(\.cm),
                                "info": Dictionary(info.map { ($0.0, $0.1) }) { $1 }, "kondisiTap": kondisiTap]
        if let d = jarakCM { t["jarakCM"] = d }
        ShrimpWatch.catat("scan", tambahan: t)
    }

    func session(_ s: ARSession, didUpdate frame: ARFrame) {
        let datar = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .horizontal }
        let lantai = datar.map { $0.transform.columns.3.y }.min()
        lantaiY = lantai
        var baris = [("tracking", Self.teks(frame.camera.trackingState)), ("lantai", lantai == nil ? "belum" : "terdeteksi"),
                     ("LiDAR", lidar ? "ya" : "tidak")]
        defer { info = baris }

        if mode == .pegang {
            guard let lantai else { petunjukPegang = "Arahkan HP ke lantai dulu"; return }
            let d = Rumus.jarakPegang(kameraY: Double(frame.camera.transform.columns.3.y), lantaiY: Double(lantai), a: a)
            jarakCM = d
            baris.append(("jarak cm", "\(angka(d)) (\(angka(a.jarakKameraKeDasarCM.min, 0))–\(angka(a.jarakKameraKeDasarCM.max, 0)))"))
            if lolosPegang { return }
            if a.jarakKameraKeDasarCM.berisi(d) {
                tahanSejak = tahanSejak ?? Date()
                lolosPegang = Date().timeIntervalSince(tahanSejak!) >= 1
                petunjukPegang = lolosPegang ? "Jarak sesuai ✓" : "Tahan…"
            } else {
                tahanSejak = nil
                petunjukPegang = d < a.jarakKameraKeDasarCM.min ? "Naikkan HP" : "Turunkan HP"
            }
            return
        }

        // Garis bidik dari tanda bidik (tengah layar). Bidang tutup = bidang datar yang dikenai garis ini dan cukup tinggi di atas lantai.
        // Bidang tutup dipilih ulang selama belum ada titik; sejak titik pertama dikunci, hanya tingginya yang ikut diperbarui ARKit.
        let tengah = CGPoint(x: 0.5, y: 0.5).applying(frame.displayTransform(for: .portrait, viewportSize: viewport).inverted())
        let q = frame.raycastQuery(from: tengah, allowing: .existingPlaneGeometry, alignment: .horizontal)
        let kena = session.raycast(q).first?.anchor as? ARPlaneAnchor
        let minTutup = Float(a.arkit.minTinggiTutupCM / 100)
        if let t = tutup, let p = datar.first(where: { $0.identifier == t.id }) { tutup?.y = p.transform.columns.3.y }
        if awal == nil, garis.isEmpty, let k = kena, let l = lantai, k.transform.columns.3.y - l >= minTutup {
            tutup = (k.identifier, k.transform.columns.3.y)
        }

        let mentah = selesai ? nil : tutup.flatMap { Rumus.potongDatar(asal: q.origin, arah: q.direction, y: $0.y) }
        if let m = mentah { riwayat = Array((riwayat + [m]).suffix(a.arkit.frameHalus)) } else { riwayat = [] }
        let halus = Rumus.halus(riwayat)
        bidik = halus?.titik

        let kam = frame.camera.transform.columns.3.xyz
        let jarak = bidik.map { Double(simd_distance(kam, $0)) * 100 }
        let sudut = Rumus.sudutBidik(q.direction)
        let k = KondisiUkur(
            tracking: Self.tracking(frame.camera.trackingState), cahayaLumen: frame.lightEstimate.map { Double($0.ambientIntensity) },
            adaLantai: lantai != nil, adaTutup: tutup != nil,
            bidikLantai: tutup == nil && kena.map { b in lantai.map { b.transform.columns.3.y - $0 < minTutup } ?? false } ?? false,
            jarakCM: jarak, sudutDerajat: bidik == nil ? nil : sudut, goyangCM: halus?.goyangCM)
        petunjuk = selesai ? nil : petunjukUkur(k, a: a)

        baris += [("tutup box", tutup.map { t in lantai.map { "\(angka(Double(t.y - $0) * 100)) cm di atas lantai" } ?? "ya" } ?? "belum"),
                  ("cahaya", k.cahayaLumen.map { angka($0, 0) } ?? "-"),
                  ("jarak bidik cm", jarak.map { angka($0, 0) } ?? "-"),
                  ("sudut bidik", "\(angka(sudut, 0))°"),
                  ("goyang cm", halus.map { angka($0.goyangCM, 2) } ?? "-")]

        func p(_ x: SIMD3<Float>) -> CGPoint { frame.camera.projectPoint(x, orientation: .portrait, viewportSize: viewport) }
        var l = garis.enumerated().map { GarisLayar(a: p($1.a), b: p($1.b), teks: "\(nama[$0]) \(angka($1.cm)) cm") }
        if let b = bidik {
            let a0 = satuTap ? lantai.map { SIMD3(b.x, $0, b.z) } : awal
            if let a0 { l.append(GarisLayar(a: p(a0), b: p(b), teks: "\(angka(Double(simd_distance(a0, b)) * 100)) cm")) }
        }
        layar = l
        titikLayar = garis.flatMap { [p($0.a), p($0.b)] } + (awal.map { [p($0)] } ?? [])
        for (i, g) in garis.enumerated() { baris.append(("\(nama[i].lowercased()) cm", angka(g.cm))) }
    }

    private static func tracking(_ s: ARCamera.TrackingState) -> TrackingUkur {
        switch s {
        case .normal: .normal
        case .limited(.excessiveMotion): .cepat
        case .limited(.insufficientFeatures): .polos
        default: .mulai
        }
    }

    private static func teks(_ s: ARCamera.TrackingState) -> String {
        switch s {
        case .normal: "normal"
        case .notAvailable: "tidak tersedia"
        case .limited(let r): r == .excessiveMotion ? "terbatas (HP terlalu cepat)" : r == .insufficientFeatures ? "terbatas (kurang tekstur)" : "terbatas"
        }
    }
}

struct PratinjauAR: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView()
        v.session = session
        return v
    }

    func updateUIView(_ v: ARSCNView, context: Context) {}
}

/// Layar ukur ARKit. `onLanjut` dipanggil SETELAH ARSession di-pause, jadi layar berikutnya boleh langsung memakai kamera.
struct LayarScan: View {
    let mode: ModeScan
    let onLanjut: (UkuranBox?, Double?) -> Void
    @StateObject private var ar: PengukurAR
    @AppStorage("gerbangPeringatan") private var uji = false
    private let a = AmbangVerifikasi.sekarang

    init(mode: ModeScan, onLanjut: @escaping (UkuranBox?, Double?) -> Void) {
        self.mode = mode
        self.onLanjut = onLanjut
        _ar = StateObject(wrappedValue: PengukurAR(mode: mode))
    }

    private var gagalSpek: [String] { ar.ukuran.map { Rumus.cekSpesifikasi($0, a: a) } ?? [] }
    private var bolehLanjut: Bool { ar.lolos || (uji && (ar.selesai || ar.jarakCM != nil)) }

    var body: some View {
        if !ARWorldTrackingConfiguration.isSupported {
            VStack(spacing: 16) {
                ContentUnavailableView("ARKit tidak tersedia", systemImage: "arkit",
                                       description: Text("Pengukuran wadah butuh iPhone asli. Simulator tidak didukung."))
                if uji {
                    Button("Lewati dengan ukuran nominal (mode uji)") {
                        onLanjut(UkuranBox(panjang: a.boxPanjangLuarCM.nominal ?? 52, lebar: a.boxLebarLuarCM.nominal ?? 37, tinggi: a.boxTinggiLuarCM.nominal ?? 34),
                                 Rumus.jarakTaruh(tinggiTumpukanCM: 2 * (a.boxTinggiLuarCM.nominal ?? 34), a: a))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else {
            ZStack(alignment: .top) {
                GeometryReader { g in
                    ZStack {
                        PratinjauAR(session: ar.session)
                        gambarGaris
                        if mode != .pegang, !ar.selesai {   // tanda bidik: putih = siap, kuning = ada kondisi tidak akurat, abu = belum di tutup box
                            let w: Color = ar.bidik == nil ? .gray : ar.petunjuk == nil ? .white : .yellow
                            Circle().stroke(w, lineWidth: 3).frame(width: 34, height: 34)
                                .overlay(Circle().fill(w).frame(width: 6, height: 6))
                                .shadow(radius: 2).position(x: g.size.width / 2, y: g.size.height / 2)
                        }
                    }
                    .onAppear { ar.viewport = g.size }
                    .onChange(of: g.size) { _, s in ar.viewport = s }
                }
                .ignoresSafeArea()
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ar.langkah).font(.callout.bold())
                        nilaiUtama
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    PanelNilai(baris: ar.info.map { ($0.0, $0.1, nil) })
                    Spacer()
                    if let p = ar.petunjuk, mode != .pegang {
                        Label(p, systemImage: "exclamationmark.triangle.fill").font(.callout.bold()).foregroundStyle(.yellow)
                            .padding(10).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if !gagalSpek.isEmpty {
                        Label((gagalSpek + ["Gunakan box lain."]).joined(separator: " "), systemImage: "xmark.octagon.fill")
                            .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(uji ? .yellow : .red)
                    }
                    tombol
                }
                .padding()
            }
            .onAppear { ar.mulai() }
            .onDisappear { ar.berhenti() }
        }
    }

    /// Garis yang sudah diukur dan garis live ke tanda bidik, dengan label panjangnya di tengah garis.
    private var gambarGaris: some View {
        ZStack {
            ForEach(ar.layar.indices, id: \.self) { i in
                let g = ar.layar[i]
                Path { p in p.move(to: g.a); p.addLine(to: g.b) }.stroke(.white, lineWidth: 3).shadow(radius: 1)
                Text(g.teks).font(.subheadline.bold().monospacedDigit()).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white, in: Capsule()).foregroundStyle(.black)
                    .position(x: (g.a.x + g.b.x) / 2, y: (g.a.y + g.b.y) / 2)
            }
            ForEach(ar.titikLayar.indices, id: \.self) { i in
                Circle().fill(.white).frame(width: 12, height: 12).position(ar.titikLayar[i])
            }
        }
    }

    @ViewBuilder private var tombol: some View {
        if mode == .pegang || ar.selesai {
            HStack {
                if mode != .pegang { Button("Ulangi") { ar.ulangi() }.buttonStyle(.bordered).controlSize(.large) }
                Button {
                    ar.berhenti(lanjut: true)
                    onLanjut(ar.ukuran, ar.jarakCM)
                } label: { Text(ar.lolos ? "Lanjut" : "Lanjut (gerbang gagal)").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .tint(ar.lolos ? .green : .yellow)
                .disabled(!bolehLanjut)
            }
        } else {
            HStack(spacing: 40) {
                Button { ar.batal() } label: { Image(systemName: "arrow.uturn.backward").font(.title2).frame(width: 56, height: 56) }
                    .buttonStyle(.bordered).clipShape(Circle()).disabled(ar.awal == nil && ar.garis.isEmpty)
                Button { ar.tambah() } label: { Image(systemName: "plus").font(.system(size: 34, weight: .bold)).frame(width: 76, height: 76) }
                    .buttonStyle(.borderedProminent).clipShape(Circle())
                    .disabled(ar.bidik == nil || (ar.petunjuk != nil && !uji))   // mode uji: boleh tekan walau ada peringatan
                Color.clear.frame(width: 56, height: 56)
            }
        }
    }

    @ViewBuilder private var nilaiUtama: some View {
        switch mode {
        case .box:
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    let r = [a.boxPanjangLuarCM, a.boxLebarLuarCM, a.boxTinggiLuarCM][i]
                    if i < ar.garis.count {
                        let x = ar.garis[i].cm
                        Label("\(ar.nama[i]) \(angka(x))", systemImage: r.berisi(x) ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(r.berisi(x) ? .green : .red)
                    } else {
                        Label(ar.nama[i], systemImage: "circle.dashed").foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption.bold())
        case .tumpuk, .pegang:
            if let d = ar.jarakCM {
                Text("Jarak kamera ke dasar \(angka(d)) cm").font(.title2.bold().monospacedDigit())
                    .foregroundStyle(a.jarakKameraKeDasarCM.berisi(d) ? .green : .primary)
            }
            if mode == .pegang, let t = ar.petunjukPegang { Text(t).font(.headline) }
        }
    }
}
