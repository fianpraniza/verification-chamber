import AVFoundation
import SwiftUI

@main
struct ShrimpWatchApp: App {
    @StateObject private var toko = TokoProfil()
    @AppStorage("gerbangPeringatan") private var uji = false

    var body: some Scene {
        WindowGroup {
            Beranda().environmentObject(toko)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if uji {
                        Text("MODE UJI · gerbang hanya peringatan").font(.caption.bold()).frame(maxWidth: .infinity)
                            .padding(4).background(.yellow).foregroundStyle(.black)
                    }
                }
        }
    }
}

// MARK: - Beranda

struct Beranda: View {
    @EnvironmentObject private var toko: TokoProfil
    @AppStorage("gerbangPeringatan") private var uji = false
    @AppStorage("panelNilai") private var panel = true
    private let a = AmbangVerifikasi.sekarang

    var body: some View {
        NavigationStack {
            List {
                if let p = toko.profil {
                    Section("Wadah") {
                        if perluDaftarUlang(p, a: a, modelHP: modelHP) {
                            Label("Perlu didaftarkan ulang", systemImage: "exclamationmark.arrow.circlepath").foregroundStyle(.orange)
                        } else {
                            StatusWadah(profil: p)
                        }
                        LabeledContent("Dasar dalam", value: "\(angka(p.panjangDalam)) × \(angka(p.lebarDalam)) cm")
                        LabeledContent("Air", value: "\(Int(p.airML)) ml")
                        LabeledContent("Posisi hitung", value: "\(p.mode == .taruh ? "ditaruh" : "dipegang"), \(angka(p.jarakCM)) cm")
                        LabeledContent("Didaftarkan", value: p.tanggalDaftar.formatted(date: .abbreviated, time: .shortened))
                    }
                    NavigationLink { SesiView(profil: p) } label: { Label("Mulai hitung", systemImage: "camera.viewfinder").font(.headline) }
                    NavigationLink { DaftarView() } label: { Label("Daftar ulang wadah", systemImage: "arrow.clockwise") }
                } else {
                    Text("Belum ada wadah terdaftar.").foregroundStyle(.secondary)
                    NavigationLink { DaftarView() } label: { Label("Daftar wadah", systemImage: "plus.circle.fill").font(.headline) }
                }
                Section {
                    Toggle("Gerbang hanya peringatan", isOn: $uji)
                    Toggle("Tampilkan panel nilai", isOn: $panel)
                    NavigationLink { UjiKartuView() } label: { Label("Uji jarak kartu", systemImage: "creditcard") }
                    ShareLink(item: urlLog) { Label("Bagikan log", systemImage: "square.and.arrow.up") }
                } header: {
                    Text("Pengaturan")
                } footer: {
                    Text("Gerbang hanya peringatan: cek yang gagal ditandai kuning dan alur tetap lanjut. Hanya untuk uji; angka hasilnya tidak boleh dipakai.")
                }
            }
            .navigationTitle("ShrimpWatch")
        }
    }
}

// MARK: - Daftar wadah (sekali)

struct DaftarView: View {
    @EnvironmentObject private var toko: TokoProfil
    @Environment(\.dismiss) private var dismiss

    enum Langkah { case spesifikasi, pilihMode, instruksiKartu, fotoKartu, sudutDasar(FotoKartu), instruksiAcuan, acuan1, jeda(AcuanFrame), acuan2(AcuanFrame), selesai(WadahProfile) }
    @State private var langkah = Langkah.spesifikasi
    @State private var mode = ModeHitung.taruh
    @State private var jarak = 0.0
    @State private var dasar = (p: 0.0, l: 0.0)
    @State private var catatan: [String] = []
    @State private var bukti: [String: Any] = [:]   // nilai foto kartu untuk log daftar
    @State private var lensa: Float?                 // posisi fokus saat kartu terbaca
    private let a = AmbangVerifikasi.sekarang

    private var airML: Double { Rumus.airML(p: dasar.p, l: dasar.l, a: a) }

    var body: some View {
        Group {
            switch langkah {
            case .spesifikasi:
                Form {
                    Section {
                        LabeledContent("Saran", value: "Tomota \(n(a.boxPanjangLuarCM)) × \(n(a.boxLebarLuarCM)) × \(n(a.boxTinggiLuarCM)) cm")
                        Text("Box lain juga boleh, asal dari atas box seluruh dasarnya terlihat kamera dan tinggi kamera ke dasar \(angka(a.jarakKameraKeDasarCM.min, 0))–\(angka(a.jarakKameraKeDasarCM.max, 0)) cm.")
                    } header: { Text("Box") }
                    Section("Kamera") {
                        Text("App memakai kamera \(angka(Lensa.x))x (video latih: \(angka(a.deteksi.lensaLatihX))x). HP ditaruh atau dipegang di atas box, kamera menghadap dasar.")
                    }
                    Section("Untuk mengukur") {
                        Label("Satu kartu ATM, e-money, atau kartu member (jangan KTP). Kartu warna gelap paling mudah terbaca.", systemImage: "creditcard")
                    }
                    Button("Siap") { langkah = .pilihMode }
                }
            case .pilihMode:
                Form {
                    Section("Posisi hitung") {
                        Button { mode = .taruh; langkah = .instruksiKartu } label: {
                            Instruksi(ikon: "square.stack.3d.up", judul: "Taruh", teks: "HP ditaruh di atas box (di tutup berlubang atau penyangga), kamera menghadap dasar.")
                        }
                        Button { mode = .pegang; langkah = .instruksiKartu } label: {
                            Instruksi(ikon: "hand.raised", judul: "Pegang", teks: "HP dipegang di atas box seperti saat menghitung.")
                        }
                    }
                }
            case .instruksiKartu:
                LayarIsi(baris: [
                    Instruksi(ikon: "creditcard", judul: "Taruh kartu di tengah dasar box bawah", teks: "Rata, tidak tertekuk, box masih kering dan kosong."),
                    Instruksi(ikon: "iphone.rear.camera", judul: mode == .taruh ? "Taruh HP di atas box, kamera menghadap dasar" : "Pegang HP di posisi hitung",
                              teks: "Foto diambil otomatis saat kartu terbaca dan HP diam. Seluruh dasar box harus terlihat.")
                ], tombol: "Mulai") { langkah = .fotoKartu }
            case .fotoKartu:
                LayarFotoKartu(pegang: mode == .pegang) { f in
                    if let f {
                        langkah = .sudutDasar(f)
                    } else {   // dilewati di mode uji: ukuran nominal
                        let d = Rumus.dalam(UkuranBox(panjang: a.boxPanjangLuarCM.nominal ?? 52, lebar: a.boxLebarLuarCM.nominal ?? 37, tinggi: 0), a: a)
                        jarak = (a.jarakKameraKeDasarCM.min + a.jarakKameraKeDasarCM.max) / 2
                        dasar = d; catatan = ["Ukuran dilewati (mode uji)"]; bukti = [:]; lensa = nil
                        langkah = .instruksiAcuan
                    }
                }
            case .sudutDasar(let f):
                LayarSudutDasar(foto: f, onUlang: { langkah = .fotoKartu }) { p, l, sudut in
                    jarak = f.jarakCM; dasar = (p, l); lensa = f.posisiLensa
                    let W = Double(f.gambar.width), H = Double(f.gambar.height)
                    catatan = Rumus.catatanWadah(jarakCM: f.jarakCM, sudutDasar: sudut.map { CGPoint(x: $0.x / W, y: $0.y / H) }, a: a)
                    bukti = ["sudutKartuPX": f.sudutKartu.flatMap { [$0.x, $0.y] }, "sudutDasarPX": sudut.flatMap { [$0.x, $0.y] },
                             "fx": f.fx, "fy": f.fy, "miringDerajat": f.miring, "sebaranCM": f.sebaranCM, "posisiLensaKartu": f.posisiLensa, "foto": simpanBukti(f, dasarPX: sudut) ?? ""]
                    langkah = .instruksiAcuan
                }
            case .instruksiAcuan:
                LayarIsi(baris: [
                    Instruksi(ikon: "creditcard.trianglebadge.exclamationmark", judul: "Ambil kartu dari box", teks: "Ukuran sudah tersimpan."),
                    Instruksi(ikon: "drop.fill", judul: "Tuang \(Int(airML)) ml air ke box bawah", teks: "Belum ada benur."),
                    Instruksi(ikon: "lightbulb.slash.fill", judul: "Tutup box atau matikan lampu", teks: "Senter HP jadi satu-satunya cahaya."),
                    Instruksi(ikon: "iphone.rear.camera", judul: mode == .taruh ? "Taruh HP di posisi hitung" : "Pegang HP di posisi hitung",
                              teks: "Foto acuan diambil otomatis saat gambar stabil.")
                ], tombol: "Ambil foto acuan") { langkah = .acuan1 }
            case .acuan1:
                LayarKamera(mode: .acuan(pegang: mode == .pegang, setelan: nil, lensa: lensa)) { acuan in langkah = .jeda(acuan) }
            case .jeda(let a1):
                LayarIsi(baris: [
                    Instruksi(ikon: "checkmark.circle.fill", judul: "Acuan 1 tersimpan", teks: "Sekarang ukur variasi posisi."),
                    Instruksi(ikon: "arrow.up.and.down", judul: "Angkat HP lalu taruh atau pegang lagi di posisi yang sama", teks: "Jangan ubah air atau tutup box.")
                ], tombol: "Ambil acuan kedua") { langkah = .acuan2(a1) }
            case .acuan2(let a1):
                LayarKamera(mode: .acuan(pegang: mode == .pegang, setelan: a1.setelan)) { a2 in
                    let p = WadahProfile(panjangDalam: dasar.p, lebarDalam: dasar.l, luasDasar: dasar.p * dasar.l, airML: airML,
                                         mode: mode, jarakCM: jarak, lensaX: Lensa.x, catatan: catatan, acuan: a1, nccBaseline: Rumus.nccPosisi(a1.thumb, a2.thumb),
                                         fpBaseline: Visi.jarak(a1.featurePrint, a2.featurePrint) ?? 0,
                                         modelHP: modelHP, versi: a.versi, tanggalDaftar: Date())
                    toko.simpan(p)
                    var t = bukti
                    t.merge(["nccBaseline": p.nccBaseline, "fpBaseline": p.fpBaseline, "jarakCM": p.jarakCM, "airML": p.airML,
                             "panjangDalam": p.panjangDalam, "lebarDalam": p.lebarDalam, "catatan": p.catatan, "mode": p.mode.rawValue, "lensaX": p.lensaX, "posisiLensaAcuan": a1.setelan.posisiLensa]) { $1 }
                    catat("daftar", tambahan: t)
                    langkah = .selesai(p)
                }
            case .selesai(let p):
                let amb = Rumus.ambangCocok(nccBaseline: p.nccBaseline, fpBaseline: p.fpBaseline, a: a)
                Form {
                    StatusWadah(profil: p)
                    LabeledContent("Jarak kamera ke dasar", value: "\(angka(p.jarakCM)) cm")
                    LabeledContent("Dasar dalam", value: "\(angka(p.panjangDalam)) × \(angka(p.lebarDalam)) cm")
                    LabeledContent("Air", value: "\(Int(p.airML)) ml")
                    LabeledContent("Baseline NCC / feature print", value: "\(angka(p.nccBaseline, 3)) / \(angka(p.fpBaseline, 3))")
                    LabeledContent("Ambang cocok", value: "NCC ≥ \(angka(amb.minNCC, 2)), FP ≤ \(angka(amb.maksFP, 2))")
                    Button("Selesai") { dismiss() }
                }
            }
        }
        .navigationTitle("Daftar wadah")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func n(_ r: Rentang) -> String { angka(r.nominal ?? r.min, 0) }
}

/// Terdaftar dan terverifikasi (hijau), terdaftar tapi ada catatan (oranye, alasannya ditampilkan).
struct StatusWadah: View {
    let profil: WadahProfile

    var body: some View {
        if profil.terverifikasi {
            Label("Wadah terverifikasi ✓", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("Wadah belum terverifikasi", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                ForEach(profil.catatan, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Sesi hitung

struct SesiView: View {
    let profil: WadahProfile
    @AppStorage("stadiaTerakhir") private var stadiaTerakhir = 10
    @AppStorage("gerbangPeringatan") private var uji = false

    enum Langkah { case pilih, cekWadah, masukkanBenur, hitung, proses, hasil(HasilSesi), tolak(HasilSesi), tanpaModel }
    @State private var langkah = Langkah.pilih
    @State private var hitungan: [Int] = []   // hitung bertahap dari kantong yang sama
    @State private var daftarUlang = false
    private let a = AmbangVerifikasi.sekarang

    private var stadia: Stadia { Stadia(rawValue: stadiaTerakhir).flatMap { a.stadia.contains($0) ? $0 : nil } ?? a.stadia.first ?? .pl10 }

    var body: some View {
        Group {
            if perluDaftarUlang(profil, a: a, modelHP: modelHP), !uji {
                LayarTolak(masalah: .profilKedaluwarsa, tombol: "Daftar ulang") { daftarUlang = true }
            } else {
                switch langkah {
                case .pilih:
                    Form {
                        Picker("Stadia benur", selection: $stadiaTerakhir) { ForEach(a.stadia) { Text($0.nama).tag($0.rawValue) } }
                        Sorotan(judul: "Tuang \(Int(profil.airML)) ml air, belum ada benur.", nilai: "", ikon: "drop.fill")
                        Text("Lalu tutup box atau matikan lampu, dan \(profil.mode == .taruh ? "taruh" : "pegang") HP di posisi hitung.")
                        Button("Cek wadah") { langkah = .cekWadah }
                    }
                case .cekWadah:
                    LayarKamera(mode: .cocok(profil), onCocok: { _ in langkah = .masukkanBenur })
                case .masukkanBenur:
                    LayarIsi(baris: [
                        Instruksi(ikon: "checkmark.seal.fill", judul: "Wadah cocok ✓", teks: "Masukkan benur \(stadia.nama), lalu kembalikan HP ke posisi."),
                        Instruksi(ikon: "square.grid.3x3", judul: "Ratakan benur", teks: "Maksimal \(a.maksKapasitas) ekor per hitungan.")
                    ], tombol: "Benur sudah masuk") { langkah = .hitung }
                case .hitung:
                    LayarKamera(mode: .hitung(profil), onFoto: { t in
                        langkah = .proses
                        Task { @MainActor in
                            guard let model = Detektor.model else { langkah = .tanpaModel; return }
                            let s = stadia, p = profil
                            let r = await Task.detached { Proses.hitung(t, profil: p, stadia: s, model: model, a: .sekarang) }.value
                            catat("hitung", r.hasil, tambahan: ["stadia": s.rawValue, "perFoto": r.perFoto, "jumlah": r.jumlah ?? -1,
                                                                 "panjangPX": r.panjangPX, "sisiDeteksiPX": r.sisiDeteksiPX, "perFotoCek": r.perFotoCek.map(\.log)])
                            if r.hasil.lolos || uji {
                                hitungan.append(r.jumlah ?? Int(median(r.perFoto.map(Double.init)).rounded()))
                                langkah = .hasil(r)
                            } else {
                                langkah = .tolak(r)
                            }
                        }
                    })
                case .proses:
                    ProgressView("Menghitung benur…")
                case .hasil(let r):
                    ScrollView {
                        VStack(spacing: 12) {
                            if !r.hasil.lolos {
                                Label("Gerbang gagal (\(r.hasil.masalah.map { $0.teks().judul }.joined(separator: ", "))). Angka hanya untuk uji.",
                                      systemImage: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            }
                            if !profil.terverifikasi {
                                Label("Wadah belum terverifikasi: \(profil.catatan.joined(separator: " "))", systemImage: "exclamationmark.triangle.fill")
                                    .font(.callout).foregroundStyle(.orange)
                            }
                            if let g = r.gambar { Image(uiImage: tandai(g, r.kotak, .systemGreen)).resizable().scaledToFit() }
                            Text("\(hitungan.reduce(0, +))").font(.system(size: 64, weight: .bold))
                            Text(hitungan.count > 1 ? "ekor total \(stadia.nama)" : "ekor benur \(stadia.nama)").foregroundStyle(.secondary)
                            GroupBox {
                                if hitungan.count > 1 {
                                    ForEach(hitungan.indices, id: \.self) { i in LabeledContent("Hitungan \(i + 1)", value: "\(hitungan[i])") }
                                }
                                LabeledContent("Per foto (terakhir)", value: r.perFoto.map(String.init).joined(separator: " · "))
                            }
                            PanelNilai(baris: barisHasil(r))
                            Button("Tambah hitungan dari kantong yang sama") { langkah = .masukkanBenur }.buttonStyle(.bordered)
                            Button("Selesai") { hitungan = []; langkah = .pilih }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                        .padding()
                    }
                case .tolak(let r):
                    VStack {
                        LayarTolak(masalah: r.hasil.masalah.first ?? .hasilTidakStabil, gambar: r.gambar.map { tandai($0, r.kotak, .systemRed) },
                                   tombol: "Foto ulang") { langkah = .hitung }
                        PanelNilai(baris: barisHasil(r)).padding(.horizontal)
                    }
                case .tanpaModel:
                    ContentUnavailableView("Model belum ada", systemImage: "cpu", description: Text("Tambahkan Benur.mlpackage lalu build ulang."))
                }
            }
        }
        .navigationTitle("Hitung")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $daftarUlang) { DaftarView() }
    }

    private func barisHasil(_ r: HasilSesi) -> [(String, String, Bool?)] {
        var b: [(String, String, Bool?)] = [("panjang benur diharapkan px", angka(r.panjangPX), nil)]
        for (i, c) in r.perFotoCek.enumerated() {
            b += c.ukur.sorted { $0.key < $1.key }.map { ("foto \(i + 1) · \($0.key)", "\(angka($0.value.nilai, 3)) (\($0.value.batas))", $0.value.lolos) }
        }
        return b + r.hasil.ukur.map { ($0.key, "\(angka($0.value.nilai, 3)) (\($0.value.batas))", $0.value.lolos) }
    }
}

// MARK: - Komponen

/// Semua nilai terukur dan ambangnya. Bisa disembunyikan lewat Pengaturan.
struct PanelNilai: View {
    let baris: [(String, String, Bool?)]
    @AppStorage("panelNilai") private var tampil = true

    var body: some View {
        if tampil, !baris.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(baris.indices, id: \.self) { i in
                    HStack {
                        Text(baris[i].0)
                        Spacer()
                        Text(baris[i].1).monospacedDigit()
                            .foregroundStyle(baris[i].2.map { $0 ? Color.green : Color.red } ?? .primary)
                    }
                }
            }
            .font(.caption2)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct Sorotan: View {
    let judul: String
    var sub: String? = nil
    let nilai: String
    var ikon: String? = nil

    var body: some View {
        LabeledContent {
            Text(nilai).font(.title3.bold()).foregroundStyle(.tint)
        } label: {
            if let ikon { Label(judul, systemImage: ikon) } else { Text(judul) }
            if let sub { Text(sub) }
        }
    }
}

struct Instruksi: View {
    let ikon: String
    let judul: String
    let teks: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(judul).font(.headline)
                Text(teks).font(.callout).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: ikon).font(.title2) }
    }
}

struct LayarIsi: View {
    let baris: [Instruksi]
    let tombol: String
    let aksi: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(baris.indices, id: \.self) { baris[$0] }
            Spacer()
            Button(action: aksi) { Text(tombol).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding()
    }
}

/// Kamera: lampu indikator, satu masalah terpenting, progres frame stabil, panel nilai.
struct LayarKamera: View {
    var onAcuan: ((AcuanFrame) -> Void)? = nil
    var onCocok: ((HasilVerifikasi) -> Void)? = nil
    var onFoto: ((Tangkapan) -> Void)? = nil
    @StateObject private var kamera: Kamera
    @AppStorage("gerbangPeringatan") private var uji = false

    init(mode: ModeKamera, onAcuan: ((AcuanFrame) -> Void)? = nil, onCocok: ((HasilVerifikasi) -> Void)? = nil, onFoto: ((Tangkapan) -> Void)? = nil) {
        self.onAcuan = onAcuan; self.onCocok = onCocok; self.onFoto = onFoto
        _kamera = StateObject(wrappedValue: Kamera(mode: mode))
    }

    init(mode: ModeKamera, onAcuan: @escaping (AcuanFrame) -> Void) { self.init(mode: mode, onAcuan: onAcuan, onCocok: nil, onFoto: nil) }

    private var cocok: Bool { if case .cocok = kamera.mode { true } else { false } }

    var body: some View {
        ZStack(alignment: .top) {
            Pratinjau(session: kamera.session).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(kamera.status == nil && kamera.hasil.lolos ? .green : uji ? .yellow : .red)
                        .frame(width: 16, height: 16).padding(.top, 4)
                    Group {
                        if let s = kamera.status {
                            Text(s)
                        } else if kamera.memotret {
                            Text("Memotret, tahan HP diam…")
                        } else if let m = kamera.hasil.masalah.first, !cocok || kamera.gagalLama || uji {
                            let t = m.teks()
                            Label { VStack(alignment: .leading) { Text(t.judul).bold(); Text(t.perbaikan).font(.callout) } } icon: { Image(systemName: t.ikon) }
                                .foregroundStyle(uji ? .yellow : .primary)
                        } else if !kamera.hasil.lolos {
                            Text("Mencocokkan dengan foto acuan…")
                        } else {
                            VStack(alignment: .leading) {
                                Text("Tahan, stabil…").bold()
                                ProgressView(value: min(kamera.progres, 1))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                PanelNilai(baris: kamera.hasil.ukur.sorted { $0.key < $1.key }.map { ($0.key, "\(angka($0.value.nilai, 2)) (\($0.value.batas))", $0.value.lolos) })
            }
            .padding()
        }
        .onAppear { kamera.onAcuan = onAcuan; kamera.onCocok = onCocok; kamera.onFoto = onFoto; kamera.mulai() }
        .onDisappear { kamera.berhenti() }
    }
}

struct Pratinjau: UIViewRepresentable {
    let session: AVCaptureSession
    final class V: UIView { override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self } }

    func makeUIView(context: Context) -> V {
        let v = V()
        let l = v.layer as! AVCaptureVideoPreviewLayer
        l.session = session
        l.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ v: V, context: Context) {}
}

/// Layar penolakan: satu masalah, satu tindakan perbaikan, satu tombol.
struct LayarTolak: View {
    let masalah: MasalahVerifikasi
    var gambar: UIImage?
    let tombol: String
    let aksi: () -> Void

    var body: some View {
        let t = masalah.teks()
        ScrollView {
            VStack(spacing: 16) {
                if let gambar { Image(uiImage: gambar).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)) }
                Image(systemName: t.ikon).font(.system(size: 44)).foregroundStyle(.red)
                Text(t.judul).font(.title2.bold()).multilineTextAlignment(.center)
                Text(t.perbaikan).multilineTextAlignment(.center)
                Button(tombol, action: aksi).buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding()
        }
    }
}

/// Gambar kotak (ternormalisasi, origin kiri-atas) di atas foto.
func tandai(_ cg: CGImage, _ kotak: [CGRect], _ warna: UIColor) -> UIImage {
    let s = CGSize(width: cg.width, height: cg.height)
    let f = UIGraphicsImageRendererFormat()
    f.scale = 1
    return UIGraphicsImageRenderer(size: s, format: f).image { _ in
        UIImage(cgImage: cg).draw(at: .zero)
        warna.setStroke()
        for k in kotak {
            let p = UIBezierPath(rect: CGRect(x: k.minX * s.width, y: k.minY * s.height, width: k.width * s.width, height: k.height * s.height))
            p.lineWidth = 2
            p.stroke()
        }
    }
}
