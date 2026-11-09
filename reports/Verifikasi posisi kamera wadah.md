# Cek wadah menjaga cahaya, bukan posisi

Jawaban singkatnya: **cek wadah saat ini hanya kuat menjaga satu dari lima kondisi ideal, yaitu cahaya yang mirip.** NCC dipasang untuk memastikan HP kembali ke posisi dan tinggi yang sama di atas box yang sama. Di rig kamu NCC tidak bisa bekerja, karena dasar box putih hampir tanpa kontras. Simpangan baku thumbnail acuan hanya **5,4 tingkat abu-abu**, di bawah sekitar **8 tingkat** yang disebut literatur sebagai syarat agar korelasi bekerja. Akibatnya, dua foto dari HP yang sama sekali tidak bergerak hanya cocok **0,22**. Karena itu, sejak 8 Nov 15:40 UTC kode melewati NCC secara otomatis kalau baseline registrasi di bawah 0,6, dan **keempat registrasi sejak 13:49 UTC semuanya di bawah 0,6**. Feature print hanya mengenali "jenis pemandangan", bukan box yang mana atau tinggi berapa. Saat hitung, tinggi HP hanya dijaga cek ukuran benur ±35%, yang masih meloloskan HP di **33–69 cm**. Sensor diam tidak dicek saat cek wadah. Sensor itu dicek saat foto acuan dan foto hitung, dan dua saat itulah yang penting. Untuk adegan tanpa tekstur, metode yang terbukti adalah **menambah struktur yang ukurannya diketahui** (label atau penanda), atau **memaku geometrinya secara fisik** dengan rig. Penjelasan sebelumnya berubah-ubah karena kode diubah sebagai reaksi atas log, dan dua klaim penting diucapkan tanpa pernah diukur. Belum ada kode yang diubah. Bagian rekomendasi berisi pilihan untuk kamu putuskan.

> **Cara baca label bukti.** *(diukur)* = angka dari iPhone 17 kamu, diambil dari `log.jsonl` atau profil tersimpan. *(kode)* = dibaca langsung dari `Inti.swift`, `Kamera.swift`, `App.swift`, atau `ambang.json`. *(hitungan)* = aritmetika dari angka kode dan log, belum diuji di HP. *(literatur)* = dari sumber bertautan. Waktu log memakai UTC. WIB = UTC + 7.

## Cek per cek: hanya cahaya yang benar-benar terjaga

Beberapa istilah dulu. **NCC** adalah skor kemiripan pola terang-gelap dua gambar kecil (thumbnail 48 × 64 piksel), dari −1 sampai 1. **Baseline** adalah skor NCC dan feature print antara foto acuan 1 dan foto acuan 2 saat registrasi. Ambang cek wadah diturunkan dari baseline ini. **Feature print** adalah "sidik" gambar dari jaringan saraf Apple. Jaraknya kecil kalau dua gambar mirip isinya. **Peta cahaya** membagi gambar jadi 4 × 4 kotak dan membandingkan terang tiap kotak terhadap rata-rata gambar. **Pita tepi** adalah jalur 3% di pinggir foto: kalau ada benur di situ, berarti dasar box mungkin terpotong.

| Cek | Kapan jalan | Ambang sekarang | Mau menjaga | Kenyataan di rig ini | Saran |
|---|---|---|---|---|---|
| **NCC** | Cek wadah | Dilewati (−1) kalau baseline < 0,6. Kalau tidak, min(0,80, baseline − 0,05) *(kode)* | Posisi dan tinggi HP sama, box sama | **Mati.** Baseline 4 registrasi terakhir 0,19–0,52, jadi selalu dilewati *(diukur)*. Kemampuannya mendeteksi tinggi atau box lain **tidak pernah diukur** | Jadikan log saja |
| **Feature print** | Cek wadah, ±2× per detik | ≤ maks(3 × baseline, 0,15) *(kode)* | Box sama | **Lemah.** Batas di profil terbaru 0,65–0,87. Box yang sama sudah memberi 0,06–0,33. Box lain belum pernah diuji *(diukur)* | Pertahankan sebagai cek kasar "kamera melihat hal lain". Jangan dipakai untuk identitas box |
| **Peta cahaya** | Cek wadah | Deviasi kotak terburuk ≤ 0,25 *(kode)* | Pola cahaya sama (tutup, lampu kamar) | **Bekerja, mungkin terlalu ketat.** Menggagalkan sesi 22:57 WIB dengan 0,268 dan 0,282 *(diukur)* | Setel ulang dari uji di HP. Simpan fotonya saat gagal |
| **Kecerahan** | Cek wadah dan hitung | ±25% dari acuan *(kode)* | Cahaya keseluruhan mirip | Bekerja. Selisih terukur 0,5–5% *(diukur)* | Pertahankan |
| **Sensor diam** (giroskop dan akselerometer) | Foto acuan dan foto hitung. **Tidak di cek wadah** *(kode)* | ≤ 5 °/s dan ≤ 0,03 g selama ±0,5 s | HP diam, tidak blur | **Kuat.** HP yang ditaruh membaca ±0,16 °/s *(diukur)* | Pertahankan. Tidak perlu ditambah ke cek wadah |
| **Ukuran benur** | Tiap foto hitung | Median panjang kotak deteksi ±35% dari 17 px (PL-10) *(kode, diukur)* | Tinggi HP saat hitung | **Longgar.** ±35% setara HP di 33,3–69,2 cm *(hitungan)*. Belum pernah jalan dengan benur sungguhan *(diukur: 3 hitungan v5, semuanya 0 deteksi)* | Setel ulang setelah mengukur PL-10 asli. Tetap peringatan |
| **Pita tepi** | Tiap foto hitung | 0 benur di 3% tepi *(kode)* | Seluruh dasar masuk frame | **Sebagian.** Hanya bereaksi kalau benur kebetulan ada di tepi. Menangkap HP digeser (sekitar 1,2 cm di sumbu pendek) atau diturunkan ke sekitar 42,5 cm, **tidak pernah** menangkap HP dinaikkan *(hitungan)* | Pertahankan |

Dua hal lagi **tidak dicek sama sekali**. Pertama, kemiringan HP di mode taruh setelah langkah kartu (cek ≤ 10° hanya ada di mode pegang). Kedua, volume air. Selain itu, 9 dari 10 profil memakai sudut dasar bawaan 48 × 35 cm yang tidak digeser user *(diukur)*. Jadi cek "sudut dasar di luar pita tepi" saat registrasi menilai persegi asumsi, bukan dasar yang sebenarnya.

| Kondisi ideal | Dijaga oleh | Status |
|---|---|---|
| Box sama | Feature print (NCC mati) | **Lemah.** Box putih lain yang serupa hampir pasti lolos |
| Tinggi HP sama | Kartu saat registrasi (±0,5 cm, tervalidasi). Saat hitung: ukuran benur ±35% | **Kuat sekali saja, lalu longgar** (33–69 cm) |
| Seluruh dasar dalam frame | Pita tepi, hanya kalau ada benur di tepi | **Sebagian** |
| Cahaya mirip | Peta cahaya dan kecerahan | **Kuat**, bahkan mungkin terlalu ketat |
| HP diam | Sensor gerak saat acuan dan hitung | **Kuat** |

## Kenapa NCC ada, dan kenapa sekarang dilewati

NCC lahir dari desain v1 (7 Nov). Ide awalnya: ambil foto acuan, angkat HP, taruh lagi, lalu ambil foto acuan kedua. Skor antara dua foto itu (baseline) menunjukkan seberapa mirip gambar ketika HP "dikembalikan dengan benar". Setiap sesi, gambar live dibandingkan dengan acuan. Kalau skornya jauh di bawah baseline, berarti HP ada di posisi atau tinggi lain, atau box-nya lain. Layar registrasi memang meminta user "Angkat HP lalu taruh atau pegang lagi di posisi yang sama" *(kode)*.

Dalam praktik, desain itu tidak pernah benar-benar teruji. **Pada 7 dari 10 registrasi, jarak antara foto acuan 1 dan 2 hanya 3–5 detik** *(diukur)*. Itu terlalu singkat untuk mengangkat dan menaruh HP, jadi baseline lebih banyak mengukur getaran gambar antar-frame daripada keakuratan menaruh ulang HP. Registrasi 22:38 WIB menjadi bukti paling jelas. HP diam total (0,166 dan 0,160 °/s), kamu mengonfirmasi HP tidak dipindah, dan baseline-nya tetap **0,2155** *(diukur)*.

NCC sekarang dilewati karena aturan yang ditambahkan 8 Nov pukul 15:40 UTC: kalau baseline < 0,6 (`minBaselineNCC`), ambang NCC menjadi −1, sehingga selalu lolos dan panel menulis "dilewati (dasar polos)" *(kode)*. Keputusan ini diambil sekali saat registrasi. Semua registrasi sejak 13:49 UTC punya baseline 0,19–0,52, jadi **di setup kamu sekarang NCC selalu dilewati** *(diukur)*. Alasan yang tertulis di komentar kode, "frame hanya berisi dasar polos (tidak ada tepi/dinding)", **tidak akurat**. Bagian berikut menjelaskan sebabnya.

## Dasar putih terlalu polos untuk dicocokkan

Foto bukti registrasi 22:57 WIB menunjukkan lembaran kertas putih di dasar, dengan tepi kertas terlihat, dan jalur sempit bibir serta dinding styrofoam di keempat tepi frame. Jadi tepi itu ada, hanya **kontrasnya sangat rendah**. Thumbnail acuan bernilai 91–156 dengan simpangan baku **5,36 tingkat abu-abu** dari skala 0–255 *(diukur)*. Simpangan baku di sini artinya seberapa jauh terang tiap piksel menyimpang dari rata-rata. Angka 5 berarti gambarnya nyaris rata.

Literatur fotogrametri sudah lama menyatakan bahwa korelasi "inherently needs" variasi abu-abu (tekstur). Satu studi mendapati korelasi baru mencapai tingkat maksimumnya pada simpangan baku lokal sekitar **8 tingkat abu-abu**, dan ambang terima/tolaknya dipilih dari data, bukan ditetapkan di awal ([IAPRS 1995, hlm. 133](https://goobi.tib.eu/viewer/!fulltext/1067806741/133)). Uji "bisa dilacak" standar (Shi–Tomasi) juga mensyaratkan gradien yang kuat ke dua arah ([Shi & Tomasi 1994](https://users.cs.duke.edu/~tomasi/papers/shi/shiCvpr94.pdf)). Angka 8 itu berasal dari satu dataset, bukan konstanta universal. Tapi rig kamu ada di bawahnya.

Apa artinya bagi skor? Misalkan tiap frame terdiri dari bagian tetap (dasar, kertas, bibir) ditambah bagian yang berubah tiap saat (noise sensor, kilau senter di air, riak). NCC yang diharapkan untuk posisi yang sama = varians bagian tetap ÷ varians total. Skor 0,22 dengan HP diam berarti sekitar **78% variasi thumbnail berubah dalam 4 detik** *(hitungan)*. Foto acuan sebagian besar memotret kilau dan riak air, bukan box. Selain itu, pencarian geser ±3 piksel di `nccPosisi` memberi "skor gratis" sekitar +0,07 rata-rata, dan sampai +0,12, pada dua gambar noise murni *(hitungan, simulasi)*. Thumbnail juga diambil per piksel tunggal tanpa rata-rata *(kode)*, sehingga noise sensor ikut masuk penuh. Ide merata-ratakan per blok pernah dicoba di Mac dan menaikkan skor, tapi belum pernah dijalankan di HP. Rata-rata blok juga hanya mengurangi noise sensor. Kilau air tetap ada, dan pencarian geser tetap tidak bisa membaca perubahan skala. Jadi rata-rata blok tidak membuktikan bahwa NCC bisa mendeteksi tinggi.

Feature print punya masalah yang berbeda. Apple membuatnya dari lapisan atas jaringan klasifikasi, yang sengaja membuang detail "tidak perlu" dan mengukur kemiripan "in a semantic sense". Di demo Apple, dua foto kucing yang tampak berbeda justru lebih dekat daripada dua hewan berbeda yang tampak mirip ([WWDC19 sesi 222](https://developer.apple.com/videos/play/wwdc2019/222/)). Dua box styrofoam putih berisi air adalah "pemandangan yang sama" baginya. Apple tidak menerbitkan ambang jarak, dan jarak dari revisi model yang berbeda tidak bisa dibandingkan ([Apple Developer Forums 732876](https://developer.apple.com/forums/thread/732876)). Data kamu cocok dengan gambaran ini. Baseline feature print saat HP diam (0,26) hampir sama dengan saat HP dipindah atau dipegang (0,22–0,29) *(diukur)*, jadi feature print bahkan tidak membedakan "dipindah" dari "tidak dipindah".

## Metode yang terbukti: tambah struktur atau kunci geometri

Pola dari literatur konsisten: kalau adegannya tidak bertekstur, **jangan mencari pembanding gambar yang lebih pintar, tapi tambahkan struktur yang diketahui**. Semua pembanding gambar butuh struktur yang stabil. Penanda cetak (fiducial) adalah jawaban standar untuk pose kamera di lingkungan "textureless" ([Calvet dkk., CVPR 2016](https://openaccess.thecvf.com/content_cvpr_2016/papers/Calvet_Detection_and_Accurate_CVPR_2016_paper.pdf)). Penghitung komersial memilih memaku geometrinya: XpertCount adalah "ember ajaib" tertutup dengan kamera internal ([Global Seafood Alliance](https://www.globalseafood.org/advocate/one-fish-two-fish-fish-counting-tech-nets-funding-for-canadian-engineering-firm/)). Tinggi juga terbukti penting. Pada penghitungan udang dengan iPhone, MAPE YOLOv5m6 naik dari 7,39% di 100 cm menjadi 16,94% di 185 cm ([Bukas dkk. 2024](https://doi.org/10.1016/j.jclepro.2024.143024)).

| Metode | Butuh tekstur? | Memberi tinggi? | Memberi identitas box? | Hanya Apple? | Bukti |
|---|---|---|---|---|---|
| **Rig tetap** (dudukan HP) | Tidak | **Menghilangkan error tinggi**, bukan sekadar mendeteksinya | Tidak | Ya (fisik) | Dipakai penghitung komersial ([GSA](https://www.globalseafood.org/advocate/one-fish-two-fish-fish-counting-tech-nets-funding-for-canadian-engineering-firm/)) |
| **Label QR** dibaca `VNDetectBarcodesRequest` | Tidak, label membawa kontrasnya sendiri | Ya, dari ukuran pikselnya | **Ya**, dari isi kode | Ya | Vision memberi 4 sudut, isi, dan jenis kode ([Apple](https://developer.apple.com/documentation/vision/vnbarcodeobservation)). Penanda cetak (AprilTag) mencapai error jarak 0,26 cm di 30 cm dan 0,63 cm di 50 cm ([Abbas dkk. 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6960891/)) |
| Gambar acuan ARKit | Butuh gambar kontras tinggi, tidak mengilap | Ya | Ya | Ya | Butuh ukuran fisik, dan kilau mengganggu ([Apple](https://developer.apple.com/documentation/arkit/detecting-images-in-an-ar-experience)). ARSession mengambil alih kamera, sehingga bentrok dengan fokus, eksposur, dan senter yang dikunci |
| Registrasi homografi Vision | Ya | Secara teori | Tidak | Ya | Apple tidak mendokumentasikan algoritma maupun skor keyakinannya. Hasil terbaik dicapai saat isi gambar "very similar" ([Apple](https://developer.apple.com/documentation/vision/aligning-similar-images)) |
| Fourier-Mellin (korelasi fase dengan skala) | Ya | Ya | Tidak | Ya (Accelerate) | Kehilangan ketangguhan kalau struktur hanya sebagian kecil gambar ([US 8390291](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8390291)) |
| Feature print | Isi semantik | Tidak | Tidak untuk box serupa | Ya | Kemiripan "semantic" ([WWDC19](https://developer.apple.com/videos/play/wwdc2019/222/)) |
| NCC | **Ya** (±8 tingkat abu-abu) | Tidak bisa membaca skala | Lemah | Ya | ([IAPRS 1995](https://goobi.tib.eu/viewer/!fulltext/1067806741/133)) |
| ARKit tanpa LiDAR, `lensPosition` | Ya, atau tidak terkalibrasi | Tidak andal | Tidak | Ya | `lensPosition` "doesn't correspond to an exact physical distance" ([Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lensposition)) |
| Ukuran benur | Tidak | Kasar | Tidak | Ya | Variasi panjang PL12 dalam satu populasi ±17,5% ([PMC10072957](https://pmc.ncbi.nlm.nih.gov/articles/PMC10072957/table/tab4)). Hanya cocok sebagai peringatan |

Hitungan untuk label QR, memakai **rumus pinhole**: tinggi = fx × ukuran asli ÷ ukuran di piksel, dengan fx adalah fokus kamera dalam piksel. Dengan fx 3067 px pada lebar 4032 px *(diukur, dari intrinsics registrasi)*, label 5 cm di 45 cm tampil sekitar **340 px** di foto penuh, atau sekitar 160 px di frame video 1920 px. Salah 1 px di sudut setara 0,3–0,6% skala, atau **0,15–0,3 cm** *(hitungan)*. Itu setara dengan kartu ID-1 yang sudah tervalidasi ±0,5 cm. Sebagai pembanding, perubahan tinggi 1 cm di 45 cm mengubah skala 2,2%. Matriks fx tersedia per frame lewat `isCameraIntrinsicMatrixDeliveryEnabled` ([Apple](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled)). Akurasi sudut QR dari Vision belum pernah dipublikasikan, jadi angka di atas harus dibuktikan di HP.

## Kenapa penjelasannya berubah-ubah

Jawaban jujurnya: **riset dan pengukuran tidak dilakukan lebih dulu.** Setiap perubahan dibuat sebagai reaksi atas satu log yang gagal, tanpa lebih dulu memeriksa apakah adegan ini punya sinyal yang bisa dipakai NCC. Pemeriksaan itu murah. Cukup hitung simpangan baku thumbnail acuan dan bandingkan dengan literatur, dan hasilnya (5,4 lawan sekitar 8) akan langsung memperlihatkan masalahnya.

| Yang dikatakan di chat | Faktanya |
|---|---|
| 09:55 UTC: NCC dengan blur dan geser, "beda tinggi atau box lain tetap ditolak" | **Tidak pernah diukur.** Pada 15:25 UTC sendiri diakui "belum diukur" |
| 15:41 UTC: "frame hanya berisi dasar polos, tidak ada tepi" | **Tidak akurat.** Tepi kertas dan bibir box ada di frame, hanya kontrasnya ±5 tingkat abu-abu (std 5,36) *(diukur)* |
| 15:41 UTC: "sensor diam tetap dicek" saat cek wadah | **Salah.** `gerbangCocok` tidak punya cek diam maupun cek miring *(kode)* |
| Kegagalan cek wadah 15:57–15:58 UTC (22:57–22:58 WIB) dikaitkan dengan NCC | NCC saat itu dilewati. Yang gagal adalah **peta cahaya: 0,268 dan 0,282 lawan batas 0,25** *(diukur)* |
| Baseline "angkat-taruh" mengukur keakuratan menaruh ulang HP | 7/10 registrasi berjarak 3–5 detik, jadi HP hampir pasti tidak diangkat *(diukur)* |
| Ambang cek wadah dianggap sudah pas | Ambang diambil apa adanya dari spesifikasi 6 Nov dan **tidak pernah dikalibrasi di HP** *(kode)*. Hanya `minBaselineNCC` 0,6 yang ditambahkan belakangan |

Urutannya jadi tiga cerita yang berbeda: "terlalu sensitif" (blur dan geser), lalu "tidak ada tepi" (dilewati), lalu "thumbnail satu piksel mengukur noise". Penjelasan ketiga paling cocok dengan data. Transkrip juga menyebut perubahan 16:02 UTC (NCC dihidupkan lagi dengan thumbnail rata-rata blok) dan dokumen "Catatan Pengerjaan", tapi keduanya tidak ada di disk. Penjelasan paling mungkin: percakapan di-rewind dan app mengembalikan file ke titik itu, yang sesuai dengan cap waktu file 00:13:53 WIB. Laporan ini memakai kode di disk sebagai keadaan sekarang.

## Rekomendasi: pilihan untuk kamu putuskan

Semua saran mengikuti batasan kamu: gerbang sedikit dan bisa disetel, alur selalu bisa selesai, hanya framework Apple, dan semua angka di `ambang.json`. **Belum ada kode yang diubah.**

**Opsi berbukti: satu label QR matte.** Tempel label QR kecil (sekitar 5 cm, cetakan matte, tahan air) di tempat yang selalu masuk frame dan sebisa mungkin di atas air, misalnya di bibir atau ujung atas dinding box. Kilau dari permukaan mengilap mengganggu deteksi ([Apple](https://developer.apple.com/documentation/arkit/detecting-images-in-an-ar-experience)). Vision membaca label itu di frame yang sama yang sudah dipakai. Dari satu label didapat tiga hal: **ID box** (isi kode cocok atau tidak), **tinggi** (ukuran piksel lawan ukuran saat registrasi), dan **posisi** (letak pusat label di frame). Opsional, tambah 2–3 kotak hitam di sudut bibir. Kalau semuanya terlihat dengan jarak aman dari tepi frame, berarti seluruh dasar masuk frame. Ada dua catatan jujur. Pertama, di foto bukti, bibir box hanya tampak sebagai jalur tipis di tepi frame, jadi uji pertama adalah memastikan label di bibir memang terbaca. Kalau tidak terbaca, alternatifnya adalah label di sudut dasar di bawah air setinggi 0,5 cm. Pergeseran refraksinya sekitar 1 mm *(hitungan)*, tapi risiko kilaunya harus diuji. Kedua, opsi ini bertentangan dengan preferensi lama kamu untuk tidak memakai penanda cetak, jadi keputusannya ada di kamu. Kalau label QR ditolak, **rig tetap adalah satu-satunya cara yang menghilangkan error tinggi**, bukan sekadar mendeteksinya. Kalau keduanya ditolak, tinggi saat hitung tetap hanya dijaga oleh ukuran benur, dan label hasil harus jujur menyebutnya.

Gerbang label diusulkan sebagai **peringatan, bukan blok**. Kalau label tidak terbaca, hitungan tetap selesai dengan cap "identitas/tinggi belum terverifikasi". Kunci baru di `ambang.json` cukup tiga: ukuran sisi label (mm), toleransi skala (%), dan geser pusat maksimum (px). Nilai awalnya diisi dari uji 2 dan 7 di bawah.

| Cek yang ada | Tindakan | Alasan |
|---|---|---|
| NCC | **Log saja** | Di dasar polos yang diukur adalah air, bukan pose |
| Feature print | **Pertahankan**, ganti pesan jadi "pemandangan berbeda", kunci revisinya | Berguna untuk menangkap tangan, meja, atau kamera salah arah. Tidak untuk identitas box |
| Peta cahaya | **Setel ulang** dari uji 1 dan 4, simpan foto saat gagal | 0,25 menolak sesi yang sah |
| Kecerahan | **Pertahankan** | Bekerja |
| Sensor diam | **Pertahankan** di acuan dan hitung | Cek wadah tidak memotret untuk hitung |
| Ukuran benur | **Setel ulang** setelah uji 5. Tetap peringatan | ±35% terlalu longgar, dan tidak bisa membedakan stadia dari tinggi |
| Pita tepi | **Pertahankan**. Beri peringatan kalau sudut dasar tidak digeser saat registrasi | 9/10 profil memakai sudut bawaan |
| Kemiringan (mode taruh) | **Tambahkan** ≤ 5° ke gerbang hitung untuk kedua mode | Datanya sudah dihitung, hanya belum dipakai |

**Tujuh uji minimal di HP** untuk mengisi ambang. Ambang yang baik ditaruh di antara sebaran "kondisi sama" dan "kondisi salah", seperti cara literatur memilih ambang dari data.

| # | Uji | Cara | Mengisi |
|---|---|---|---|
| 1 | Ulang-taruh | 10× angkat-taruh HP, box dan lampu sama. Catat semua nilai | Sebaran "kondisi sama" untuk semua cek |
| 2 | Tinggi | Ganjal HP ke 40, 45, dan 50 cm, masing-masing 5×. Bandingkan dengan meteran | Cek mana yang benar-benar bereaksi terhadap tinggi, dan toleransi skala label |
| 3 | Pemandangan lain | Box lain, tangan masuk frame, kamera diarahkan ke meja | Ambang feature print |
| 4 | Cahaya | Tutup terbuka, lampu kamar nyala | Ambang peta cahaya |
| 5 | Benur asli | PL-10 di 45 cm, median panjang dalam piksel | Toleransi ukuran benur |
| 6 | Baca label | 20 sesi dengan senter nyala, label kering dan basah, matte dan laminasi | Apakah opsi QR layak |
| 7 | Geser | HP digeser 1, 2, dan 3 cm ke samping | Geser pusat maksimum, dan reaksi pita tepi |

## Kesimpulan

Masalahnya tidak pernah ada di ambang NCC. **Adegannya memang tidak membawa sinyal posisi.** Dasar putih di bawah air bersenter adalah kasus buruk yang sudah dikenal untuk semua pembanding gambar. Tiga putaran perbaikan NCC adalah usaha memeras sinyal yang tidak ada. Begitu itu diterima, pilihannya jadi sederhana dan bisa diuji: bawa struktur sendiri ke dalam frame (label), atau kunci tingginya secara fisik (rig). Cek cahaya, kecerahan, dan sensor diam yang sudah ada cukup untuk sisanya, setelah ambangnya disetel dari data.

Pelajaran prosesnya sama penting. Sebelum sebuah cek dijadikan gerbang, tiga angka harus sudah diukur: sebaran saat kondisinya sama, sebaran saat kondisinya salah, dan apakah keduanya terpisah. Untuk NCC, feature print, dan ukuran benur, ketiga angka itu belum pernah ada. Tujuh uji di atas adalah cara termurah untuk mendapatkannya sebelum kode diubah lagi.
