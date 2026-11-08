# Riset: Apple Measure vs `Ukur.swift` (iPhone 17, non-LiDAR)

Diriset 2026-11-07. Box uji: styrofoam putih bergerigi, 50 × 44 × 46 cm.

**Label yang dipakai:**
- **[DOK]**: tertulis di sumber resmi Apple (support.apple.com, developer.apple.com, apple.com/newsroom, sesi WWDC).
- **[SEKUNDER]**: dari media/blog pihak ketiga. Kebanyakan membahas iOS 12, jadi perilakunya bisa sudah berubah.
- **[INFERENSI]**: kesimpulan saya sendiri, tidak ada dokumen yang menyatakannya.

Catatan sumber: artikel KB lama Apple "Use the Measure app…" (`support.apple.com/102468`) sekarang otomatis dialihkan ke User Guide. Teks lamanya hanya saya lihat dari cuplikan mesin pencari, tidak saya buka langsung.

---

## 1. Cara pakai Measure: non-LiDAR vs LiDAR

**iPhone 17 (non-Pro) tidak punya LiDAR.** Daftar "Models with a LiDAR Scanner" milik Apple cuma berisi model Pro/Pro Max, dari iPhone 12 Pro sampai 18 Pro. [DOK] https://support.apple.com/guide/iphone/aside/iphc07537a89/27/ios/27

### Langkah yang berlaku di semua model (termasuk iPhone 17)
1. **Mulai / "kalibrasi".** Pindai benda di sekitar pelan-pelan pakai kamera, lalu posisikan benda yang mau diukur di layar. [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios
   - Versi lama KB Apple menulis: tetap gerakkan device sampai muncul *lingkaran dengan titik di tengah*. [DOK lama, dari cuplikan search, tidak dibuka langsung] https://support.apple.com/en-asia/102468
   - MacRumors: alat ini siap dipakai setelah "calibrated, denoted by a white dot in a circle". [SEKUNDER, iOS 12] https://www.macrumors.com/how-to/use-the-augmented-reality-measure-app-ios-12/
   - UI coaching ("gerakkan HP") di Measure adalah desain yang sama dengan `ARCoachingOverlayView`. Kata Apple di WWDC19: "We have it in AR Quick Look and in Measure." [DOK] https://developer.apple.com/videos/play/wwdc2019/604/
2. **Ukur manual.** Arahkan titik di tengah layar ke titik awal, tap +, *geser iPhone pelan-pelan* ke titik akhir, lalu tap + lagi. Tap Clear untuk mulai ulang. [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios
3. **Persegi otomatis.** Kalau iPhone mendeteksi tepi benda persegi, muncul kotak putih (di iOS 12 warnanya kuning). Tap kotaknya untuk melihat dimensi. [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios , https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/12.0/ios/12.0
4. **Level** (waterpass) tersedia, dan hasilnya juga disebut "approximate". [DOK] https://support.apple.com/guide/iphone/use-the-level-iphbd435673d/ios
5. **Snap dan haptic.** Apple tidak mendokumentasikannya, tapi pihak ketiga melaporkan:
   - Ada "little haptic taps" saat titik dipasang dan saat app menemukan "obvious stopping point… such as the end of a wall". [SEKUNDER, iOS 12] https://www.macrumors.com/how-to/use-the-augmented-reality-measure-app-ios-12/
   - Titik "snap" ke sudut, toleransi snap-nya kecil, dan tidak ada snap ke tepi. [SEKUNDER, iOS 12, dari cuplikan search karena halaman 403] https://www.applevis.com/blog/measuring-ios-12-measure-app
   - Titik bisa di-drag untuk dikoreksi (dari komentar pembaca). [SEKUNDER lemah] https://www.macrumors.com/how-to/use-the-augmented-reality-measure-app-ios-12/

### Tambahan khusus model LiDAR (semua ditulis "On supported models" = daftar LiDAR di atas)
- **Edge guides.** Taruh titik di sepanjang tepi lurus sampai muncul garis panduan, lalu ukur mengikuti garis itu. Fitur ini dipakai juga untuk mengukur tinggi furnitur. [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios
- **Ruler view.** Dekatkan iPhone ke garis ukur, nanti garisnya berubah jadi penggaris berskala. [DOK] (sumber sama)
- **Riwayat ukuran.** Daftar semua ukuran dalam satu sesi, lengkap dengan screenshot, dan bisa di-Copy. [DOK] https://support.apple.com/guide/iphone/view-and-save-measurements-iphfe5294b90/ios
- **Tinggi orang.** Dihitung otomatis dari lantai ke ujung kepala. [DOK] https://support.apple.com/guide/iphone/measure-a-persons-height-iph341d4a993/ios
- Menurut Apple, LiDAR membuat Measure "faster" dan guide-nya membantu mengukur "more quickly and accurately". Semua app ARKit juga otomatis mendapat "instant AR placement". [DOK] https://www.apple.com/newsroom/2020/03/apple-unveils-new-ipad-pro-with-lidar-scanner-and-trackpad-support-in-ipados/

**Yang berubah di iPhone 17:** tidak ada edge guides, Ruler view, riwayat, maupun tinggi orang. Fase "gerakkan HP dulu" juga lebih lama, karena ARKit perlu gerakan untuk membangun pemahaman scene (lihat §2). Artinya alur di iPhone 17 = coaching → titik → + → geser → +, ditambah deteksi persegi otomatis.

---

## 2. Teknologi di balik Measure

| Komponen | Status | Isi | Sumber |
|---|---|---|---|
| Berbasis ARKit/AR | [DOK] | "uses AR to quickly gauge the size of real-world objects" | https://www.apple.com/newsroom/2018/06/apple-unveils-arkit-2/ |
| World tracking (VIO) | [DOK umum ARKit] | ARKit menggabungkan sensor gerak dengan fitur visual yang dilacak antar-frame | https://developer.apple.com/documentation/arkit/understanding-world-tracking |
| Coaching overlay | [DOK] | Measure memakai desain coaching yang sama (WWDC19) | https://developer.apple.com/videos/play/wwdc2019/604/ |
| Plane detection horizontal/vertikal | [INFERENSI kuat] | Apple tidak menyebut config Measure secara eksplisit | https://developer.apple.com/documentation/arkit/arplaneanchor |
| Raycast (bukan hit-test) | [INFERENSI] | Apple merekomendasikan raycast sejak iOS 14, dan raycast di LiDAR "automatically benefit" | https://developer.apple.com/videos/play/wwdc2020/10611/ |
| Feature points | [DOK umum] | `estimatedPlane` memotong *feature points* di sekitar ray | https://developer.apple.com/documentation/arkit/arraycastquery/target-swift.enum/estimatedplane |
| Depth + mesh (LiDAR) | [DOK] | Newsroom: depth frameworks + LiDAR untuk Measure. Raycast memakai scene depth/geometry "to instantly place objects… even on featureless surfaces such as white walls" | https://www.apple.com/newsroom/2020/03/apple-unveils-new-ipad-pro-with-lidar-scanner-and-trackpad-support-in-ipados/ , https://developer.apple.com/videos/play/wwdc2020/10611/ |
| Deteksi persegi | [DOK fitur] / [INFERENSI mekanisme] | Fiturnya ada. Mekanismenya tidak dijelaskan; kemungkinan semacam `VNDetectRectanglesRequest` digabung dengan plane | https://developer.apple.com/documentation/vision/vndetectrectanglesrequest |
| Snap ke sudut/titik + haptic | [SEKUNDER] / mekanisme [INFERENSI] | Dilaporkan media. Apple tidak menjelaskan cara kerjanya | lihat §1 |
| Edge guides | [DOK fitur, hanya LiDAR] | Mekanismenya tidak dijelaskan. Kemungkinan dari depth/mesh [INFERENSI] | https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios |

Fakta ARKit yang relevan:
- **Tiga jenis target raycast:**
  - `existingPlaneGeometry`: butuh plane dengan "definitive size and shape".
  - `existingPlaneInfinite`: plane yang sudah terdeteksi "regardless of its size and shape".
  - `estimatedPlane`: "nonplanar surfaces, or planes about which ARKit can only estimate".
  - [DOK] https://developer.apple.com/documentation/arkit/arraycastquery/target-swift.enum
- **`estimatedPlane` di permukaan putih.** Target ini baru bisa mengenai permukaan "with few or no features, such as a white wall" **kalau `sceneReconstruction` mesh aktif**, dan mesh butuh LiDAR. Di iPhone 17 target ini hanya mengandalkan feature points. [DOK] https://developer.apple.com/documentation/arkit/arraycastquery/target-swift.enum/estimatedplane , https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstruction
- **Tracked raycast** mengulang query dan "refined results over time". [DOK] https://developer.apple.com/documentation/arkit/artrackedraycast
- **Anchor.** Menambahkan `ARAnchor` "helps ARKit to optimize world-tracking accuracy in the area around that anchor". [DOK] https://developer.apple.com/documentation/arkit/aranchor

---

## 3. Akurasi dan batasan yang terdokumentasi

- Apple **tidak memberi angka akurasi**. Yang ditulis cuma "Measurements are approximate", dengan saran "well-defined objects located 0.5 to 3 meters" dari iPhone. [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios
- **Pencahayaan dan tekstur.** Tracking memburuk "when the camera is pointed at a blank wall or the scene is too dark". [DOK] https://developer.apple.com/documentation/arkit/understanding-world-tracking
  - Status `insufficientFeatures` artinya scene "doesn't contain enough distinguishable features". [DOK] https://developer.apple.com/documentation/arkit/arcamera/trackingstate-swift.enum/reason/insufficientfeatures
  - **Styrofoam putih = kasus terburuk.** Gerigi pada styrofoam mungkin sedikit membantu karena memberi bayangan. [INFERENSI]
- **Gerakan.** ARKit butuh device bergerak, tapi gerakan "too far, too fast, or shaking too vigorously" menurunkan kualitas tracking. [DOK] (sumber sama)
- **Plane berubah seiring waktu.** Saat pertama terdeteksi, posisi dan luas plane "may be inaccurate", lalu diperbaiki bertahap. [DOK] (sumber sama)
  - HIG: "Avoid trying to precisely align objects with the edges of detected surfaces… boundaries are approximations." **Ini penting karena sudut box = tepi plane.** [DOK] https://developer.apple.com/design/human-interface-guidelines/augmented-reality
- **Penyebab gagal deteksi menurut HIG:** "insufficient light, an overly reflective surface, a surface without enough detail, or too much camera motion". [DOK] (sumber sama)
- **LiDAR juga punya batas.** Permukaan yang sangat reflektif atau sangat menyerap cahaya menurunkan confidence depth. [DOK] https://developer.apple.com/videos/play/wwdc2020/10611/
- **Akurasi tergantung titik.** "The accuracy… depends heavily on the precision of where the end points are placed". [SEKUNDER] https://www.macrumors.com/how-to/use-the-augmented-reality-measure-app-ios-12/

---

## 4. Gap list: `Ukur.swift` vs Measure (TIDAK ada kode yang diubah)

Yang dilakukan `Ukur.swift` sekarang:
- Setiap frame, raycast dari tengah layar ke `.existingPlaneGeometry`, lalu fallback ke `.estimatedPlane`, keduanya dengan alignment `.any` (baris 119–123).
- Titik = hasil raycast **satu frame** saat + ditekan (baris 70–71). Titik disimpan sebagai `SIMD3` mentah, bukan anchor.
- Garis digambar 2D di SwiftUI lewat `projectPoint` (baris 126–130).
- Tidak ada snap, coaching overlay, maupun gating tracking state.

Diurutkan dari dampak terbesar. **A** = akurasi, **F** = feel. Semua solusi di bawah adalah [INFERENSI] desain, tapi API-nya [DOK].

| # | Gap | Dampak | Kenapa | API penutup |
|---|---|---|---|---|
| 1 | **Tinggi diukur diagonal lantai→sudut atas, bebas 3D** | A tinggi | Titik bawah di sambungan lantai-box sering kena sisi box atau lantai. Titik atas ada di tepi plane, yang menurut HIG posisinya perkiraan. Selisih horizontal kecil pun ikut masuk ke hasil. | Hitung tinggi = `y` plane atas box − `y` plane lantai (`ARPlaneAnchor.transform`). Alternatif: kunci ujung kedua ke garis vertikal lewat titik awal dengan `ARRaycastQuery(origin:direction:allowing:alignment:)` + `existingPlaneInfinite` `.vertical`. https://developer.apple.com/documentation/arkit/arraycastquery |
| 2 | **Panjang/lebar tidak dikunci ke satu plane** | A tinggi | Di sudut, reticle keluar dari batas `existingPlaneGeometry` lalu jatuh ke `estimatedPlane`. Hasilnya bisa kena lantai, jadi titik "loncat" puluhan cm ke bawah. | Setelah titik awal ada di plane atas, raycast ujung kedua ke `.existingPlaneInfinite` + `.horizontal` (plane yang sama, `result.anchor`). https://developer.apple.com/documentation/arkit/arraycastquery/target-swift.enum |
| 3 | **Titik = 1 frame mentah, reticle tidak dihaluskan** | A + F | Jitter per frame langsung masuk ke hasil. Sample Apple menyimpan `recentFocusSquarePositions` untuk focus square-nya [DOK], dan memakai tracked raycast untuk memperbaiki posisi seiring waktu [DOK]. | `ARSession.trackedRaycast(_:updateHandler:)`/`ARTrackedRaycast`, atau median N hasil terakhir saat tap. https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction |
| 4 | **Titik tidak di-anchor** | A sedang | Koreksi world tracking tidak ikut menggeser titik. Padahal anchor membantu ARKit mengoptimalkan akurasi di sekitarnya [DOK]. | `session.add(anchor: ARAnchor(transform:))`, lalu baca `anchor.transform` terbaru di `didUpdate`. https://developer.apple.com/documentation/arkit/aranchor |
| 5 | **+ tetap aktif saat tracking `limited`** | A sedang | Titik bisa dipasang saat `excessiveMotion`/`insufficientFeatures`. | Tombol + hanya aktif saat `frame.camera.trackingState == .normal`. https://developer.apple.com/documentation/arkit/arcamera/trackingstate-swift.enum |
| 6 | **Tidak ada coaching overlay** (cuma teks) | F tinggi, A sedang | Measure memakai UI coaching ini [DOK WWDC19]. Overlay juga muncul ulang otomatis saat tracking turun. | `ARCoachingOverlayView` (`session`, `goal = .horizontalPlane`, `activatesAutomatically = true`). https://developer.apple.com/documentation/arkit/arcoachingoverlayview |
| 7 | **Tidak ada snap ke titik/garis yang sudah ada + haptic snap** | F tinggi, A sedang | Panjang dan lebar berbagi satu sudut. Snap ke titik lama menghilangkan error sudut ganda. Measure dilaporkan snap + haptic [SEKUNDER]. HIG menyarankan haptic untuk konfirmasi kontak [DOK]. | Jarak layar antara reticle dan `projectPoint(titik lama)` < ambang → pakai titik lama + `UIImpactFeedbackGenerator`/`UISelectionFeedbackGenerator`. https://developer.apple.com/design/human-interface-guidelines/augmented-reality |
| 8 | **Reticle 2D datar, tidak menempel di permukaan** | F | Focus square di sample Apple mengikuti orientasi permukaan (`worldTransform.orientation`) [DOK]. | `SCNNode` di `ARSCNView` (sudah dipakai di `PratinjauAR`) dengan `simdWorldTransform` = hasil raycast. https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction |
| 9 | **Garis/titik digambar 2D via projeksi** | F | Tidak ada perspektif dan oklusi. Titik di belakang kamera bisa terproyeksi aneh [INFERENSI]. | `SCNNode` garis (SCNGeometry/silinder) di `ARSCNView.scene`. https://developer.apple.com/documentation/arkit/arscnview |
| 10 | **Tidak bisa drag titik untuk koreksi** (cuma undo) | F | Ada di Measure menurut laporan pengguna [SEKUNDER lemah]. | Gesture + raycast dari titik sentuh: `ARSCNView.raycastQuery(from:allowing:alignment:)`. https://developer.apple.com/documentation/arkit/arscnview/raycastquery(from:allowing:alignment:) |
| 11 | **Snap ke sudut/tepi box** | F/A, effort besar | Measure non-LiDAR dilaporkan snap ke sudut [SEKUNDER]. Tapi HIG bilang tepi plane cuma perkiraan, jadi jangan mengandalkan batas plane. | `VNDetectRectanglesRequest` pada `frame.capturedImage` untuk sisi atas box, lalu raycast sudutnya ke plane atas. https://developer.apple.com/documentation/vision/vndetectrectanglesrequest |
| 12 | Tidak ada mode debug feature points | Diagnosis | Belum ada cara melihat apakah styrofoam punya cukup fitur. | `ARSCNView.debugOptions = [.showFeaturePoints]` / `frame.rawFeaturePoints`. https://developer.apple.com/documentation/arkit/arframe/rawfeaturepoints |
| 13 | Jalur LiDAR cuma `sceneDepth`, tanpa mesh | Tidak relevan di iPhone 17 | `estimatedPlane` baru mengenai permukaan putih kalau `sceneReconstruction` mesh aktif [DOK]. | `config.sceneReconstruction = .mesh` di device yang mendukung. https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstruction |

Catatan kecil [INFERENSI]: `ARFrame.raycastQuery(from:)` menerima titik "normalized coordinate in the UI system" (https://developer.apple.com/documentation/arkit/arframe/raycastquery(from:allowing:alignment:)). Kode kita mengonversi titik tengah lewat `displayTransform().inverted()`. Untuk (0.5, 0.5) hasilnya tetap di tengah, jadi tidak salah, tapi perlu dicek ulang kalau nanti ada raycast dari titik selain tengah (misalnya fitur drag di #10).

---

## 5. Tips mengukur box styrofoam 50×44×46 di iPhone 17

1. **Cahaya terang dan merata.** Hindari ruangan gelap dan cahaya yang memantul keras. [DOK] https://developer.apple.com/documentation/arkit/understanding-world-tracking , https://developer.apple.com/design/human-interface-guidelines/augmented-reality
2. **Tambahkan tekstur.**
   - Tempel lakban kertas atau masking tape dengan tanda "X" spidol hitam di **setiap sudut atas** dan di lantai dekat sudut bawah. Dasarnya: tracking dan `estimatedPlane` butuh feature points, dan permukaan polos itu kasus terburuk [DOK, sumber §3]. Bahwa tanda X membantu adalah [INFERENSI].
   - Tanda juga sekaligus jadi target bidik yang presisi. Tebal lakban bisa diabaikan.
3. **Letakkan box di lantai yang bertekstur** (keramik bermotif, karpet, koran), bukan lantai putih polos. Tujuannya supaya plane lantai cepat terdeteksi. [INFERENSI dari DOK §3]
4. **Jarak.** Apple menyarankan 0,5–3 m [DOK] https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios. Untuk membidik sudut, sekitar 0,5–1 m lebih enak karena sudutnya terlihat besar di layar. [INFERENSI]
5. **Kalibrasi dulu.**
   - Gerakkan HP kiri-kanan pelan beberapa detik sampai lantai dan tutup box terdeteksi. [DOK] https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction
   - Tunggu sebentar setelah plane muncul, karena estimasinya masih membaik. [DOK] https://developer.apple.com/documentation/arkit/understanding-world-tracking
6. **Geser pelan, jangan goyang** saat memindah reticle dari titik awal ke titik akhir. [DOK] "Slowly pan iPhone" https://support.apple.com/guide/iphone/measure-dimensions-iphd8ac2cfea/ios
7. **Panjang dan lebar: ukur di tutup atas box**, dari sudut ke sudut, dengan HP agak di atas box (melihat ke bawah ±45°). Tutup atas adalah plane horizontal yang paling mungkin terdeteksi. [INFERENSI]
8. **Tinggi.** Paling aman pakai selisih plane atas dan lantai (gap #1). Selama belum diimplementasi:
   - Taruh box menempel dinding yang bertekstur, lalu ukur di sepanjang dinding (plane vertikal), **atau**
   - Bidik dari tanda X di lantai tepat di bawah sudut atas, sambil menjaga HP setinggi kira-kira tengah box supaya garisnya tidak miring.
   - [INFERENSI]
9. **Ulangi 3×, ambil median** per dimensi. Ini mengurangi efek satu titik yang meleset karena jitter. [INFERENSI statistik dasar]
10. **Kontrol dengan Apple Measure** di HP yang sama, kondisi yang sama, box yang sama, ditambah meteran asli sebagai *ground truth*.
    - Kalau Measure juga meleset jauh, masalahnya di kondisi (cahaya/tekstur), bukan di kode kita.
    - Kalau Measure jauh lebih baik, prioritaskan gap #1–#3.
    - [INFERENSI metode]
11. **Lihat panel info.** Jangan tekan + saat tracking "terbatas"; tunggu sampai "normal". [DOK tentang arti status] https://developer.apple.com/documentation/arkit/arcamera/trackingstate-swift.enum/reason/insufficientfeatures

---

### Ringkasan satu paragraf
Di iPhone non-LiDAR, Measure pada dasarnya juga hanya ARKit world tracking + plane + raycast, dengan coaching, snap, dan haptic di atasnya. Fitur "ajaib"-nya (edge guides, ruler, riwayat, tinggi orang, penempatan instan di permukaan putih) **khusus LiDAR**. Jadi tidak ada teknologi rahasia yang kita lewatkan di iPhone 17. Selisih akurasi kemungkinan besar datang dari **(1) tinggi yang diukur bebas-3D, (2) ujung garis yang tidak dikunci ke plane yang sama, dan (3) titik satu-frame tanpa smoothing**. Selisih "feel" datang dari coaching overlay, snap + haptic, dan reticle/garis yang tidak hidup di ruang 3D. [INFERENSI, disusun dari sumber di atas]
