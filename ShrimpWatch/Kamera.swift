import AVFoundation
import CoreImage
import CoreMotion
import UIKit
import Vision

/// Kanal Y frame YUV, diperkecil (tetangga terdekat) sampai sisi terpanjang `panjang`.
extension Luma {
    init(pixelBuffer pb: CVPixelBuffer, panjang: Int) {
        CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let W = CVPixelBufferGetWidthOfPlane(pb, 0), H = CVPixelBufferGetHeightOfPlane(pb, 0)
        let bpr = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        let base = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!.assumingMemoryBound(to: UInt8.self)
        let s = min(1, Double(panjang) / Double(max(W, H))), w = Int(Double(W) * s), h = Int(Double(H) * s)
        var px = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { let sy = y * H / h; for x in 0..<w { px[y * w + x] = base[sy * bpr + x * W / w] } }
        self.init(w: w, h: h, px: px)
    }
}

/// Foto resolusi penuh (sudah tegak) + FOV sisi panjang sensor (untuk panjang benur dalam piksel).
struct Tangkapan {
    var foto: [CIImage]
    var fovDerajat: Double
}

enum ModeKamera {
    case acuan(pegang: Bool, setelan: SetelanKamera?)   // setelan nil = kunci baru (acuan 1); ada = pakai ulang (acuan 2)
    case cocok(WadahProfile)
    case hitung(WadahProfile)
}

/// Kamera + gerbang per frame + foto. Semua state analisis hidup di `antrian`.
final class Kamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published private(set) var hasil = HasilVerifikasi()
    @Published private(set) var progres = 0.0
    @Published private(set) var status: String? = "Menyiapkan kamera…"   // non-nil = belum siap atau galat
    @Published private(set) var memotret = false
    @Published private(set) var gagalLama = false                       // cek wadah gagal > 5 detik

    let session = AVCaptureSession()
    let mode: ModeKamera
    var onAcuan: ((AcuanFrame) -> Void)?
    var onCocok: ((HasilVerifikasi) -> Void)?
    var onFoto: ((Tangkapan) -> Void)?

    private let a = AmbangVerifikasi.sekarang
    private let uji = UserDefaults.standard.bool(forKey: "gerbangPeringatan")
    private let video = AVCaptureVideoDataOutput()
    private let fotoOutput = AVCapturePhotoOutput()
    private let antrian = DispatchQueue(label: "kamera")
    private let gerak = CMMotionManager()
    private var device: AVCaptureDevice?
    private var siap = false, selesai = false, aktif = true
    private var nFrame = 0, berturut = 0, gagalSejak: Date?
    private var gravitasi: [CMAcceleration] = []
    private var setelan: SetelanKamera?
    private var fpAcuan: VNFeaturePrintObservation?, jarakFP: Double?
    private var foto: [CIImage] = [], percobaan = 0

    init(mode: ModeKamera) {
        self.mode = mode
        if case .cocok(let p) = mode {
            fpAcuan = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: p.acuan.featurePrint)
        }
    }

    func mulai() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            if ok { self.antrian.async { self.siapkan() } } else { self.lapor("Izin kamera ditolak. Buka Pengaturan untuk mengizinkan.") }
        }
    }

    func berhenti() {
        gerak.stopDeviceMotionUpdates()
        antrian.async { self.aktif = false; self.atur { $0.torchMode = .off }; self.session.stopRunning() }
    }

    private func lapor(_ s: String?) { DispatchQueue.main.async { self.status = s } }

    private func siapkan() {
        guard let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), d.hasTorch,
              let input = try? AVCaptureDeviceInput(device: d), session.canAddInput(input) else {
            return lapor("Kamera belakang dengan senter tidak tersedia (Simulator tidak punya kamera).")
        }
        device = d
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: antrian)
        if session.canAddOutput(video) { session.addOutput(video) }
        if session.canAddOutput(fotoOutput) { session.addOutput(fotoOutput) }
        if let m = d.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width < $1.width }) { fotoOutput.maxPhotoDimensions = m }
        for o in [video as AVCaptureOutput, fotoOutput] {   // potret
            if let c = o.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        }
        session.commitConfiguration()
        session.startRunning()
        gerak.deviceMotionUpdateInterval = 1 / 30
        gerak.startDeviceMotionUpdates()
        switch mode {
        case .acuan(_, let s?): pakaiUlang(s)
        case .acuan(_, nil): kunciBaru()
        case .cocok(let p), .hitung(let p): pakaiUlang(p.acuan.setelan)
        }
    }

    private func atur(_ f: (AVCaptureDevice) -> Void) {
        guard let d = device, (try? d.lockForConfiguration()) != nil else { return }
        f(d); d.unlockForConfiguration()
    }

    private func senter(_ level: Float) {
        atur { d in try? d.setTorchModeOn(level: min(level, AVCaptureDevice.maxAvailableTorchLevel)) }
    }

    /// Senter di level tetap, tunggu ±1 detik, lalu kunci eksposur, white balance, dan fokus.
    private func kunciBaru() {
        lapor("Menyalakan senter dan mengunci setelan kamera…")
        atur { d in
            let maks = CMTime(seconds: a.kamera.maksDurasiEksposurDetik, preferredTimescale: 1_000_000)
            d.exposureMode = .continuousAutoExposure
            d.activeMaxExposureDuration = min(maks, d.activeFormat.maxExposureDuration)   // eksposur otomatis tidak lebih lama dari 1/60 s
            d.whiteBalanceMode = .continuousAutoWhiteBalance
            if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus }
        }
        senter(a.kamera.levelSenter)
        antrian.asyncAfter(deadline: .now() + 1.2) { [self] in
            atur { d in
                d.exposureMode = .locked
                d.whiteBalanceMode = .locked
                if d.isFocusModeSupported(.locked) { d.focusMode = .locked }
            }
            antrian.asyncAfter(deadline: .now() + 0.3) { [self] in
                guard let d = device else { return }
                let g = d.deviceWhiteBalanceGains
                setelan = SetelanKamera(iso: d.iso, durasiEksposurDetik: d.exposureDuration.seconds, posisiLensa: d.lensPosition,
                                        gainMerah: g.redGain, gainHijau: g.greenGain, gainBiru: g.blueGain, levelSenter: a.kamera.levelSenter)
                siap = true; lapor(nil)
            }
        }
    }

    /// ISO, durasi eksposur, white balance, posisi fokus, dan level senter dari profil.
    private func pakaiUlang(_ s: SetelanKamera) {
        lapor("Memasang setelan kamera dari profil…")
        atur { d in
            let f = d.activeFormat
            d.setExposureModeCustom(duration: CMTime(seconds: min(max(s.durasiEksposurDetik, f.minExposureDuration.seconds), f.maxExposureDuration.seconds),
                                                     preferredTimescale: 1_000_000),
                                    iso: min(max(s.iso, f.minISO), f.maxISO), completionHandler: nil)
            let m = d.maxWhiteBalanceGain
            d.setWhiteBalanceModeLocked(with: .init(redGain: min(max(s.gainMerah, 1), m), greenGain: min(max(s.gainHijau, 1), m),
                                                    blueGain: min(max(s.gainBiru, 1), m)), completionHandler: nil)
            if d.isFocusModeSupported(.locked) { d.setFocusModeLocked(lensPosition: s.posisiLensa, completionHandler: nil) }
        }
        senter(s.levelSenter)
        setelan = s
        antrian.asyncAfter(deadline: .now() + 1.2) { [self] in siap = true; lapor(nil) }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        defer { nFrame += 1 }
        if let g = gerak.deviceMotion?.gravity { gravitasi = (gravitasi + [g]).suffix(15) }   // ±0,5 detik
        guard aktif, siap, !selesai else { return }

        let l = Luma(pixelBuffer: pb, panjang: a.kamera.sisiAnalisisPX)
        var u = UkuranFrame()
        u.ketajaman = l.ketajaman()
        u.kecerahan = l.rata()
        u.peta = Rumus.normal(l.sel(n: 4))
        u.thumb = Luma(pixelBuffer: pb, panjang: 64).px
        u.iso = Double(setelan?.iso ?? 0)
        let n = Double(max(gravitasi.count, 1))
        let gx = gravitasi.map(\.x).reduce(0, +) / n, gy = gravitasi.map(\.y).reduce(0, +) / n, gz = gravitasi.map(\.z).reduce(0, +) / n
        u.kemiringan = acos(min(1, abs(gz) / max((gx * gx + gy * gy + gz * gz).squareRoot(), 1e-9))) * 180 / .pi

        let h: HasilVerifikasi
        switch mode {
        case .acuan(let pegang, _): h = gerbangAcuan(u, pegang: pegang, a: a)
        case .cocok(let p):
            if nFrame % 15 == 0, let acuan = fpAcuan, let f = Visi.sidik(pb) {   // ±2× per detik
                var d: Float = 0
                if (try? f.computeDistance(&d, to: acuan)) != nil { jarakFP = Double(d) }
            }
            u.jarakFP = jarakFP
            h = gerbangCocok(u, profil: p, a: a)
            gagalSejak = h.lolos ? nil : (gagalSejak ?? Date())
        case .hitung(let p): h = gerbangHitung(u, profil: p, a: a)
        }

        // Satu cek gagal mengembalikan penghitung ke nol. Mode uji: gagal hanya peringatan, penghitung tetap jalan.
        berturut = h.lolos || uji ? berturut + 1 : 0
        let p = Double(berturut) / Double(a.kamera.frameStabil), lama = gagalSejak.map { Date().timeIntervalSince($0) > 5 } ?? false
        DispatchQueue.main.async { self.hasil = h; self.progres = p; self.gagalLama = lama }
        guard berturut >= a.kamera.frameStabil else { return }

        selesai = true
        switch mode {
        case .acuan:
            guard let s = setelan else { selesai = false; return }
            let fp = Visi.sidik(pb).flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) } ?? Data()
            let acuan = AcuanFrame(thumb: u.thumb, peta: u.peta, kecerahan: u.kecerahan, featurePrint: fp, setelan: s)
            catat("acuan", h)
            DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); self.onAcuan?(acuan) }
        case .cocok:
            catat("cekWadah", h)
            DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); self.onCocok?(h) }
        case .hitung:
            potret()
        }
    }

    // MARK: Foto resolusi penuh

    private func potret() {
        foto = []; percobaan = 0
        DispatchQueue.main.async { self.memotret = true; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        ambil()
    }

    private func ambil() {
        let s = AVCapturePhotoSettings()
        s.flashMode = .off
        s.photoQualityPrioritization = .speed   // tanpa fusi multi-frame, supaya setelan terkunci benar-benar dipakai
        s.maxPhotoDimensions = fotoOutput.maxPhotoDimensions
        percobaan += 1
        fotoOutput.capturePhoto(with: s, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let ci = photo.fileDataRepresentation().flatMap { CIImage(data: $0, options: [.applyOrientationProperty: true]) }
        antrian.async { [self] in
            if let ci { foto.append(ci) }
            if foto.count < a.hasil.jumlahFoto, percobaan < a.hasil.jumlahFoto * 2 { return ambil() }
            guard !foto.isEmpty else { return lapor("Gagal mengambil foto. Kembali lalu coba lagi.") }
            let t = Tangkapan(foto: foto, fovDerajat: Double(device?.activeFormat.videoFieldOfView ?? 67))
            DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); self.onFoto?(t) }
        }
    }
}
