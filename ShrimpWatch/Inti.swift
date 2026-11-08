// Logika murni (Foundation + CoreGraphics + simd) supaya bisa dicek di Mac: lihat Cek/main.swift
import Foundation
import CoreGraphics
import simd

// MARK: - Model data

enum Stadia: Int, Codable, CaseIterable, Identifiable {
    case pl8 = 8, pl9, pl10, pl11, pl12, pl13, pl14, pl15

    var id: Int { rawValue }
    var nama: String { "PL-\(rawValue)" }

    // Panjang acuan (mm) dari dokumen kalkulator; selain PL-10 masih estimasi kerja
    var panjangMM: Double {
        switch self {
        case .pl8: return 7.950
        case .pl9: return 8.455
        case .pl10: return 8.650
        case .pl11: return 9.180
        case .pl12: return 9.680
        case .pl13: return 10.655
        case .pl14: return 11.450
        case .pl15: return 12.000
        }
    }
}

struct SetelanKamera: Codable {
    var iso: Float
    var durasiEksposurDetik: Double
    var posisiLensa: Float
    var gainMerah: Float
    var gainHijau: Float
    var gainBiru: Float
    var levelSenter: Float
}

struct UkuranBox: Codable { var panjang: Double; var lebar: Double; var tinggi: Double }   // cm, luar

enum ModeHitung: String, Codable { case taruh, pegang }

/// Tampilan wadah kosong di posisi hitung, sebagai acuan pencocokan setiap sesi.
struct AcuanFrame: Codable {
    var thumb: [UInt8]          // Y 64 × 48 (untuk NCC)
    var peta: [Double]          // 4 × 4, dinormalisasi ke rata-rata
    var kecerahan: Double
    var featurePrint: Data      // VNFeaturePrintObservation, NSKeyedArchiver
    var setelan: SetelanKamera
}

struct WadahProfile: Codable {
    var panjangDalam: Double    // cm, dari foto kartu: dasar dalam
    var lebarDalam: Double
    var luasDasar: Double       // cm2
    var airML: Double
    var mode: ModeHitung
    var jarakCM: Double         // kamera ke dasar, dari foto kartu
    var catatan: [String]       // alasan belum terverifikasi; kosong = terverifikasi
    var acuan: AcuanFrame
    var nccBaseline: Double     // acuan 1 vs acuan 2 (HP diangkat lalu dikembalikan)
    var fpBaseline: Double
    var modelHP: String
    var versi: String
    var tanggalDaftar: Date

    var terverifikasi: Bool { catatan.isEmpty }
}

struct Rentang: Codable {
    var min: Double
    var max: Double
    var nominal: Double?
    func berisi(_ x: Double) -> Bool { x >= min && x <= max }
}

// Dibaca dari ambang.json. Persen ditulis sebagai pecahan: 5% = 0.05.
struct AmbangVerifikasi: Codable {
    struct AR: Codable {
        var frameHalus: Int                // titik = median posisi bidikan N frame terakhir
        var maksGoyangCM: Double           // sebaran bidikan N frame itu; lebih besar = HP masih bergerak
        var minTinggiTutupCM: Double       // bidang setinggi ini di atas lantai dianggap tutup box
        var jarakBidikCM: Rentang          // jarak kamera ke titik bidikan
        var minSudutBidikDerajat: Double   // sudut garis bidik di bawah horizontal; terlalu landai = titik mudah meleset
        var minCahayaLumen: Double         // ARLightEstimate.ambientIntensity, 1000 = cahaya normal
    }
    // Kartu ID-1 (ATM/e-money) rata di dasar box sebagai acuan jarak
    struct Kartu: Codable {
        var panjangMM: Double
        var lebarMM: Double
        var toleransiRasio: Double       // rasio sisi panjang/pendek di foto boleh beda segini dari 85,6/53,98
        var maksMiringDerajat: Double
        var frameHalus: Int              // jarak = median N deteksi terakhir
        var maksSebaranCM: Double        // foto otomatis baru diambil kalau N deteksi itu sebarannya ≤ ini
        var koreksiJarakCM: Double       // bias tetap iPhone 17 vs meteran: rata-rata −0,5 cm di 28–76 cm (uji 7/11/2026)
        var detikTanpaKartu: Double      // setelah ini, tampilkan tips kalau kartu belum terbaca
    }
    struct Kam: Codable {
        var levelSenter: Float
        var zoomLensa: Double            // 0.6x = ultrawide × 1,2, sama dengan video latih
        var maksISO: Float
        var maksDurasiEksposurDetik: Double
        var sisiAnalisisPX: Int
        var frameStabil: Int
        var maksKemiringanPegangDerajat: Double
        var minKetajaman: Double
        var toleransiKecerahan: Double
    }
    struct Cocok: Codable {
        var minNCC: Double
        var pengaliBaseline: Double
        var minBatasFeaturePrint: Double
        var maksDeviasiPetaCahaya: Double
    }
    struct Hsl: Codable {
        var jumlahFoto: Int
        var minFotoLolos: Int
        var pitaTepi: Double
        var toleransiSkalaBenur: Double
        var iouNMS: Double                     // dipakai sebagai IoS gabung antarubin (lihat Detektor)
        var minKeyakinanDeteksi: Double
        var minRataKeyakinan: Double
        var batasKeyakinanRendah: Double
        var maksPersenKeyakinanRendah: Double
        var faktorJarakTerlaluDekat: Double
        var maksPersenTerlaluDekat: Double
        var iouTumpuk: Double
        var maksPersenTumpuk: Double
        var maksSelisihAntarFoto: Double
    }
    // Pipeline deteksi: sisi panjang foto 1920 px, ubin 320 px, sama dengan pipeline latih.
    // jarakLatihCM: kamera ke dasar saat video latih direkam (0.6x, HP di atas box 46 cm)
    struct Det: Codable { var sisiPanjangPX: Int; var sisiUbinPX: Int; var overlapUbin: Double; var jarakLatihCM: Double }

    var versi: String
    var boxPanjangLuarCM: Rentang
    var boxLebarLuarCM: Rentang
    var boxTinggiLuarCM: Rentang
    var tebalDindingCM: Double
    var jarakKameraKeDasarCM: Rentang
    var kedalamanAirCM: Double
    var pembulatanAirML: Double
    var stadiaDidukung: [Int]
    var maksKapasitas: Int
    var masaBerlakuDaftarHari: Int
    var arkit: AR
    var kartu: Kartu
    var kamera: Kam
    var cocokAcuan: Cocok
    var hasil: Hsl
    var deteksi: Det

    var stadia: [Stadia] { stadiaDidukung.compactMap(Stadia.init) }

    static func muat(_ url: URL) throws -> AmbangVerifikasi { try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)) }
    static let sekarang = try! muat(Bundle.main.url(forResource: "ambang", withExtension: "json")!)
}

// Urutan case = urutan prioritas pesan.
enum MasalahVerifikasi: String, Codable, CaseIterable {
    case profilKedaluwarsa
    // Foto acuan dan cek ringan sebelum hitung
    case cahayaLemah, hpMiring, blur
    // Cek wadah terhadap acuan
    case wadahBerbeda, posisiBeda, cahayaBeda
    // Hasil
    case wadahKosong, dasarTerpotong, skalaTidakSesuai, terlaluBanyak, terlaluRapat, bertumpuk, keyakinanRendah, hasilTidakStabil

    var urutan: Int { Self.allCases.firstIndex(of: self)! }

    func teks() -> (judul: String, perbaikan: String, ikon: String) {
        switch self {
        case .profilKedaluwarsa: ("Wadah perlu didaftarkan ulang", "Profil lebih dari 30 hari, HP berganti, atau config diperbarui", "exclamationmark.arrow.circlepath")
        case .cahayaLemah: ("Cahaya terlalu lemah", "Periksa senter", "flashlight.off.fill")
        case .hpMiring: ("HP miring", "Sejajarkan HP dengan dasar wadah", "level")
        case .blur: ("Gambar belum tajam", "Tahan HP diam, tunggu fokus", "camera.metering.unknown")
        case .wadahBerbeda: ("Wadah berbeda dari yang didaftarkan", "Pakai box yang didaftarkan, atau daftar ulang", "questionmark.square.dashed")
        case .posisiBeda: ("Tinggi atau posisi HP berbeda dari saat daftar", "Kembalikan HP ke posisi hitung", "arrow.up.and.down")
        case .cahayaBeda: ("Cahaya berbeda", "Periksa lampu ruangan atau tutup box", "lightbulb.fill")
        case .wadahKosong: ("Belum ada benur terdeteksi", "Masukkan benur, lalu foto ulang", "tray")
        case .dasarTerpotong: ("Dasar wadah terpotong", "Pastikan seluruh dasar box terlihat, lalu foto ulang", "crop")
        case .skalaTidakSesuai: ("Jarak HP atau wadah tidak sesuai", "Kembalikan HP ke posisi hitung, lalu foto ulang", "arrow.up.left.and.arrow.down.right")
        case .terlaluBanyak: ("Terlalu banyak", "Bagi jadi 2 hitungan", "exclamationmark.triangle.fill")
        case .terlaluRapat, .bertumpuk: ("Benur terlalu rapat atau bertumpuk", "Ratakan benur, lalu foto ulang", "square.stack.3d.up.fill")
        case .keyakinanRendah: ("Hasil kurang pasti", "Foto ulang; periksa cahaya dan kebersihan air", "questionmark.circle.fill")
        case .hasilTidakStabil: ("Hitungan antarfoto berbeda jauh", "Tunggu benur tenang, lalu foto ulang", "waveform.path")
        }
    }
}

/// Satu nilai terukur beserta ambangnya, untuk panel nilai dan log.
struct Ukur { var nilai: Double; var batas: String; var lolos: Bool }

struct HasilVerifikasi {
    var masalah: [MasalahVerifikasi] = []   // urut dari prioritas tertinggi
    var ukur: [String: Ukur] = [:]
    var lolos: Bool { masalah.isEmpty }

    mutating func cek(_ nama: String, _ v: Double, _ batas: String, lolos ok: Bool, _ m: MasalahVerifikasi) {
        ukur[nama] = Ukur(nilai: v, batas: batas, lolos: ok)
        if !ok, !masalah.contains(m) { masalah.append(m); masalah.sort { $0.urutan < $1.urutan } }
    }

    var log: [String: Any] {
        ["lolos": lolos, "masalah": masalah.map(\.rawValue),
         "nilai": ukur.filter { $0.value.nilai.isFinite }.mapValues { ["nilai": $0.nilai, "lolos": $0.lolos] as [String: Any] }]
    }
}

/// Angka gaya Indonesia (koma desimal), deterministik untuk pesan dan uji.
func angka(_ x: Double, _ d: Int = 1) -> String { String(format: "%.\(d)f", x).replacingOccurrences(of: ".", with: ",") }

// MARK: - Rumus spesifikasi, air, jarak, skala

enum Rumus {
    /// Satu pesan per ukuran yang keluar rentang; kosong = sesuai spesifikasi.
    static func cekSpesifikasi(_ u: UkuranBox, a: AmbangVerifikasi) -> [String] {
        [("Panjang", u.panjang, a.boxPanjangLuarCM), ("Lebar", u.lebar, a.boxLebarLuarCM), ("Tinggi", u.tinggi, a.boxTinggiLuarCM)]
            .compactMap { nama, x, r in
                x < r.min ? "\(nama) \(angka(x)) cm, minimal \(angka(r.min, 0)) cm."
                    : x > r.max ? "\(nama) \(angka(x)) cm, maksimal \(angka(r.max, 0)) cm." : nil
            }
    }

    /// P = panjang luar − 2·tebal, L = lebar luar − 2·tebal
    static func dalam(_ u: UkuranBox, a: AmbangVerifikasi) -> (p: Double, l: Double) {
        (u.panjang - 2 * a.tebalDindingCM, u.lebar - 2 * a.tebalDindingCM)
    }

    /// V = P·L·kedalaman (ml), dibulatkan ke kelipatan pembulatanAirML.
    static func airML(p: Double, l: Double, a: AmbangVerifikasi) -> Double {
        (p * l * a.kedalamanAirCM / a.pembulatanAirML).rounded() * a.pembulatanAirML
    }

    /// Mode taruh: HP di atas tumpukan, kamera ke dasar box bawah.
    static func jarakTaruh(tinggiTumpukanCM t: Double, a: AmbangVerifikasi) -> Double { t - a.tebalDindingCM }

    /// Mode pegang: Y kamera dan lantai dalam meter (dunia ARKit).
    static func jarakPegang(kameraY: Double, lantaiY: Double, a: AmbangVerifikasi) -> Double { (kameraY - lantaiY) * 100 - a.tebalDindingCM }

    /// mm per piksel di dasar = 2 · jarak · 10 · tan(FOVh/2) ÷ lebar foto. FOVh = videoFieldOfView, sepanjang sisi panjang sensor,
    /// jadi `lebarFotoPX` = sisi panjang gambar yang dideteksi.
    static func panjangPX(_ s: Stadia, jarakCM: Double, fovDerajat: Double, lebarFotoPX: Double) -> Double {
        let mmPerPiksel = 2 * jarakCM * 10 * tan(fovDerajat / 2 * .pi / 180) / lebarFotoPX
        return s.panjangMM / mmPerPiksel
    }

    /// Ambang cocok dari baseline (variasi saat HP diangkat lalu dikembalikan).
    static func ambangCocok(nccBaseline: Double, fpBaseline: Double, a: AmbangVerifikasi) -> (minNCC: Double, maksFP: Double) {
        (min(a.cocokAcuan.minNCC, nccBaseline - 0.05), max(a.cocokAcuan.pengaliBaseline * fpBaseline, a.cocokAcuan.minBatasFeaturePrint))
    }

    /// Normalized cross-correlation dua thumbnail sama ukuran (−1…1).
    static func ncc(_ x: [UInt8], _ y: [UInt8]) -> Double {
        guard x.count == y.count, !x.isEmpty else { return 0 }
        let a = x.map(Double.init), b = y.map(Double.init), ma = mean(a), mb = mean(b)
        var sab = 0.0, saa = 0.0, sbb = 0.0
        for i in a.indices { let p = a[i] - ma, q = b[i] - mb; sab += p * q; saa += p * p; sbb += q * q }
        return sab / max((saa * sbb).squareRoot(), 1e-9)
    }

    static func normal(_ p: [Double]) -> [Double] { let m = max(mean(p), 1e-9); return p.map { $0 / m } }

    /// Deviasi relatif terbesar antarsel peta cahaya (keduanya sudah dinormalisasi).
    static func deviasiPeta(_ p: [Double], _ acuan: [Double]) -> Double {
        zip(p, acuan).map { abs($0 / max($1, 1e-9) - 1) }.max() ?? 0
    }
}

extension SIMD4 where Scalar == Float { var xyz: SIMD3<Float> { SIMD3(x, y, z) } }

// MARK: - Ukur ARKit (meter, dunia ARKit, Y ke atas)

extension Rumus {
    /// Titik potong garis bidik dengan bidang datar setinggi `y`; nil kalau garis tidak mengarah ke bidang itu.
    static func potongDatar(asal: SIMD3<Float>, arah: SIMD3<Float>, y: Float) -> SIMD3<Float>? {
        guard abs(arah.y) > 1e-4 else { return nil }
        let t = (y - asal.y) / arah.y
        return t > 0 ? asal + t * arah : nil
    }

    /// Sudut garis bidik di bawah horizontal, derajat (90 = tegak lurus ke bawah).
    static func sudutBidik(_ arah: SIMD3<Float>) -> Double { Double(asin(-arah.y / max(simd_length(arah), 1e-9))) * 180 / .pi }

    /// Median per sumbu dan sebaran terjauh dari median (cm).
    static func halus(_ t: [SIMD3<Float>]) -> (titik: SIMD3<Float>, goyangCM: Double)? {
        guard !t.isEmpty else { return nil }
        let m = SIMD3<Float>(Float(median(t.map { Double($0.x) })), Float(median(t.map { Double($0.y) })), Float(median(t.map { Double($0.z) })))
        return (m, Double(t.map { simd_distance($0, m) }.max()!) * 100)
    }
}

// MARK: - Jarak dari kartu (pinhole)

struct HasilKartu { var jarakCM: Double; var rasio: Double; var sisiPanjangPX: Double }

extension Rumus {
    /// 4 sudut kartu berurutan (piksel frame), fx/fy dari intrinsics. Bidang kartu sejajar sensor: luas di foto = luas asli · (f/Z)²,
    /// jadi Z = √(luas asli ÷ luas ternormalisasi). Memakai luas (bukan satu sisi) supaya kemiringan kecil hanya berpengaruh ±√cos.
    static func jarakKartu(_ s: [CGPoint], fx: Double, fy: Double, a: AmbangVerifikasi) -> HasilKartu? {
        guard s.count == 4, fx > 0, fy > 0 else { return nil }
        let n = s.map { CGPoint(x: $0.x / fx, y: $0.y / fy) }
        let luas = abs((0..<4).map { n[$0].x * n[($0 + 1) % 4].y - n[($0 + 1) % 4].x * n[$0].y }.reduce(0, +)) / 2
        guard luas > 0 else { return nil }
        func d(_ p: [CGPoint], _ i: Int) -> Double { hypot(p[i].x - p[(i + 1) % 4].x, p[i].y - p[(i + 1) % 4].y) }
        let s1 = (d(n, 0) + d(n, 2)) / 2, s2 = (d(n, 1) + d(n, 3)) / 2
        let px = max((d(s, 0) + d(s, 2)) / 2, (d(s, 1) + d(s, 3)) / 2)
        return HasilKartu(jarakCM: (a.kartu.panjangMM * a.kartu.lebarMM / luas).squareRoot() / 10, rasio: max(s1, s2) / min(s1, s2), sisiPanjangPX: px)
    }

    /// Koreksi tepi: sudut dari Vision rata-rata ±19 px di luar tepi kartu (uji 7/11/2026), tetap dalam piksel, jadi meleset makin jauh.
    /// Kalau setiap sisi kelebihan m yang sama: (P+2m)/(L+2m) ≠ rasio asli. Dari rasio kartu yang diketahui, P = r·(a−b)/(r−1),
    /// lalu jarak = panjang asli ÷ P. Bentuk ternormalisasi (÷fx, ÷fy) supaya hasilnya langsung dalam meter.
    static func jarakKoreksiTepi(_ s: [CGPoint], fx: Double, fy: Double, a: AmbangVerifikasi) -> Double? {
        guard s.count == 4 else { return nil }
        let n = s.map { CGPoint(x: $0.x / fx, y: $0.y / fy) }
        func d(_ i: Int) -> Double { hypot(n[i].x - n[(i + 1) % 4].x, n[i].y - n[(i + 1) % 4].y) }
        let s1 = (d(0) + d(2)) / 2, s2 = (d(1) + d(3)) / 2, p = max(s1, s2), l = min(s1, s2)
        let r = a.kartu.panjangMM / a.kartu.lebarMM, asli = r * (p - l) / (r - 1)
        return asli > 0 ? a.kartu.panjangMM / asli / 10 : nil
    }

    /// 4 sudut dasar dalam (piksel frame) di bidang yang sama dengan kartu, jadi 1 px = Z/fx. Sisi berhadapan dirata-rata.
    /// ponytail: pinhole tanpa homografi; cukup selama miring ≤ 5° (gerbang kartu). Pakai homografi kartu kalau HP boleh lebih miring.
    static func dasarDariSudut(_ s: [CGPoint], fx: Double, fy: Double, jarakCM: Double) -> (p: Double, l: Double)? {
        guard s.count == 4, fx > 0, fy > 0 else { return nil }
        func d(_ i: Int) -> Double {
            let j = (i + 1) % 4
            return hypot((s[i].x - s[j].x) / fx, (s[i].y - s[j].y) / fy) * jarakCM
        }
        let s1 = (d(0) + d(2)) / 2, s2 = (d(1) + d(3)) / 2
        return (max(s1, s2), min(s1, s2))
    }

    /// Alasan wadah belum terverifikasi; kosong = terverifikasi. Ukuran box tidak dibatasi; yang dicek fungsinya:
    /// 1. jarak kamera dekat jarak video latih, supaya ukuran benur di foto sama dengan yang dikenal model;
    /// 2. seluruh dasar terlihat: 4 sudut dasar (0–1 terhadap frame) tidak masuk pita tepi.
    static func catatanWadah(jarakCM: Double, sudutDasar: [CGPoint], a: AmbangVerifikasi) -> [String] {
        let r = a.jarakKameraKeDasarCM, t = a.hasil.pitaTepi
        var c = [String]()
        if !r.berisi(jarakCM) {
            c.append("Jarak kamera ke dasar \(angka(jarakCM)) cm, harus \(angka(r.min, 0))–\(angka(r.max, 0)) cm" +
                     (jarakCM < r.min ? ". Naikkan HP." : ". Turunkan HP."))
        }
        if sudutDasar.contains(where: { $0.x < t || $0.x > 1 - t || $0.y < t || $0.y > 1 - t }) {
            c.append("Sudut dasar terlalu dekat ke tepi gambar. Taruh HP di tengah box, atau naikkan HP.")
        }
        return c
    }

    /// FOV setelah zoom digital: tan(FOV'/2) = tan(FOV/2) ÷ zoom.
    static func fovEfektif(_ fovDerajat: Double, zoom: Double) -> Double {
        2 * atan(tan(fovDerajat / 2 * .pi / 180) / max(zoom, 1)) * 180 / .pi
    }

    /// Sisi panjang foto untuk deteksi, supaya benur sama besar dengan di video latih: ukuran benur ∝ sisi ÷ jarak.
    /// Contoh: HP 20% lebih tinggi dari saat latih → foto 20% lebih besar. Tidak melebihi resolusi asli foto.
    static func sisiDeteksi(jarakCM: Double, asliPX: Double, a: AmbangVerifikasi) -> Double {
        min(Double(a.deteksi.sisiPanjangPX) * jarakCM / a.deteksi.jarakLatihCM, asliPX)
    }

    static func kartuSah(_ k: HasilKartu, a: AmbangVerifikasi) -> Bool {
        abs(k.rasio / (a.kartu.panjangMM / a.kartu.lebarMM) - 1) <= a.kartu.toleransiRasio
    }

    /// fx dari FOV horizontal format kamera, kalau intrinsics tidak dikirim.
    static func fxDariFOV(lebarPX: Double, fovDerajat: Double) -> Double { lebarPX / 2 / tan(fovDerajat / 2 * .pi / 180) }
}

enum TrackingUkur { case normal, mulai, cepat, polos }

/// Kondisi saat ini ketika mengukur; nil = belum ada nilainya (mis. tanda bidik belum menempel).
struct KondisiUkur {
    var tracking: TrackingUkur
    var cahayaLumen: Double?
    var adaLantai: Bool
    var adaTutup: Bool
    var bidikLantai = false       // tanda bidik ada di bidang lantai, padahal yang perlu tutup box
    var jarakCM: Double?
    var sudutDerajat: Double?
    var goyangCM: Double?
}

/// Petunjuk live untuk kondisi yang membuat ukuran tidak akurat, urut dari yang paling mendasar. nil = siap tekan +.
func petunjukUkur(_ k: KondisiUkur, a: AmbangVerifikasi) -> String? {
    let r = a.arkit
    switch k.tracking {
    case .mulai: return "Gerakkan HP pelan ke kiri-kanan supaya ruangan terbaca."
    case .cepat: return "HP bergerak terlalu cepat. Gerakkan lebih pelan."
    case .polos: return "Kamera melihat permukaan terlalu polos atau gelap. Tambah cahaya, atau arahkan sebentar ke lantai yang bermotif."
    case .normal: break
    }
    if let c = k.cahayaLumen, c < r.minCahayaLumen { return "Ruangan terlalu gelap. Nyalakan lampu." }
    if !k.adaLantai { return "Arahkan HP ke lantai di samping box, gerakkan pelan sampai lantai terdeteksi." }
    if !k.adaTutup {
        return k.bidikLantai ? "Bidang ini terbaca sebagai lantai. Kalau ini tutup box, arahkan HP ke lantai di samping box dulu."
            : "Arahkan ke tengah tutup box, gerakkan pelan sampai lingkaran putih."
    }
    if let j = k.jarakCM, j > r.jarakBidikCM.max { return "Terlalu jauh (\(angka(j, 0)) cm). Dekati box." }
    if let j = k.jarakCM, j < r.jarakBidikCM.min { return "Terlalu dekat. Mundur sedikit." }
    if let s = k.sudutDerajat, s < r.minSudutBidikDerajat { return "HP terlalu landai. Angkat HP lebih tinggi, arahkan ke bawah ke tutup box." }
    if let g = k.goyangCM, g > r.maksGoyangCM { return "Tahan HP diam sebentar." }
    return nil
}

/// Wajib daftar ulang jika umur > masa berlaku, model HP berbeda, atau versi config berbeda.
func perluDaftarUlang(_ p: WadahProfile, a: AmbangVerifikasi, modelHP: String, sekarang: Date = Date()) -> Bool {
    p.versi != a.versi || p.modelHP != modelHP || sekarang.timeIntervalSince(p.tanggalDaftar) > Double(a.masaBerlakuDaftarHari) * 86_400
}

// MARK: - Gerbang kamera

struct UkuranFrame {
    var ketajaman = 0.0
    var kemiringan = 0.0
    var kecerahan = 0.0
    var peta: [Double] = []     // dinormalisasi
    var thumb: [UInt8] = []
    var iso = 0.0
    var jarakFP: Double?        // ke acuan, diperbarui ±2× per detik
}

/// Foto acuan: senter cukup, gambar tajam, HP sejajar (mode pegang).
func gerbangAcuan(_ u: UkuranFrame, pegang: Bool, a: AmbangVerifikasi) -> HasilVerifikasi {
    let k = a.kamera
    var h = HasilVerifikasi()
    h.cek("ISO", u.iso, "≤ \(angka(Double(k.maksISO), 0))", lolos: u.iso <= Double(k.maksISO), .cahayaLemah)
    h.cek("ketajaman", u.ketajaman, "≥ \(angka(k.minKetajaman, 0))", lolos: u.ketajaman >= k.minKetajaman, .blur)
    if pegang { h.cek("kemiringan °", u.kemiringan, "≤ \(angka(k.maksKemiringanPegangDerajat, 0))", lolos: u.kemiringan <= k.maksKemiringanPegangDerajat, .hpMiring) }
    return h
}

/// Cek wadah: tampilan live dibanding foto acuan.
func gerbangCocok(_ u: UkuranFrame, profil p: WadahProfile, a: AmbangVerifikasi) -> HasilVerifikasi {
    let amb = Rumus.ambangCocok(nccBaseline: p.nccBaseline, fpBaseline: p.fpBaseline, a: a)
    var h = HasilVerifikasi()
    let n = Rumus.ncc(u.thumb, p.acuan.thumb)
    h.cek("NCC", n, "≥ \(angka(amb.minNCC, 2))", lolos: n >= amb.minNCC, .posisiBeda)
    if let f = u.jarakFP { h.cek("feature print", f, "≤ \(angka(amb.maksFP, 2))", lolos: f <= amb.maksFP, .wadahBerbeda) }
    let dev = Rumus.deviasiPeta(u.peta, p.acuan.peta)
    h.cek("deviasi cahaya", dev, "≤ \(angka(a.cocokAcuan.maksDeviasiPetaCahaya, 2))", lolos: dev <= a.cocokAcuan.maksDeviasiPetaCahaya, .cahayaBeda)
    let k = u.kecerahan / max(p.acuan.kecerahan, 1) - 1
    h.cek("selisih kecerahan", k, "±\(angka(a.kamera.toleransiKecerahan, 2))", lolos: abs(k) <= a.kamera.toleransiKecerahan, .cahayaBeda)
    return h
}

/// Cek ringan sebelum foto hitung: tajam, sejajar (mode pegang), kecerahan dalam toleransi acuan.
func gerbangHitung(_ u: UkuranFrame, profil p: WadahProfile, a: AmbangVerifikasi) -> HasilVerifikasi {
    let kam = a.kamera
    var h = HasilVerifikasi()
    h.cek("ketajaman", u.ketajaman, "≥ \(angka(kam.minKetajaman, 0))", lolos: u.ketajaman >= kam.minKetajaman, .blur)
    if p.mode == .pegang { h.cek("kemiringan °", u.kemiringan, "≤ \(angka(kam.maksKemiringanPegangDerajat, 0))", lolos: u.kemiringan <= kam.maksKemiringanPegangDerajat, .hpMiring) }
    let k = u.kecerahan / max(p.acuan.kecerahan, 1) - 1
    h.cek("selisih kecerahan", k, "±\(angka(kam.toleransiKecerahan, 2))", lolos: abs(k) <= kam.toleransiKecerahan, .cahayaBeda)
    return h
}

/// Kanal Y yang diperkecil.
// ponytail: Swift biasa pada gambar ≤ 480 px, bukan vDSP. Ganti ke Accelerate kalau profil CPU menunjukkan lag.
struct Luma {
    let w: Int, h: Int
    var px: [UInt8]

    func v(_ x: Int, _ y: Int) -> Double { Double(px[y * w + x]) }
    func rata() -> Double { mean(px.map(Double.init)) }

    /// Rata-rata tiap sel grid n × n, baris demi baris.
    func sel(n: Int) -> [Double] {
        var jumlah = [Double](repeating: 0, count: n * n), banyak = [Double](repeating: 0, count: n * n)
        for y in 0..<h { for x in 0..<w { let i = (y * n / h) * n + x * n / w; jumlah[i] += v(x, y); banyak[i] += 1 } }
        return zip(jumlah, banyak).map { $0 / max($1, 1) }
    }

    /// Varians Laplacian 4-tetangga.
    func ketajaman() -> Double {
        guard w >= 3, h >= 3 else { return 0 }
        var s = 0.0, s2 = 0.0, n = 0.0
        for y in 1..<(h - 1) { for x in 1..<(w - 1) {
            let l = v(x - 1, y) + v(x + 1, y) + v(x, y - 1) + v(x, y + 1) - 4 * v(x, y)
            s += l; s2 += l * l; n += 1
        }}
        return s2 / n - (s / n) * (s / n)
    }
}

// MARK: - Deteksi dan cek hasil

struct Deteksi { var kotak: CGRect; var keyakinan: Double }   // ternormalisasi 0–1, origin kiri-atas

func iou(_ a: CGRect, _ b: CGRect) -> Double {
    let i = a.intersection(b); if i.isNull { return 0 }
    let ai = i.width * i.height; return ai / (a.width * a.height + b.width * b.height - ai)
}

/// Irisan ÷ kotak terkecil. Di perbatasan ubin, potongan benur tersisa di dalam kotak utuh; IoU-nya kecil, IoS-nya besar.
func ios(_ a: CGRect, _ b: CGRect) -> Double {
    let i = a.intersection(b); if i.isNull { return 0 }
    return i.width * i.height / min(a.width * a.height, b.width * b.height)
}

// ponytail: NMS rakus O(n²), cukup untuk ~4.000 deteksi; pakai grid sel kalau jumlah naik jauh.
func nms(_ d: [Deteksi], batas: Double, ukuran: (CGRect, CGRect) -> Double = iou) -> [Deteksi] {
    var simpan = [Deteksi]()
    for k in d.sorted(by: { $0.keyakinan > $1.keyakinan }) where !simpan.contains(where: { ukuran($0.kotak, k.kotak) > batas }) {
        simpan.append(k)
    }
    return simpan
}

/// Keluaran mentah YOLO [1, 5, N]: baris 0–3 = cx, cy, w, h dalam piksel input, baris 4 = skor. Lalu NMS IoU 0,7 per ubin
/// seperti `model.predict` Ultralytics (NMS bawaan export CoreML menghasilkan +2–4% kotak).
func dekodeYOLO(n: Int, sisi: Double, conf: Double, nilai: (Int, Int) -> Double) -> [Deteksi] {
    var d = [Deteksi]()
    for i in 0..<n where nilai(4, i) >= conf {
        let w = nilai(2, i) / sisi, h = nilai(3, i) / sisi
        d.append(Deteksi(kotak: CGRect(x: nilai(0, i) / sisi - w / 2, y: nilai(1, i) / sisi - h / 2, width: w, height: h),
                         keyakinan: nilai(4, i)))
    }
    return nms(d, batas: 0.7)
}

/// Cek hasil per foto. `ukuran` = piksel gambar deteksi, `panjangPX` = panjang benur stadia yang diharapkan.
/// Mengembalikan kotak bermasalah untuk ditandai di foto. Tetangga dicari lewat grid sel.
func validasiFoto(_ d: [Deteksi], ukuran: CGSize, panjangPX: Double, a: AmbangVerifikasi) -> (hasil: HasilVerifikasi, tanda: [CGRect]) {
    let r = a.hasil
    var h = HasilVerifikasi()
    h.cek("jumlah", Double(d.count), "1–\(a.maksKapasitas)", lolos: !d.isEmpty, .wadahKosong)
    guard !d.isEmpty else { return (h, []) }   // cek lain tidak bermakna
    h.cek("jumlah", Double(d.count), "1–\(a.maksKapasitas)", lolos: d.count <= a.maksKapasitas, .terlaluBanyak)
    let n = Double(d.count)

    let tepi = d.indices.filter { min(d[$0].kotak.midX, d[$0].kotak.midY, 1 - d[$0].kotak.midX, 1 - d[$0].kotak.midY) < r.pitaTepi }
    h.cek("di pita tepi", Double(tepi.count), "0", lolos: tepi.isEmpty, .dasarTerpotong)

    let k = d.map { CGRect(x: $0.kotak.minX * ukuran.width, y: $0.kotak.minY * ukuran.height,
                           width: $0.kotak.width * ukuran.width, height: $0.kotak.height * ukuran.height) }
    let skala = median(k.map { max($0.width, $0.height) })
    h.cek("panjang benur px", skala, "\(angka(panjangPX * (1 - r.toleransiSkalaBenur)))–\(angka(panjangPX * (1 + r.toleransiSkalaBenur)))",
          lolos: abs(skala / panjangPX - 1) <= r.toleransiSkalaBenur, .skalaTidakSesuai)

    let besar = median(k.map { ($0.width * $0.height).squareRoot() })
    let batasDekat = r.faktorJarakTerlaluDekat * besar
    let sel = max(batasDekat, k.map { max($0.width, $0.height) }.max()!, 1)
    func kunci(_ b: CGRect) -> SIMD2<Int> { SIMD2(Int(b.midX / sel), Int(b.midY / sel)) }
    var grid = [SIMD2<Int>: [Int]]()
    for (i, b) in k.enumerated() { grid[kunci(b), default: []].append(i) }
    var dekat = Set<Int>(), tumpuk = Set<Int>()
    for (i, b) in k.enumerated() {
        let c = kunci(b)
        for dx in -1...1 { for dy in -1...1 { for j in grid[c &+ SIMD2(dx, dy)] ?? [] where j != i {
            if iou(b, k[j]) > r.iouTumpuk { tumpuk.insert(i) }
            else if hypot(b.midX - k[j].midX, b.midY - k[j].midY) < batasDekat { dekat.insert(i) }
        }}}
    }
    h.cek("terlalu dekat", Double(dekat.count) / n, "≤ \(angka(r.maksPersenTerlaluDekat, 2))", lolos: Double(dekat.count) / n <= r.maksPersenTerlaluDekat, .terlaluRapat)
    h.cek("bertumpuk", Double(tumpuk.count) / n, "≤ \(angka(r.maksPersenTumpuk, 2))", lolos: Double(tumpuk.count) / n <= r.maksPersenTumpuk, .bertumpuk)

    let rendah = d.indices.filter { d[$0].keyakinan < r.batasKeyakinanRendah }
    let rata = mean(d.map(\.keyakinan)), porsiRendah = Double(rendah.count) / n
    h.cek("rata keyakinan", rata, "≥ \(angka(r.minRataKeyakinan, 2))", lolos: rata >= r.minRataKeyakinan, .keyakinanRendah)
    h.cek("keyakinan rendah", porsiRendah, "≤ \(angka(r.maksPersenKeyakinanRendah, 2))", lolos: porsiRendah <= r.maksPersenKeyakinanRendah, .keyakinanRendah)

    var tanda = tepi.map { d[$0].kotak }
    if h.masalah.contains(.terlaluRapat) { tanda += dekat.map { d[$0].kotak } }
    if h.masalah.contains(.bertumpuk) { tanda += tumpuk.map { d[$0].kotak } }
    if h.masalah.contains(.keyakinanRendah) { tanda += rendah.map { d[$0].kotak } }
    return (h, tanda)
}

/// Antarfoto: foto gagal dibuang, minimal M lolos, (maks − min) ÷ median ≤ batas. Hasil = median.
func validasiAntarFoto(_ perFoto: [HasilVerifikasi], jumlah: [Int], a: AmbangVerifikasi) -> (hasil: HasilVerifikasi, jumlah: Int?) {
    var h = HasilVerifikasi()
    let lolos = zip(perFoto, jumlah).filter { $0.0.lolos }.map { Double($0.1) }
    guard lolos.count >= a.hasil.minFotoLolos else {
        let m = perFoto.flatMap(\.masalah).min { $0.urutan < $1.urutan } ?? .hasilTidakStabil   // masalah terpenting dari foto gagal
        h.cek("foto lolos", Double(lolos.count), "≥ \(a.hasil.minFotoLolos)", lolos: false, m)
        return (h, nil)
    }
    let med = median(lolos), selisih = (lolos.max()! - lolos.min()!) / max(med, 1)
    h.cek("selisih antarfoto", selisih, "≤ \(angka(a.hasil.maksSelisihAntarFoto, 2))", lolos: selisih <= a.hasil.maksSelisihAntarFoto, .hasilTidakStabil)
    return (h, h.lolos ? Int(med.rounded()) : nil)
}

// MARK: - Statistik

func mean(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.reduce(0, +) / Double(a.count) }
func median(_ a: [Double]) -> Double {
    let s = a.sorted(); return s.isEmpty ? 0 : s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}
