// Cek logika inti di Mac:
// swiftc ShrimpWatch/Inti.swift Cek/main.swift -o /tmp/cek && /tmp/cek ShrimpWatch/ambang.json
import Foundation
import CoreGraphics
import simd

setvbuf(stdout, nil, _IONBF, 0)
let a = try! AmbangVerifikasi.muat(URL(fileURLWithPath: CommandLine.arguments[1]))

// Spesifikasi box
assert(Rumus.cekSpesifikasi(UkuranBox(panjang: 52.3, lebar: 36.8, tinggi: 34.1), a: a).isEmpty)
assert(Rumus.cekSpesifikasi(UkuranBox(panjang: 52, lebar: 40.2, tinggi: 34), a: a) == ["Lebar 40,2 cm, maksimal 38 cm."])
assert(Rumus.cekSpesifikasi(UkuranBox(panjang: 45, lebar: 37, tinggi: 40), a: a).count == 2)

// Air dan jarak: box nominal 48 × 33 dalam → 792 → 800 ml; dua box 34 cm → 66 cm
let dlm = Rumus.dalam(UkuranBox(panjang: 52, lebar: 37, tinggi: 34), a: a)
assert(dlm.p == 48 && dlm.l == 33 && Rumus.airML(p: dlm.p, l: dlm.l, a: a) == 800)
assert(Rumus.jarakTaruh(tinggiTumpukanCM: 68, a: a) == 66 && a.jarakKameraKeDasarCM.berisi(44))
assert(abs(Rumus.jarakPegang(kameraY: 0.75, lantaiY: 0.1, a: a) - 63) < 1e-9)

// Ukur ARKit: garis bidik dari 1 m di atas lantai, miring 45°, dipotong bidang tutup setinggi 46 cm
let arah = simd_normalize(SIMD3<Float>(0, -1, -1))
let kenaTutup = Rumus.potongDatar(asal: SIMD3(0, 1, 0), arah: arah, y: 0.46)!
assert(abs(kenaTutup.y - 0.46) < 1e-6 && abs(kenaTutup.z + 0.54) < 1e-5)
assert(Rumus.potongDatar(asal: SIMD3(0, 1, 0), arah: SIMD3(0, 1, 0), y: 0.46) == nil)   // menghadap ke atas
assert(abs(Rumus.sudutBidik(arah) - 45) < 1e-4)
let h = Rumus.halus([SIMD3(0, 0, 0), SIMD3(0.001, 0, 0), SIMD3(0.5, 0, 0)])!          // satu frame meleset 50 cm tidak menggeser median
assert(h.titik.x == 0.001 && abs(h.goyangCM - 49.9) < 1e-3)
var kon = KondisiUkur(tracking: .normal, cahayaLumen: 1000, adaLantai: true, adaTutup: true, jarakCM: 80, sudutDerajat: 50, goyangCM: 0.3)
assert(petunjukUkur(kon, a: a) == nil)
kon.goyangCM = 2; assert(petunjukUkur(kon, a: a) == "Tahan HP diam sebentar.")
kon.sudutDerajat = 15; assert(petunjukUkur(kon, a: a)!.hasPrefix("HP terlalu landai"))
kon.jarakCM = 200; assert(petunjukUkur(kon, a: a)!.hasPrefix("Terlalu jauh"))
kon.adaTutup = false; kon.bidikLantai = true; assert(petunjukUkur(kon, a: a)!.hasPrefix("Bidang ini terbaca sebagai lantai"))
kon.adaLantai = false; assert(petunjukUkur(kon, a: a)!.hasPrefix("Arahkan HP ke lantai"))
kon.cahayaLumen = 100; assert(petunjukUkur(kon, a: a) == "Ruangan terlalu gelap. Nyalakan lampu.")
kon.tracking = .cepat; assert(petunjukUkur(kon, a: a)!.hasPrefix("HP bergerak terlalu cepat"))

// Jarak dari kartu: kartu 85,6 × 53,98 mm di 60 cm, fx = fy = 3000 px, tidak di tengah frame → 60 cm
let (kx, ky) = (85.6 * 3000 / 600 / 2, 53.98 * 3000 / 600 / 2)
let sudutKartu = [(-kx, -ky), (kx, -ky), (kx, ky), (-kx, ky)].map { CGPoint(x: 1500 + $0.0, y: 700 + $0.1) }
let hk = Rumus.jarakKartu(sudutKartu, fx: 3000, fy: 3000, a: a)!
assert(abs(hk.jarakCM - 60) < 1e-9 && Rumus.kartuSah(hk, a: a) && abs(hk.sisiPanjangPX - 428) < 1e-9)
let kotak = Rumus.jarakKartu([CGPoint(x: 0, y: 0), CGPoint(x: 480, y: 0), CGPoint(x: 480, y: 330), CGPoint(x: 0, y: 330)], fx: 3000, fy: 3000, a: a)!
assert(!Rumus.kartuSah(kotak, a: a))   // dasar box 48 × 33 bukan kartu
// Koreksi tepi: kotak Vision 19 px lebih besar di tiap sisi → jarak mentah meleset, koreksi kembali ke 60 cm
let lebih = [(-kx - 19, -ky - 19), (kx + 19, -ky - 19), (kx + 19, ky + 19), (-kx - 19, ky + 19)].map { CGPoint(x: 1500 + $0.0, y: 700 + $0.1) }
assert(Rumus.jarakKartu(lebih, fx: 3000, fy: 3000, a: a)!.jarakCM < 56)
assert(abs(Rumus.jarakKoreksiTepi(lebih, fx: 3000, fy: 3000, a: a)! - 60) < 1e-6)
assert(abs(Rumus.jarakKoreksiTepi(sudutKartu, fx: 3000, fy: 3000, a: a)! - 60) < 1e-6)
// Dasar dari 4 sudut: 48 × 33 cm di 60 cm, fx = fy = 2800 → setengah sisi 1120 × 770 px
let sudutDasar = [(-1120.0, -770.0), (1120, -770), (1120, 770), (-1120, 770)].map { CGPoint(x: 1920 + $0.0, y: 1080 + $0.1) }
let dsr = Rumus.dasarDariSudut(sudutDasar, fx: 2800, fy: 2800, jarakCM: 60)!
assert(abs(dsr.p - 48) < 1e-9 && abs(dsr.l - 33) < 1e-9)
let dasarAman = [CGPoint(x: 0.2, y: 0.1), CGPoint(x: 0.8, y: 0.1), CGPoint(x: 0.8, y: 0.9), CGPoint(x: 0.2, y: 0.9)]
assert(Rumus.catatanWadah(jarakCM: 44, sudutDasar: dasarAman, a: a).isEmpty)
assert(Rumus.catatanWadah(jarakCM: 30, sudutDasar: dasarAman, a: a) == ["Jarak kamera ke dasar 30,0 cm, harus 35–55 cm. Naikkan HP."])
assert(Rumus.catatanWadah(jarakCM: 44, sudutDasar: dasarAman + [CGPoint(x: 0.99, y: 0.5)], a: a).count == 1)

// Lensa 0.6x: FOV 90° dengan zoom 2 → tan 0,5 → 53,13°; skala deteksi mengikuti jarak, dibatasi resolusi asli
assert(abs(Rumus.fovEfektif(90, zoom: 2) - 53.130102354) < 1e-6 && Rumus.fovEfektif(70, zoom: 1) == 70)
func sd(_ z: Double, _ f: Double) -> Double { Rumus.sisiDeteksi(jarakCM: z, fovDerajat: f, fovLatihDerajat: 100, asliPX: 4032, a: a) }
assert(abs(sd(44, 100) - 1920) < 1e-9 && abs(sd(55, 100) - 2400) < 1e-9 && sd(200, 100) == 4032)   // lensa sama: ikut jarak
assert(abs(sd(44, 70) - 1920 * tan(35 * Double.pi / 180) / tan(50 * Double.pi / 180)) < 1e-9 && sd(44, 70) < 1200)   // 1x: diperkecil
assert(abs(Rumus.fxDariFOV(lebarPX: 2000, fovDerajat: 90) - 1000) < 1e-9)

// Skala benur: 66 cm, FOV 67°, sisi panjang 1920 px → 0,455 mm/px → PL-10 ±19 px
let pPX = Rumus.panjangPX(.pl10, jarakCM: 66, fovDerajat: 67, lebarFotoPX: 1920)
print("panjang PL-10 di 66 cm:", angka(pPX), "px")
assert(abs(pPX - 8.65 / (2 * 660 * tan(33.5 * Double.pi / 180) / 1920)) < 1e-9)

// Ambang cocok dari baseline
let amb = Rumus.ambangCocok(nccBaseline: 0.97, fpBaseline: 0.03, a: a)
assert(amb.minNCC == 0.80 && amb.maksFP == 0.15)
let amb2 = Rumus.ambangCocok(nccBaseline: 0.82, fpBaseline: 0.1, a: a)
assert(abs(amb2.minNCC - 0.77) < 1e-9 && abs(amb2.maksFP - 0.3) < 1e-9)
// Dasar polos (log 15:38, HP diam, baseline 0,22): cek NCC dilewati, feature print tetap.
let amb3 = Rumus.ambangCocok(nccBaseline: 0.22, fpBaseline: 0.26, a: a)
assert(amb3.minNCC < 0 && abs(amb3.maksFP - 0.78) < 1e-9)

// NCC: sama = 1, terbalik = −1
let t: [UInt8] = (0..<3072).map { UInt8($0 % 251) }
assert(abs(Rumus.ncc(t, t) - 1) < 1e-9 && abs(Rumus.ncc(t, t.map { 255 - $0 }) + 1) < 1e-9)
assert(Rumus.deviasiPeta([1.2, 0.8], [1, 1]) > 0.19)

// Cek hasil: benur acak di 1440 × 1920, kotak sepanjang benur PL-10
var rng = SystemRandomNumberGenerator()
let ukuran = CGSize(width: 1440, height: 1920)
func acak(_ n: Int, px: Double = pPX, yakin: ClosedRange<Double> = 0.8...0.95, tepi: Double = 0.05) -> [Deteksi] {
    (0..<n).map { _ in
        let cx = Double.random(in: tepi...(1 - tepi), using: &rng), cy = Double.random(in: tepi...(1 - tepi), using: &rng)
        let w = px / ukuran.width, h = px * 0.4 / ukuran.height
        return Deteksi(kotak: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), keyakinan: .random(in: yakin, using: &rng))
    }
}
for n in [500, 1000, 2000] {
    let v = validasiFoto(acak(n), ukuran: ukuran, panjangPX: pPX, a: a)
    print("acak \(n) ekor:", v.hasil.masalah.map { $0.rawValue }, "terlalu dekat", angka(v.hasil.ukur["terlalu dekat"]!.nilai, 3),
          "bertumpuk", angka(v.hasil.ukur["bertumpuk"]!.nilai, 3))
}
assert(validasiFoto(acak(100), ukuran: ukuran, panjangPX: pPX, a: a).hasil.lolos)   // acak 500 sudah 4% bertumpuk (batas 2%)
assert(validasiFoto([], ukuran: ukuran, panjangPX: pPX, a: a).hasil.masalah == [.wadahKosong])
assert(validasiFoto(acak(300, tepi: 0), ukuran: ukuran, panjangPX: pPX, a: a).hasil.masalah.contains(.dasarTerpotong))
assert(validasiFoto(acak(300, px: pPX * 0.5), ukuran: ukuran, panjangPX: pPX, a: a).hasil.masalah.contains(.skalaTidakSesuai))
assert(validasiFoto(acak(300, yakin: 0.5...0.6), ukuran: ukuran, panjangPX: pPX, a: a).hasil.masalah.contains(.keyakinanRendah))
assert(validasiFoto(acak(4001, px: 4), ukuran: ukuran, panjangPX: 4, a: a).hasil.masalah.contains(.terlaluBanyak))

// Antarfoto
let ok = HasilVerifikasi()
var gagal = HasilVerifikasi(); gagal.cek("x", 1, "", lolos: false, .bertumpuk)
assert(validasiAntarFoto([ok, ok, ok, gagal, ok], jumlah: [500, 502, 505, 900, 501], a: a).jumlah == 502)   // median 501,5
assert(validasiAntarFoto([ok, ok, ok], jumlah: [500, 520, 505], a: a).hasil.masalah == [.hasilTidakStabil])
assert(validasiAntarFoto([ok, ok, gagal, gagal, gagal], jumlah: [1, 1, 1, 1, 1], a: a).hasil.masalah == [.bertumpuk])

// NMS: potongan benur di perbatasan ubin terbuang lewat IoS, kotak terpisah tetap
let utuh = Deteksi(kotak: CGRect(x: 0.1, y: 0.1, width: 0.02, height: 0.02), keyakinan: 0.9)
let potongan = Deteksi(kotak: CGRect(x: 0.11, y: 0.1, width: 0.01, height: 0.02), keyakinan: 0.6)
let lain = Deteksi(kotak: CGRect(x: 0.5, y: 0.5, width: 0.02, height: 0.02), keyakinan: 0.7)
assert(nms([potongan, utuh, lain], batas: a.hasil.iouNMS, ukuran: ios).count == 2)

// HP diam: awal (sensor belum terisi) dianggap bergerak; HP ditaruh lolos; tangan menggeser gagal
do {
    var u = UkuranFrame(); u.iso = 100
    precondition(gerbangAcuan(u, pegang: false, a: a).masalah.contains(.goyang))
    u.putar = 0.5; u.geser = 0.004
    precondition(gerbangAcuan(u, pegang: false, a: a).lolos)
    u.putar = 20
    precondition(gerbangAcuan(u, pegang: false, a: a).masalah.contains(.goyang))
}
// NCC posisi: geser 2 px tetap ≈ 1; gambar beda tetap rendah
do {
    let w = 48, h = 64
    func gambar(_ ox: Int, _ oy: Int) -> [UInt8] {
        (0..<(w * h)).map { k in
            let i = k % w - ox, j = k / w - oy
            return UInt8((i > 10 && i < 30 && j > 15 && j < 45 ? 200 : 60) + (i * 3 + j) % 7)
        }
    }
    let x = gambar(0, 0), y = gambar(2, 1)
    precondition(Rumus.nccPosisi(x, y) > 0.95, "geser kecil harus tetap cocok")
    precondition(Rumus.ncc(x, y) < Rumus.nccPosisi(x, y))
    let z = (0..<(w * h)).map { k in UInt8(k % w < 24 ? 200 : 60) }
    precondition(Rumus.nccPosisi(x, z) < 0.6, "gambar lain harus rendah: \(Rumus.nccPosisi(x, z))")
}
print("semua cek lolos")
