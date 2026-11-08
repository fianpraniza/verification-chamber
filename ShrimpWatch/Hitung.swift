import CoreImage
import CoreML
import UIKit
import Vision

// MARK: - Sidik visual dan render

enum Visi {
    static let ctx = CIContext()

    static func sidik(_ pb: CVPixelBuffer) -> VNFeaturePrintObservation? {
        let r = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pb).perform([r])
        return r.results?.first
    }

    static func jarak(_ a: Data, _ b: Data) -> Double? {
        guard let x = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: a),
              let y = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: b) else { return nil }
        var d: Float = 0
        return (try? x.computeDistance(&d, to: y)) != nil ? Double(d) : nil
    }

    static func render(_ img: CIImage, skala s: Double) -> CGImage? {
        let i = img.transformed(by: CGAffineTransform(scaleX: s, y: s))
        return ctx.createCGImage(i, from: i.extent.integral)
    }
}

// MARK: - Detektor benur

enum Detektor {
    /// Benur.mlpackage = snap_now.pt (juara hold-out ±4,6%), export format=coreml nms=False imgsz=640. Satu kelas.
    static let mlModel: MLModel? = Bundle.main.url(forResource: "Benur", withExtension: "mlmodelc").flatMap { try? MLModel(contentsOf: $0) }
    static let model: VNCoreMLModel? = mlModel.flatMap { try? VNCoreMLModel(for: $0) }
    static let sisiModel = Double(mlModel?.modelDescription.inputDescriptionsByName.values.compactMap { $0.imageConstraint?.pixelsWide }.first ?? 640)

    static func ubin(_ potong: CGImage, model: VNCoreMLModel, conf: Double) -> [Deteksi] {
        let r = VNCoreMLRequest(model: model)
        r.imageCropAndScaleOption = .scaleFill   // ubin 320 diperbesar ke 640, sama dengan pipeline Python
        try? VNImageRequestHandler(cgImage: potong).perform([r])
        guard let a = (r.results?.first as? VNCoreMLFeatureValueObservation)?.featureValue.multiArrayValue else { return [] }
        let n = a.shape[2].intValue, s1 = a.strides[1].intValue, s2 = a.strides[2].intValue
        if a.dataType == .float32 {
            return a.withUnsafeBufferPointer(ofType: Float.self) { p in dekodeYOLO(n: n, sisi: sisiModel, conf: conf) { Double(p[$0 * s1 + $1 * s2]) } }
        }
        return dekodeYOLO(n: n, sisi: sisiModel, conf: conf) { a[[0, $0, $1] as [NSNumber]].doubleValue }
    }

    /// Ubin bertumpang, kotak dipetakan ke koordinat gambar penuh (ternormalisasi), deteksi ganda di perbatasan digabung.
    /// `iouNMS` dipakai sebagai batas IoS: potongan benur di perbatasan ubin lolos IoU tapi tertangkap IoS.
    static func deteksi(_ img: CGImage, model: VNCoreMLModel, a: AmbangVerifikasi) -> [Deteksi] {
        let sisi = a.deteksi.sisiUbinPX, langkah = max(1, Int(Double(sisi) * (1 - a.deteksi.overlapUbin)))
        func awal(_ n: Int) -> [Int] {
            guard n > sisi else { return [0] }
            var s = Array(stride(from: 0, through: n - sisi, by: langkah))
            if s.last! + sisi < n { s.append(n - sisi) }
            return s
        }
        let W = Double(img.width), H = Double(img.height)
        var semua = [Deteksi]()
        for y in awal(img.height) { for x in awal(img.width) {
            guard let potong = img.cropping(to: CGRect(x: x, y: y, width: sisi, height: sisi)) else { continue }
            let pw = Double(potong.width), ph = Double(potong.height)
            semua += ubin(potong, model: model, conf: a.hasil.minKeyakinanDeteksi).map { d in
                Deteksi(kotak: CGRect(x: (Double(x) + d.kotak.minX * pw) / W, y: (Double(y) + d.kotak.minY * ph) / H,
                                      width: d.kotak.width * pw / W, height: d.kotak.height * ph / H), keyakinan: d.keyakinan)
            }
        }}
        return nms(semua, batas: a.hasil.iouNMS, ukuran: ios)
    }
}

// MARK: - Hitung

struct HasilSesi {
    var hasil: HasilVerifikasi          // antarfoto
    var perFotoCek: [HasilVerifikasi]
    var jumlah: Int?                    // median foto lolos; nil = ditolak
    var perFoto: [Int]
    var panjangPX: Double
    var sisiDeteksiPX: Double           // sisi panjang foto saat deteksi, setelah disesuaikan dengan jarak
    var gambar: CGImage?                // foto untuk ditampilkan
    var kotak: [CGRect]                 // kotak deteksi (hijau) atau area bermasalah (merah), ternormalisasi
}

enum Proses {
    /// K foto → skala supaya benur sama besar dengan di video latih (1920 px di jarak latih) → deteksi berubin → cek per foto dan antarfoto.
    static func hitung(_ t: Tangkapan, profil: WadahProfile, stadia: Stadia, model: VNCoreMLModel, a: AmbangVerifikasi) -> HasilSesi {
        var perFoto = [(hasil: HasilVerifikasi, deteksi: [Deteksi], tanda: [CGRect], gambar: CGImage)]()
        var panjangPX = 0.0, sisi = 0.0
        for f in t.foto {
            let asli = max(f.extent.width, f.extent.height)
            sisi = Rumus.sisiDeteksi(jarakCM: profil.jarakCM, asliPX: asli, a: a)
            guard let g = Visi.render(f, skala: sisi / asli) else { continue }
            panjangPX = Rumus.panjangPX(stadia, jarakCM: profil.jarakCM, fovDerajat: t.fovDerajat, lebarFotoPX: Double(max(g.width, g.height)))
            let d = Detektor.deteksi(g, model: model, a: a)
            let v = validasiFoto(d, ukuran: CGSize(width: g.width, height: g.height), panjangPX: panjangPX, a: a)
            perFoto.append((v.hasil, d, v.tanda, g))
        }
        let jumlah = perFoto.map(\.deteksi.count)
        let (h, n) = validasiAntarFoto(perFoto.map(\.hasil), jumlah: jumlah, a: a)
        // Tampilkan foto lolos yang hitungannya paling dekat median, atau foto gagal pertama dengan area bermasalah
        let pilih = n.flatMap { n in perFoto.indices.filter { perFoto[$0].hasil.lolos }.min { abs(jumlah[$0] - n) < abs(jumlah[$1] - n) } }
            ?? perFoto.firstIndex { !$0.hasil.lolos } ?? 0
        let p = perFoto.indices.contains(pilih) ? perFoto[pilih] : nil
        return HasilSesi(hasil: h, perFotoCek: perFoto.map(\.hasil), jumlah: n, perFoto: jumlah, panjangPX: panjangPX, sisiDeteksiPX: sisi,
                         gambar: p?.gambar, kotak: n != nil ? (p?.deteksi.map(\.kotak) ?? []) : (p?.tanda ?? []))
    }
}

// MARK: - Penyimpanan dan log

/// Satu profil wadah di Documents/profil.json.
final class TokoProfil: ObservableObject {
    @Published private(set) var profil: WadahProfile?
    private let url = URL.documentsDirectory.appending(path: "profil.json")

    init() { profil = try? JSONDecoder().decode(WadahProfile.self, from: Data(contentsOf: url)) }

    func simpan(_ p: WadahProfile) {
        profil = p
        try? JSONEncoder().encode(p).write(to: url, options: .atomic)
    }
}

let modelHP: String = {
    var u = utsname(); uname(&u)
    return withUnsafeBytes(of: u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
}()

let urlLog: URL = {
    let u = URL.documentsDirectory.appending(path: "log.jsonl")
    if !FileManager.default.fileExists(atPath: u.path) { try? Data().write(to: u) }
    return u
}()

/// Satu baris JSON per scan, cek wadah, dan hitungan di Documents/log.jsonl. Foto tidak disimpan.
func catat(_ tahap: String, _ h: HasilVerifikasi? = nil, tambahan: [String: Any] = [:]) {
    var baris: [String: Any] = ["waktu": ISO8601DateFormatter().string(from: Date()), "tahap": tahap,
                                "versi": AmbangVerifikasi.sekarang.versi, "modelHP": modelHP,
                                "modeUji": UserDefaults.standard.bool(forKey: "gerbangPeringatan")]
    if let h { baris.merge(h.log) { $1 } }
    baris.merge(tambahan) { $1 }
    guard JSONSerialization.isValidJSONObject(baris), var data = try? JSONSerialization.data(withJSONObject: baris) else { return }
    data.append(0x0A)
    if let f = try? FileHandle(forWritingTo: urlLog) { f.seekToEndOfFile(); f.write(data); try? f.close() }
}
