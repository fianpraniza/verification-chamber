import AVFoundation
import CoreMotion
import SwiftUI
import Vision

/// Foto kartu yang diambil otomatis saat daftar wadah. Semua koordinat dalam piksel frame asli sensor (landscape).
struct FotoKartu {
    var gambar: CGImage
    var sudutKartu: [CGPoint]
    var fx: Double
    var fy: Double
    var jarakCM: Double          // median koreksi tepi + koreksi kalibrasi
    var miring: Double
    var sebaranCM: Double
}

/// Jarak kamera ke dasar box dari kartu ATM yang rata di dasar (daftar wadah dan layar uji).
/// Frame dianalisis di orientasi asli sensor (landscape) supaya intrinsics dari AVFoundation berlaku langsung.
final class KameraKartu: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var sudut: [CGPoint] = []          // titik perangkat (0–1, landscape sensor) untuk overlay
    @Published private(set) var jarakCM: Double?               // median N deteksi terakhir, sudut dari deteksi ulang di sekitar kartu
    @Published private(set) var jarakKoreksiCM: Double?        // median, sudut yang sama + koreksi tepi dari rasio kartu
    @Published private(set) var jarakKasarCM: Double?          // median, sudut dari deteksi seluruh frame (cara uji pertama)
    @Published private(set) var sebaranCM: Double?
    @Published private(set) var jumlah = 0                     // deteksi kartu berturut-turut (maks frameHalus)
    @Published private(set) var kartu: HasilKartu?
    @Published private(set) var miring = 0.0
    @Published private(set) var status: String? = "Menyiapkan kamera…"
    @Published private(set) var info: [(String, String)] = []

    let session = AVCaptureSession()
    private let a = AmbangVerifikasi.sekarang
    private let video = AVCaptureVideoDataOutput()
    private let antrian = DispatchQueue(label: "kameraKartu")
    private let gerak = CMMotionManager()
    private var device: AVCaptureDevice?
    private var nFrame = 0, intrinsik = false
    private var riwayat: [(tajam: Double, koreksi: Double, kasar: Double)] = []
    private(set) var catatan: [String: Any] = [:]              // nilai frame terakhir untuk log
    private var terakhir: (pb: CVPixelBuffer, sudut: [CGPoint], fx: Double, fy: Double, miring: Double)?

    /// Bekukan frame terakhir yang kartunya terbaca, beserta jarak median saat ini.
    func potret(_ selesai: @escaping (FotoKartu?) -> Void) {
        antrian.async { [self] in
            let kor = riwayat.map(\.koreksi), taj = riwayat.map(\.tajam)
            guard let t = terakhir, !kor.isEmpty,
                  let cg = CIContext().createCGImage(CIImage(cvPixelBuffer: t.pb), from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(t.pb), height: CVPixelBufferGetHeight(t.pb)))
            else { return DispatchQueue.main.async { selesai(nil) } }
            let f = FotoKartu(gambar: cg, sudutKartu: t.sudut, fx: t.fx, fy: t.fy, jarakCM: median(kor) + a.kartu.koreksiJarakCM,
                              miring: t.miring, sebaranCM: taj.max()! - taj.min()!)
            DispatchQueue.main.async { selesai(f) }
        }
    }

    func mulai() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            if ok { self.antrian.async { self.siapkan() } } else { self.lapor("Izin kamera ditolak.") }
        }
    }

    func berhenti() {
        gerak.stopDeviceMotionUpdates()
        antrian.async { self.senter(false); self.session.stopRunning() }
    }

    func senter(_ nyala: Bool) {
        guard let d = device, d.hasTorch, (try? d.lockForConfiguration()) != nil else { return }
        if nyala { try? d.setTorchModeOn(level: min(a.kamera.levelSenter, AVCaptureDevice.maxAvailableTorchLevel)) } else { d.torchMode = .off }
        d.unlockForConfiguration()
    }

    private func permintaan(minUkuran: Float) -> VNDetectRectanglesRequest {
        let r = VNDetectRectanglesRequest()
        r.minimumAspectRatio = 0.5; r.maximumAspectRatio = 0.8
        r.minimumSize = minUkuran; r.maximumObservations = 6; r.quadratureTolerance = 15
        return r
    }

    private func lapor(_ s: String?) { DispatchQueue.main.async { self.status = s } }

    private func siapkan() {
        guard let d = Lensa.perangkat(),
              let input = try? AVCaptureDeviceInput(device: d), session.canAddInput(input) else {
            return lapor("Kamera belakang tidak tersedia (Simulator tidak punya kamera).")
        }
        device = d
        session.beginConfiguration()
        session.addInput(input)
        // 4:3 seperti foto hitung, supaya dasar yang terlihat saat daftar = yang terlihat saat menghitung
        if let f = Lensa.format43(d), (try? d.lockForConfiguration()) != nil { d.activeFormat = f; d.unlockForConfiguration() }
        else { session.sessionPreset = .photo }
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: antrian)
        if session.canAddOutput(video) { session.addOutput(video) }
        if let c = video.connection(with: .video) {
            if c.isCameraIntrinsicMatrixDeliverySupported { c.isCameraIntrinsicMatrixDeliveryEnabled = true; intrinsik = true }
            if c.isVideoStabilizationSupported { c.preferredVideoStabilizationMode = .off }   // stabilisasi memotong frame dan menggeser intrinsics
        }
        session.commitConfiguration()
        Lensa.pasang(d)
        session.startRunning()
        gerak.deviceMotionUpdateInterval = 1 / 30
        gerak.startDeviceMotionUpdates()
        lapor(nil)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        nFrame += 1
        guard nFrame % 6 == 0, let pb = CMSampleBufferGetImageBuffer(sb), let d = device else { return }   // ±5× per detik
        let W = Double(CVPixelBufferGetWidth(pb)), H = Double(CVPixelBufferGetHeight(pb))

        let fxFov = Rumus.fxDariFOV(lebarPX: max(W, H), fovDerajat: Lensa.fov(d))
        var fx = fxFov, fy = fxFov, cx = W / 2, cy = H / 2
        if let data = CMGetAttachment(sb, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {
            let m = data.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
            fx = Double(m.columns.0.x); fy = Double(m.columns.1.y); cx = Double(m.columns.2.x); cy = Double(m.columns.2.y)
        }
        var mir = 0.0
        if let g = gerak.deviceMotion?.gravity {
            let n: Double = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
            mir = acos(min(1, abs(g.z) / max(n, 1e-9))) * 180 / .pi
        }

        // Lintasan 1: cari kartu di seluruh frame. Vision memperkecil frame, jadi sudutnya kasar (±19 px di luar tepi pada 4K).
        let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up)
        let semua = CGRect(x: 0, y: 0, width: 1, height: 1)
        let r = permintaan(minUkuran: 0.05)
        try? handler.perform([r])
        let target = a.kartu.panjangMM / a.kartu.lebarMM
        // Vision: 0–1 relatif terhadap `roi`, asal kiri bawah → piksel frame (asal kiri atas). Pilih yang rasionya paling dekat kartu.
        func terbaik(_ os: [VNRectangleObservation], _ roi: CGRect) -> (o: VNRectangleObservation, px: [CGPoint], h: HasilKartu)? {
            os.compactMap { o -> (VNRectangleObservation, [CGPoint], HasilKartu)? in
                let px = [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft]
                    .map { CGPoint(x: (roi.minX + $0.x * roi.width) * W, y: (1 - (roi.minY + $0.y * roi.height)) * H) }
                return Rumus.jarakKartu(px, fx: fx, fy: fy, a: a).map { (o, px, $0) }
            }.min { abs($0.2.rasio / target - 1) < abs($1.2.rasio / target - 1) }
        }
        let kasar = terbaik(r.results ?? [], semua)

        // Lintasan 2: ulangi hanya di sekitar kartu supaya Vision bekerja di resolusi lebih tinggi. Dokumentasi tidak tegas apakah
        // hasilnya relatif ke ROI atau ke frame, jadi dua tafsiran dicoba dan dipilih yang pusatnya paling dekat dengan hasil lintasan 1.
        var tajam = kasar
        if let c = kasar {
            let b = c.o.boundingBox, roi = b.insetBy(dx: -b.width * 0.2, dy: -b.height * 0.2).intersection(semua)
            let r2 = permintaan(minUkuran: 0.4)
            r2.regionOfInterest = roi
            try? handler.perform([r2])
            func pusat(_ p: [CGPoint]) -> CGPoint { CGPoint(x: p.map(\.x).reduce(0, +) / 4, y: p.map(\.y).reduce(0, +) / 4) }
            let pc = pusat(c.px)
            tajam = [terbaik(r2.results ?? [], roi), terbaik(r2.results ?? [], semua)].compactMap { $0 }
                .filter { Rumus.kartuSah($0.h, a: a) }
                .min { hypot(pusat($0.px).x - pc.x, pusat($0.px).y - pc.y) < hypot(pusat($1.px).x - pc.x, pusat($1.px).y - pc.y) } ?? c
        }

        var k: HasilKartu?, titik: [CGPoint] = [], jarakFov: Double?
        if let t = tajam, let c = kasar, Rumus.kartuSah(c.h, a: a) || Rumus.kartuSah(t.h, a: a) {
            k = t.h
            titik = t.px.map { CGPoint(x: $0.x / W, y: $0.y / H) }
            jarakFov = Rumus.jarakKartu(t.px, fx: fxFov, fy: fxFov, a: a)?.jarakCM
            let kor = Rumus.jarakKoreksiTepi(t.px, fx: fx, fy: fy, a: a) ?? t.h.jarakCM
            riwayat = Array((riwayat + [(t.h.jarakCM, kor, c.h.jarakCM)]).suffix(a.kartu.frameHalus))
            terakhir = (pb, t.px, fx, fy, mir)
        } else {
            riwayat = []
            terakhir = nil
        }
        let n = riwayat.count
        let jarak = riwayat.map(\.tajam)
        let med: Double? = jarak.isEmpty ? nil : median(jarak)
        let medK: Double? = jarak.isEmpty ? nil : median(riwayat.map(\.koreksi))
        let medC: Double? = jarak.isEmpty ? nil : median(riwayat.map(\.kasar))
        let sebar: Double? = jarak.count < 2 ? nil : jarak.max()! - jarak.min()!
        var baris: [(String, String)] = [("frame", "\(Int(W)) × \(Int(H))")]
        baris.append(("fx intrinsics", intrinsik ? angka(fx, 0) : "tidak ada"))
        baris.append(("fx dari FOV", angka(fxFov, 0)))
        baris.append(("sisi kartu", k.map { "\(angka($0.sisiPanjangPX, 0)) px" } ?? "-"))
        baris.append(("rasio kartu (asli 1,586)", k.map { angka($0.rasio, 3) } ?? "-"))
        baris.append(("rasio lintasan 1", kasar.map { angka($0.h.rasio, 3) } ?? "-"))
        baris.append(("miring", "\(angka(mir))°"))
        baris.append(("sebaran cm", sebar.map { angka($0, 2) } ?? "-"))
        var log: [String: Any] = ["lebarFramePX": W, "tinggiFramePX": H, "fx": fx, "fy": fy, "fxFOV": fxFov, "intrinsik": intrinsik]
        log["fovDerajat"] = Lensa.fov(d)
        log["zoom"] = Double(d.videoZoomFactor); log["lensaX"] = Lensa.x   // kalau fx intrinsics ≈ fxFOV, intrinsics sudah memperhitungkan zoom
        log["miringDerajat"] = mir
        log["rasio"] = k?.rasio ?? 0
        log["rasioKasar"] = kasar?.h.rasio ?? 0
        // Sudut mentah supaya model koreksi lain bisa dicoba dari log tanpa tes ulang
        log["sudutPX"] = tajam.map { $0.px.flatMap { [Double($0.x), Double($0.y)] } } ?? []
        log["sudutKasarPX"] = kasar.map { $0.px.flatMap { [Double($0.x), Double($0.y)] } } ?? []
        log["cx"] = cx; log["cy"] = cy
        log["sisiPanjangKasarPX"] = kasar?.h.sisiPanjangPX ?? 0
        log["appFovCM"] = jarakFov ?? -1
        log["sisiPanjangPX"] = k?.sisiPanjangPX ?? 0
        log["sebaranCM"] = sebar ?? -1
        log["jumlahDeteksi"] = riwayat.count
        log["posisiLensa"] = Double(d.lensPosition)
        DispatchQueue.main.async {
            self.kartu = k; self.sudut = titik; self.jarakCM = med; self.jarakKoreksiCM = medK; self.jarakKasarCM = medC
            self.sebaranCM = sebar; self.miring = mir; self.info = baris; self.catatan = log; self.jumlah = n
        }
    }
}

/// Pratinjau dengan garis tepi kartu yang terdeteksi.
struct PratinjauKartu: UIViewRepresentable {
    let session: AVCaptureSession
    let sudut: [CGPoint]
    let warna: UIColor

    final class V: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        let garis = CAShapeLayer()
        var pratinjau: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> V {
        let v = V()
        v.pratinjau.session = session
        v.pratinjau.videoGravity = .resizeAspect
        v.garis.fillColor = UIColor.clear.cgColor
        v.garis.lineWidth = 4
        v.layer.addSublayer(v.garis)
        return v
    }

    func updateUIView(_ v: V, context: Context) {
        if let c = v.pratinjau.connection, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        v.garis.frame = v.bounds
        v.garis.strokeColor = warna.cgColor
        let p = sudut.map { v.pratinjau.layerPointConverted(fromCaptureDevicePoint: $0) }
        let path = UIBezierPath()
        if let f = p.first { path.move(to: f); p.dropFirst().forEach { path.addLine(to: $0) }; path.close() }
        v.garis.path = path.cgPath
    }
}

struct UjiKartuView: View {
    struct Baris: Identifiable { let id = UUID(); var meteran: Double; var app: Double; var koreksi: Double }

    @StateObject private var k = KameraKartu()
    @State private var meteran = ""
    @State private var hasil: [Baris] = []
    @State private var senter = false
    @FocusState private var ketik: Bool
    private let a = AmbangVerifikasi.sekarang

    private var nilaiMeteran: Double? { Double(meteran.replacingOccurrences(of: ",", with: ".")) }
    private var datar: Bool { k.miring <= a.kartu.maksMiringDerajat }
    private var siap: Bool { k.jarakCM != nil && datar && nilaiMeteran != nil }

    var body: some View {
        ZStack(alignment: .top) {
            PratinjauKartu(session: k.session, sudut: k.sudut, warna: datar ? .systemGreen : .systemYellow)
                .ignoresSafeArea()
                .onTapGesture { ketik = false }
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    if let s = k.status { Text(s).font(.callout.bold()) }
                    else if let j = k.jarakCM {
                        Text("Jarak dari kartu: \(angka(j)) cm").font(.title2.bold().monospacedDigit())
                        if let x = k.jarakKoreksiCM { Text("Dengan koreksi tepi: \(angka(x)) cm").font(.headline.monospacedDigit()) }
                        if let x = k.jarakKasarCM { Text("Cara lama (seluruh frame): \(angka(x)) cm").font(.caption.monospacedDigit()) }
                    } else {
                        Text("Taruh kartu ATM rata di dasar box, lalu pegang/taruh HP di posisi hitung.").font(.callout.bold())
                    }
                    if !datar { Label("HP miring \(angka(k.miring))°, maksimal \(angka(a.kartu.maksMiringDerajat, 0))°", systemImage: "level").foregroundStyle(.yellow).font(.caption.bold()) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                PanelNilai(baris: k.info.map { ($0.0, $0.1, nil) })
                Spacer()
                bawah
            }
            .padding()
        }
        .navigationTitle("Uji jarak kartu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { k.mulai() }
        .onDisappear { k.berhenti() }
        .onChange(of: senter) { _, v in k.senter(v) }
    }

    private var bawah: some View {
        VStack(spacing: 10) {
            if !hasil.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(hasil.suffix(4)) { b in
                        Text("Meteran \(angka(b.meteran)) · app \(selisih(b.app - b.meteran)) · koreksi \(selisih(b.koreksi - b.meteran)) cm")
                            .font(.caption.monospacedDigit())
                    }
                    ringkasan("App", hasil.map { abs($0.app - $0.meteran) })
                    ringkasan("Koreksi tepi", hasil.map { abs($0.koreksi - $0.meteran) })
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                TextField("Meteran: lensa ke dasar (cm)", text: $meteran)
                    .keyboardType(.decimalPad).focused($ketik)
                    .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                Toggle(isOn: $senter) { Image(systemName: "flashlight.on.fill") }.toggleStyle(.button)
                Button("Catat") { simpan() }.buttonStyle(.borderedProminent).disabled(!siap)
            }
        }
    }

    private func selisih(_ x: Double) -> String { "\(x >= 0 ? "+" : "")\(angka(x))" }

    private func ringkasan(_ nama: String, _ s: [Double]) -> some View {
        Text("\(nama): median |selisih| \(angka(median(s), 2)) · maks \(angka(s.max()!, 2)) cm (target ≤ 1 dan ≤ 1,5)")
            .font(.caption.bold()).foregroundStyle(median(s) <= 1 && s.max()! <= 1.5 ? .green : .orange)
    }

    private func simpan() {
        guard let m = nilaiMeteran, let j = k.jarakCM else { return }
        ketik = false
        let kor = k.jarakKoreksiCM ?? j
        hasil.append(Baris(meteran: m, app: j, koreksi: kor))
        var t = k.catatan
        t["meteranCM"] = m; t["appCM"] = j; t["appKoreksiCM"] = kor; t["appKasarCM"] = k.jarakKasarCM ?? -1
        t["selisihCM"] = j - m; t["selisihKoreksiCM"] = kor - m; t["senter"] = senter
        catat("ujiKartu", tambahan: t)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Daftar wadah: foto kartu otomatis

/// Kamera menunggu kartu terbaca, HP datar, dan jarak stabil, lalu memotret sendiri. `onSelesai(nil)` = dilewati (mode uji).
struct LayarFotoKartu: View {
    let pegang: Bool
    let onSelesai: (FotoKartu?) -> Void
    @StateObject private var k = KameraKartu()
    @AppStorage("gerbangPeringatan") private var uji = false
    @State private var senter = true
    @State private var memotret = false
    @State private var lama = false
    private let a = AmbangVerifikasi.sekarang

    private var datar: Bool { k.miring <= a.kartu.maksMiringDerajat }
    private var stabil: Bool {
        k.kartu != nil && datar && k.jumlah >= a.kartu.frameHalus && (k.sebaranCM ?? .infinity) <= a.kartu.maksSebaranCM
    }

    private var pesan: (String, String?) {
        if let s = k.status { return (s, nil) }
        if k.kartu == nil {
            return ("Kartu belum terbaca", lama ? "Coba: geser kartu ke tengah, nyalakan/matikan senter, atau pakai kartu warna gelap." : "Pastikan seluruh kartu terlihat di layar.")
        }
        if !datar { return ("HP miring \(angka(k.miring))°", "Sejajarkan HP dengan dasar box (maks \(angka(a.kartu.maksMiringDerajat, 0))°).") }
        return (pegang ? "Tahan HP diam…" : "Jangan sentuh HP…", nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            PratinjauKartu(session: k.session, sudut: k.sudut, warna: datar ? .systemGreen : .systemYellow).ignoresSafeArea()
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(memotret ? "Memotret…" : pesan.0).font(.headline)
                    if let t = pesan.1, !memotret { Text(t).font(.callout) }
                    if k.kartu != nil {
                        ProgressView(value: Double(k.jumlah), total: Double(a.kartu.frameHalus))
                        if let j = k.jarakKoreksiCM { Text("Jarak ±\(angka(j + a.kartu.koreksiJarakCM)) cm").font(.caption.monospacedDigit()) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                HStack {
                    Toggle(isOn: $senter) { Label("Senter", systemImage: "flashlight.on.fill") }.toggleStyle(.button)
                    Spacer()
                    if uji { Button("Lewati (mode uji)") { onSelesai(nil) }.buttonStyle(.bordered) }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .onAppear { k.mulai(); k.senter(senter) }
        .onDisappear { k.berhenti() }
        .onChange(of: senter) { _, v in k.senter(v) }
        .onChange(of: k.status) { _, s in if s == nil { k.senter(senter) } }   // senter baru bisa dinyalakan setelah kamera siap
        .onChange(of: stabil) { _, ok in
            guard ok, !memotret else { return }
            memotret = true
            k.potret { f in
                guard let f else { memotret = false; return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSelesai(f)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(a.kartu.detikTanpaKartu))
            lama = true
        }
    }
}

// MARK: - Daftar wadah: tarik 4 sudut dasar

/// Foto beku (tegak) dengan 4 titik yang ditarik user ke sudut dalam dasar box. Ukuran dihitung live.
/// Koordinat tampilan d (0–1, potret) ↔ piksel frame landscape: x = d.y · W, y = (1 − d.x) · H (foto diputar 90° searah jarum jam).
struct LayarSudutDasar: View {
    let foto: FotoKartu
    let onUlang: () -> Void
    let onLanjut: (_ p: Double, _ l: Double, _ sudutPX: [CGPoint]) -> Void
    @State private var titik: [CGPoint]
    @State private var aktif: Int?
    private let a = AmbangVerifikasi.sekarang
    private let ui: UIImage

    init(foto: FotoKartu, onUlang: @escaping () -> Void, onLanjut: @escaping (_ p: Double, _ l: Double, _ sudutPX: [CGPoint]) -> Void) {
        self.foto = foto; self.onUlang = onUlang; self.onLanjut = onLanjut
        ui = UIImage(cgImage: foto.gambar, scale: 1, orientation: .right)
        // Titik awal: dasar dalam nominal di jarak terukur, sisi panjang mengikuti sisi panjang layar
        let a = AmbangVerifikasi.sekarang, W = Double(foto.gambar.width), H = Double(foto.gambar.height)
        let p = ((a.boxPanjangLuarCM.nominal ?? 52) - 2 * a.tebalDindingCM) * foto.fx / foto.jarakCM / W
        let l = ((a.boxLebarLuarCM.nominal ?? 37) - 2 * a.tebalDindingCM) * foto.fy / foto.jarakCM / H
        let w = min(l, 0.9) / 2, h = min(p, 0.9) / 2
        _titik = State(initialValue: [CGPoint(x: 0.5 - w, y: 0.5 - h), CGPoint(x: 0.5 + w, y: 0.5 - h),
                                      CGPoint(x: 0.5 + w, y: 0.5 + h), CGPoint(x: 0.5 - w, y: 0.5 + h)])
    }

    private var W: Double { Double(foto.gambar.width) }
    private var H: Double { Double(foto.gambar.height) }
    private func keFrame(_ d: CGPoint) -> CGPoint { CGPoint(x: d.y * W, y: (1 - d.x) * H) }
    private func keTampilan(_ f: CGPoint) -> CGPoint { CGPoint(x: 1 - f.y / H, y: f.x / W) }
    private var dasar: (p: Double, l: Double) {
        Rumus.dasarDariSudut(titik.map(keFrame), fx: foto.fx, fy: foto.fy, jarakCM: foto.jarakCM) ?? (0, 0)
    }

    var body: some View {
        let catatan = Rumus.catatanWadah(jarakCM: foto.jarakCM, sudutDasar: titik, a: a)   // pita tepi simetris, koordinat tampilan cukup
        VStack(spacing: 10) {
            Text("Geser 4 titik kuning ke sudut dalam dasar box, tempat dasar bertemu dinding.").font(.callout.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { g in
                let s = min(g.size.width / ui.size.width, g.size.height / ui.size.height)
                let r = CGRect(x: (g.size.width - ui.size.width * s) / 2, y: (g.size.height - ui.size.height * s) / 2,
                               width: ui.size.width * s, height: ui.size.height * s)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: ui).resizable().frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                    garis(foto.sudutKartu.map { layar(keTampilan($0), r) }, .green)
                    garis(titik.map { layar($0, r) }, .yellow)
                    ForEach(0..<4, id: \.self) { i in
                        Circle().strokeBorder(.yellow, lineWidth: 3).background(Circle().fill(.black.opacity(0.25)))
                            .frame(width: 36, height: 36)
                            .position(layar(titik[i], r))
                            .gesture(DragGesture(coordinateSpace: .named("foto"))
                                .onChanged { v in
                                    aktif = i
                                    titik[i] = CGPoint(x: min(max((v.location.x - r.minX) / r.width, 0), 1),
                                                       y: min(max((v.location.y - r.minY) / r.height, 0), 1))
                                }
                                .onEnded { _ in aktif = nil })
                    }
                    if let i = aktif { kaca(titik[i], r) }
                }
                .coordinateSpace(name: "foto")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Dasar \(angka(dasar.p)) × \(angka(dasar.l)) cm · jarak kamera \(angka(foto.jarakCM)) cm").font(.headline.monospacedDigit())
                Text("Air \(Int(Rumus.airML(p: dasar.p, l: dasar.l, a: a))) ml").font(.callout)
                if catatan.isEmpty {
                    Label("Sesuai rekomendasi", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                } else {
                    ForEach(catatan, id: \.self) { Label($0, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.callout) }
                    Text("Tetap bisa lanjut, tapi wadah ditandai belum terverifikasi.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("Foto ulang", action: onUlang).buttonStyle(.bordered).controlSize(.large)
                Button { onLanjut(dasar.p, dasar.l, titik.map(keFrame)) } label: { Text("Simpan ukuran").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding()
    }

    private func layar(_ d: CGPoint, _ r: CGRect) -> CGPoint { CGPoint(x: r.minX + d.x * r.width, y: r.minY + d.y * r.height) }

    private func garis(_ p: [CGPoint], _ w: Color) -> some View {
        Path { q in if let f = p.first { q.move(to: f); p.dropFirst().forEach { q.addLine(to: $0) }; q.closeSubpath() } }
            .stroke(w, lineWidth: 2)
    }

    /// Kaca pembesar 3× di pojok kiri atas foto saat titik ditarik, supaya sudut bisa ditempatkan tepat.
    private func kaca(_ d: CGPoint, _ r: CGRect) -> some View {
        let z = 3.0, u = 120.0
        return Image(uiImage: ui).resizable().frame(width: r.width * z, height: r.height * z)
            .offset(x: u / 2 - d.x * r.width * z, y: u / 2 - d.y * r.height * z)
            .frame(width: u, height: u, alignment: .topLeading).clipShape(Circle())
            .overlay(Circle().stroke(.yellow, lineWidth: 2))
            .overlay(Image(systemName: "plus").foregroundStyle(.yellow))
            .position(x: r.minX + u / 2 + 8, y: r.minY + u / 2 + 8)
            .allowsHitTesting(false)
    }
}

/// Foto bukti daftar: kartu (hijau) dan dasar (kuning) digambar di atas foto, disimpan JPEG di Documents. Mengembalikan nama file.
func simpanBukti(_ f: FotoKartu, dasarPX: [CGPoint]) -> String? {
    let s = CGSize(width: f.gambar.width, height: f.gambar.height)
    let fmt = UIGraphicsImageRendererFormat()
    fmt.scale = 1
    let img = UIGraphicsImageRenderer(size: s, format: fmt).image { _ in
        UIImage(cgImage: f.gambar).draw(at: .zero)
        for (p, w) in [(f.sudutKartu, UIColor.systemGreen), (dasarPX, UIColor.systemYellow)] {
            let b = UIBezierPath()
            if let a = p.first { b.move(to: a); p.dropFirst().forEach { b.addLine(to: $0) }; b.close() }
            b.lineWidth = 6; w.setStroke(); b.stroke()
        }
    }
    let nama = "bukti-daftar-\(Int(Date().timeIntervalSince1970)).jpg"
    guard let cg = img.cgImage, let data = UIImage(cgImage: cg, scale: 1, orientation: .right).jpegData(compressionQuality: 0.8),
          (try? data.write(to: URL.documentsDirectory.appending(path: nama))) != nil else { return nil }
    return nama
}
