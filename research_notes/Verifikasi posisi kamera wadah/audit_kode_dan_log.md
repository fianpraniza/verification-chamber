# Audit of the ShrimpWatch container-verification gates: code and device logs

How to read this:
- **[code]** means read directly from source. **[log]** means measured on the iPhone 17 and read from the device logs or the saved profile. **[computed]** means arithmetic I did from code and log values. **[transcript]** means a statement made in the earlier chat session, which is not proof.
- Log timestamps are UTC (`...Z`). Local time is WIB = UTC+7. Evidence: log4 was pulled at 15:59:50Z, and the file's mtime is 22:58 local. So "the 15:38 registration" is 15:38:01Z = 22:38 WIB.
- log3.jsonl (124 lines) is an exact prefix of log4.jsonl (129 lines). log4 adds only the 15:57 registration and the two `cekWadahGagal` lines. All line numbers below are 0-based line indices in log4.

Source shorthand (all local files):
- Inti = `</Users/fianpraniza/Documents/Arfian FIles/Academy/Project/FINAL/FineTune/ShrimpWatch/ShrimpWatch/Inti.swift>`
- Kamera = `<.../ShrimpWatch/ShrimpWatch/Kamera.swift>`
- App = `<.../ShrimpWatch/ShrimpWatch/App.swift>`
- Hitung = `<.../ShrimpWatch/ShrimpWatch/Hitung.swift>`
- Kartu = `<.../ShrimpWatch/ShrimpWatch/Kartu.swift>`
- ambang = `<.../ShrimpWatch/ShrimpWatch/ambang.json>`
- log4 = `</private/tmp/claude-501/-Users-fianpraniza-Documents-Arfian-FIles-Academy-Project-FINAL-FineTune/b742ff36-09e9-494b-846d-24c165f99b22/scratchpad/log4.jsonl>`
- profil = `profil.json` and `bukti_kecil.jpg` / `thumb_48b.png` in that same scratchpad folder
- T = `</Users/fianpraniza/.claude/projects/-Users-fianpraniza-Documents-Arfian-FIles-Academy-Project-FINAL-FineTune/b742ff36-09e9-494b-846d-24c165f99b22.jsonl>`
- T0 = the Nov 5–6 session `<.../f13ee4c9-5e15-4804-9b7c-2ad5bce7ad84.jsonl>`
- Mem = `</Users/fianpraniza/.claude/projects/-Users-fianpraniza-Documents-Arfian-FIles-Academy-Project-FINAL-FineTune/memory/shrimpwatch-prototype.md>`

---

## Q1. What each check measures, how it is computed, its threshold, and which ideal condition it protects

### Takeaway
There are four gate functions. `gerbangAcuan` covers the reference photos: ISO, phone still, and tilt in pegang mode only. `gerbangCocok` is cek wadah: NCC, feature print, light-map deviation, and brightness. It has **no stillness check and no tilt check**. `gerbangHitung` runs before the count photo: phone still, brightness, and sharpness plus tilt in pegang mode only. `validasiFoto` checks each detection photo: count, edge band, benur size, density, overlap, and confidence. The thresholds come verbatim from the user's own ambang.json spec of Nov 6 and were never calibrated on the device. The one exception is `minBaselineNCC` 0.6, which was added on Nov 8 at 15:40Z.

### Cited Findings

**Inputs produced by Kamera.swift for every video frame** [code]
- The connection uses `videoRotationAngle = 90`, so frames are portrait. The motion manager runs at 1/30 s. — [Kamera:175-182](<Kamera>)
- **thumb**: `Luma(pixelBuffer:pb, panjang: 64).px`. It is nearest-neighbour: each thumb pixel is **one single source pixel** `base[sy*bpr + x*W/w]`, with no averaging. The output is 48 wide × 64 tall, 3072 values. — [Kamera:7-18, 280](<Kamera>)
  - [log] Confirmed in the 15:57 profile: `thumb` has 3072 values. — [profil](<profil>)
- **kecerahan**: the mean Y of a 480-px nearest-neighbour Luma (`sisiAnalisisPX` 480). — [Kamera:275-278](<Kamera>), [ambang](<ambang>)
- **peta**: the mean of each cell in a 4×4 grid of that 480-px Luma, divided by its own mean (`Rumus.normal`). It describes the light *distribution*, not absolute brightness. — [Kamera:279](<Kamera>), [Inti:303, 527-531](<Inti>)
- **ketajaman**: the variance of the 4-neighbour Laplacian on the 480-px Luma. — [Inti:533-542](<Inti>)
- **putar / geser**: per video frame, take |rotationRate| in °/s and |userAcceleration| in g. Keep the last 15 samples, about 0.5 s, and use the **maximum**. The default before 15 samples exist is putar 90 and geser 1.0, meaning "moving". — [Kamera:268-272, 282](<Kamera>), [Inti:464-465](<Inti>)
- **kemiringan**: average gravity over the last 15 samples, then the angle `acos(|gz|/|g|)` between the device z axis (the camera axis) and vertical. — [Kamera:283-285](<Kamera>)
- **iso**: the *locked* ISO from `setelan`, not a live reading. — [Kamera:281](<Kamera>)
- **jarakFP** (cek wadah only): every 15th frame (about 2×/s), compute `VNGenerateImageFeaturePrintRequest` on the full video buffer, then `computeDistance` to the stored acuan-1 print. — [Kamera:291-295](<Kamera>), [Hitung:11-15](<Hitung>)
- Camera settings are identical in every mode. Acuan 1 locks ISO, exposure, WB, focus (lens position from the card step), and torch 0.8. Acuan 2, cek wadah, and hitung re-apply those settings. — [Kamera:183-263](<Kamera>)
- A gate "passes" only after `frameStabil` = **15 consecutive** passing frames. One failing frame resets the counter. In test mode (`gerbangPeringatan`), the counter keeps running even when checks fail. — [Kamera:301-306](<Kamera>), [ambang](<ambang>)

**gerbangAcuan (reference photos 1 and 2)** [code] — [Inti:478-485](<Inti>)

| Check | Formula | Threshold (ambang.json) | Failure → message | Protects |
|---|---|---|---|---|
| ISO | locked `setelan.iso` | ≤ 800 (`maksISO`) | cahayaLemah | enough light from the torch |
| putar °/s | max \|ω\| over ~0.5 s | ≤ 5 (`maksPutarDerajatPerDetik`) | goyang | phone still |
| geser g | max \|userAccel\| over ~0.5 s | ≤ 0.03 (`maksGeserG`) | goyang | phone still |
| kemiringan ° (pegang only) | angle to vertical | ≤ 10 (`maksKemiringanPegangDerajat`) | hpMiring | phone level |

- There is no sharpness check, on purpose. The code comment says an empty box always scores about 30, and focus is locked from the card. — [Inti:475-477](<Inti>)
- In acuan 2 the ISO check is redundant. Acuan 2 reuses acuan 1's settings, so `u.iso` is the same number. The logs confirm identical ISO in every acuan pair. — [Kamera:184, 281](<Kamera>), [log4 lines 99-126](<log4>)

**gerbangCocok = "cek wadah"** [code] — [Inti:488-499](<Inti>), thresholds from [Inti:256-259](<Inti>)

| Check | Formula | Threshold | Failure → message | Intended to protect |
|---|---|---|---|---|
| NCC | `nccPosisi(live thumb, acuan1 thumb)`: 3×3 box blur on both thumbs, then the best Pearson NCC over shifts dx, dy ∈ [−3, +3] px, compared on the central 42×58 px | `minNCC` = **−1 (skipped)** if nccBaseline < 0.6, else min(0.80, nccBaseline − 0.05) | posisiBeda ("Tinggi atau posisi HP berbeda") | same phone position and height as at registration (and same box) |
| feature print | Vision feature-print distance to acuan 1 | ≤ max(3.0 × fpBaseline, 0.15) | wadahBerbeda | same box |
| deviasi cahaya | max over 16 cells of \|peta_live/peta_acuan − 1\| | ≤ 0.25 (`maksDeviasiPetaCahaya`) | cahayaBeda | same light pattern (lid closed, room lights off) |
| selisih kecerahan | kecerahan_live / kecerahan_acuan − 1 | \|·\| ≤ 0.25 (`toleransiKecerahan`) | cahayaBeda | similar overall light |

- `gerbangCocok` does **not** call `cekDiam` and has no tilt check. Phone stillness is not checked during cek wadah. — [Inti:488-499](<Inti>)
  - This contradicts the 15:41Z chat message, which said "sensor diam tetap dicek". — [T line 591](<T>)
- The FP check runs only `if let f = u.jarakFP`. If Vision returns no print, or the stored acuan print is empty, the FP check never runs. At registration `featurePrint` falls back to `Data()` when Vision fails. — [Inti:493](<Inti>), [Kamera:142-144, 312](<Kamera>)
- Failure messages are hidden for the first 5 s ("Mencocokkan dengan foto acuan…"). — [App:409](<App>), [Kamera:303](<Kamera>)
- On pass, the log gets a `cekWadah` line. After more than 5 s of failing, it gets one `cekWadahGagal` line per camera session. — [Kamera:304, 317](<Kamera>)
- The NCC shift range is ±3 px on a 48-px-wide thumb. At 45 cm the 1x 4:3 frame covers about 44.6 × 59.5 cm on the floor, about 0.93 cm per thumb pixel, so ±3 px ≈ **±2.8 cm** [computed, from fx 3067.268 on 4032 px, log line 92]. The code comment says "±2–3 cm". — [Inti:261-265](<Inti>)

**gerbangHitung (live gate before the 5 count photos)** [code] — [Inti:504-515](<Inti>)

| Check | Threshold | Mode | Protects |
|---|---|---|---|
| putar °/s, geser g (`cekDiam`) | ≤ 5, ≤ 0.03 | both | phone still (no motion blur) |
| ketajaman | ≥ 60 (`minKetajaman`) | **pegang only** | not blurred by hand shake |
| kemiringan ° | ≤ 10 | **pegang only** | phone level |
| selisih kecerahan vs acuan | ±0.25 | both | similar light |

- There is no NCC, no feature print, no light map, and no position or height check in this gate. — [Inti:504-515](<Inti>)

**validasiFoto (each of the 5 photos, after detection)** [code] — [Inti:583-627](<Inti>); detection pipeline in [Hitung:57-74, 89-110](<Hitung>)

| Check | Formula | Threshold | Message | Protects |
|---|---|---|---|---|
| jumlah | detections ≥ 1 | ≥ 1 | wadahKosong | benur actually present |
| jumlah | detections ≤ cap | ≤ 4000 (`maksKapasitas`) | terlaluBanyak | within capacity |
| di pita tepi | count of boxes whose **centre** is within 3% of any image edge | must be 0 (`pitaTepi` 0.03) | dasarTerpotong | whole floor in frame |
| panjang benur px | median of max(w, h) of the boxes in the detection image; \|median/panjangPX − 1\| | ≤ 0.35 (`toleransiSkalaBenur`) | skalaTidakSesuai ("Jarak HP atau wadah tidak sesuai") | phone height ≈ registered height (and correct stadium) |
| terlalu dekat | fraction of boxes with a neighbour (IoU ≤ 0.3) whose centre is closer than 0.5 × median √area | ≤ 0.05 | terlaluRapat | benur spread out |
| bertumpuk | fraction with IoU > 0.3 to a neighbour | ≤ 0.02 | bertumpuk | no overlapping benur |
| rata keyakinan | mean confidence | ≥ 0.75 | keyakinanRendah | model confident |
| keyakinan rendah | fraction with confidence < 0.6 | ≤ 0.10 | keyakinanRendah | model confident |

- The check needs at least 3 passing photos out of 5 (up to 10 attempts), and the spread (max − min)/median ≤ 0.02. Otherwise the result is hasilTidakStabil. The result is the median. — [Inti:630-641](<Inti>), [Kamera:345](<Kamera>)
- `panjangPX` = panjangMM ÷ (mm per px). The photo is first resized to `sisiDeteksi` = 1920·Z₀·tan(f/2) / (44·tan(f_latih/2)), where Z₀ is the **registered** `profil.jarakCM`. — [Inti:248-251, 400-403](<Inti>), [Hitung:93-96](<Hitung>)
  - [computed] Substituting one into the other, Z₀ and the 1x FOV cancel: panjangPX = panjangMM·1920 / (880·tan(f_latih/2)). The *expected* size is a constant per stadium.
  - [log] panjangPX = 17.01 (lines 97, 98) and 17.004 (line 114) for PL-10 (8.65 mm).
  - [computed] That implies a training FOV of ≈ 96°.

**Registration-only checks** [code]
- `catatanWadah` has two parts. Card distance must be 35–55 cm (`jarakKameraKeDasarCM`), and the 4 dragged floor corners must lie outside the 3% edge band. These only add a "belum terverifikasi" note. They never block. — [Inti:376-390](<Inti>), [Kartu:457](<Kartu>)
- Card auto-capture needs the card's tilt to be ≤ 5° from gravity (`kartu.maksMiringDerajat`). It also needs 10 detections (`frameHalus`) with spread ≤ 1.5 cm. — [Kartu:129-132, 363-366](<Kartu>), [ambang](<ambang>)
- A profile expires and requires re-registration after 30 days, or after a change of versi, lens, or phone model. — [Inti:450-452](<Inti>)

**Origin of the thresholds**
- `minNCC` 0.80, `pengaliBaseline` 3.0, `minBatasFeaturePrint` 0.15, `maksDeviasiPetaCahaya` 0.25, `toleransiKecerahan` 0.25, and all `hasil.*` values appear verbatim in the ambang.json the user pasted as the spec on Nov 6. The assistant then wrote "kunci persis dari spesifikasi lu". — [T0 lines 426, 606](<T0>)
- In that session the assistant already flagged two conflicts. Confidence thresholds of 0.5/0.75 vs a snap_now mean of ≈ 0.45 would reject most photos. `terlaluRapat` at 5% vs 16% "too close" at 500 randomly spread benur. — [T0 line 313](<T0>); risks repeated in [Mem](<Mem>)
- `minBaselineNCC` 0.6 was added on 2026-11-08 at 15:40Z. — [T line 571](<T>)
- Gyro and accelerometer limits (5 °/s, 0.03 g) first appear in acuan logs at 08:38:57Z. Acuan entries at 08:33 still show only ISO. — [log4 lines 99-103](<log4>)

### Inferences
- In taruh mode, nothing checks tilt after the card step. A ≤ 5° tilt is enforced only while the card is being read. — [Inti:483, 508-511](<Inti>), [Kartu:363](<Kartu>)
- Brightness ±25% is weakly sensitive to phone height, because the torch is the only light source. But the Y channel is gamma-encoded and the frame includes the white walls, so no height tolerance can be derived from it. Treat it as unquantified.

### Gaps
- The video-buffer resolution under the `.photo` preset is not logged. The exact source-pixel stride behind each thumb pixel is unknown (W/48 source pixels).
- Apple does not document the scale of `VNFeaturePrintObservation.computeDistance`. No calibration exists of FP distance for "same box" vs "different box" on this setup.

---

## Q2. Why NCC exists, and exactly when it is skipped today

### Takeaway
NCC came from the Nov 7 v1 design. A reference photo, plus a second "lift and replace" photo that sets a baseline, was meant to confirm that the phone is back at the same position and height, looking at the same box. In the current code, NCC is skipped whenever the registration baseline (acuan 1 vs acuan 2) is below 0.6. All four registrations since 13:49Z fall in that case, so on the user's present setup NCC is skipped every time.

### Cited Findings
- [code] The v1 design was: "Reference photo plus a second 'lift and replace' photo gives a baseline. The NCC and feature-print match threshold comes from that baseline." — [Mem](<Mem>)
- [code] The registration screen between acuan 1 and acuan 2 tells the user: "Angkat HP lalu taruh atau pegang lagi di posisi yang sama". — [App:149-153](<App>)
- [code] `nccBaseline = Rumus.nccPosisi(a1.thumb, a2.thumb)` and `fpBaseline = Visi.jarak(a1.featurePrint, a2.featurePrint) ?? 0`. These are stored in the profile, and the profile keeps **acuan 1** as the reference. — [App:154-158](<App>)
- [code] The skip rule is `minNCC = nccBaseline < minBaselineNCC(0.6) ? −1 : min(0.80, nccBaseline − 0.05)`. NCC is in [−1, 1], so `n >= −1` always passes, and the panel shows "dilewati (dasar polos)". — [Inti:253-259, 492](<Inti>), [ambang](<ambang>)
- [code] The decision is made once, at registration, from the stored baseline. It is not re-evaluated per session. A profile with a baseline ≥ 0.6 keeps NCC active. — [Inti:489](<Inti>)
- [code] The code comment states the rationale: "Baseline NCC rendah = frame hanya berisi dasar polos (tidak ada tepi/dinding), jadi NCC cuma mengukur noise dan pantulan air … Tinggi HP tetap dijaga cek ukuran benur saat hitung." — [Inti:254-255](<Inti>)
- [log] The saved 15:57 profile and the bukti photo contradict the "no edges/walls" premise:
  - The bukti JPEG shows the floor covered with overlapping white paper sheets. Paper-sheet edges are visible inside the frame, and the ribbed styrofoam rim and walls are visible in a narrow strip along all four frame edges.
  - The acuan-1 thumb (48×64) has values 91–156, mean 130.01, and **std 5.36 grey levels**.
  - Its row means run 136→126→129→137 top to bottom. Its column means run 134→126 left to right.
  - So edges are present, but at very low contrast. — [profil / bukti_kecil.jpg / thumb_48b.png](<profil>)
- [transcript] At 16:02Z the assistant diagnosed the low baseline as noise from single-pixel thumb sampling of a ±5-level scene, not as the absence of edges. It reported a Mac simulation where block-averaging raised NCC from 0.82 to 1.00. That fix is **not** in the current code (see Q6). — [T lines 727-762](<T>)

### Inferences
- Under the current rule, NCC as a position or height guard is effectively off for this rig. The setup is a white paper floor, the 1x lens at about 45 cm, and nearest-neighbour thumbs. NCC protects nothing until a registration produces a baseline ≥ 0.6.
- The baseline is computed between two photos the user is told to separate by lifting the phone. In practice most pairs were 3–5 s apart (Q3), which is too short to lift and replace. So the baseline mostly measures frame-to-frame noise, not placement repeatability.

### Gaps
- No device test exists of how much NCC (`nccPosisi`) drops for a known height change (for example +5 cm) or for a different box on this rig. The 15:25Z chat message proposed such a test but no log of it exists. — [T line 515](<T>)

---

## Q3. What the device logs show

### Takeaway
There are 10 `daftar` entries, all on 2026-11-08 and all `v5-lensa1x`. Card distance was very consistent at 44.26–45.54 cm. nccBaseline ranged 0.193–0.994. All four registrations after 13:49Z had nccBaseline 0.193–0.520, even with the phone still (putar ≈ 0.16 °/s). There are 3 passing `cekWadah` lines (NCC 0.775–0.943) and 2 `cekWadahGagal` lines. Both failures were on light-map deviation, 0.268 and 0.282 against a 0.25 limit, while NCC read about 0 and was skipped. Nine of ten registrations logged exactly 48 × 35 cm, which is the undragged default corner box.

### Cited Findings
**All `daftar` entries** [log] — [log4](<log4>). "Gap" = time from the acuan-1 log line to the acuan-2 log line. The acuan values are (putar °/s, geser g) or ketajaman where logged, and ISO.

| line | waktu (Z) / WIB | mode | jarakCM | nccBaseline | fpBaseline | P × L (cm) | airML | posisiLensa kartu / acuan | gap | acuan1 → acuan2 |
|---|---|---|---|---|---|---|---|---|---|---|
| 92 | 08:21:58 / 15:21 | taruh | 45.232 | 0.4646 | 0.8145 | **45.278 × 39.432** | 900 | 0.549 / 0.549 | 7 s | tajam 82.3 → 157.6; ISO 105.5 |
| 95 | 08:22:19 / 15:22 | taruh | 44.952 | **0.9942** | 0.0437 | 48.0 × 35.0 | 850 | 0.541 / 0.541 | 4 s | tajam 155.4 → 156.3; ISO 121.1 |
| 101 | 08:33:40 / 15:33 | taruh | 44.976 | 0.5490 | 0.2717 | 48 × 35 | 850 | 0.545 / 0.549 | 12 s | ISO 47.2 only |
| 104 | 08:39:01 / 15:39 | taruh | 45.158 | 0.6804 | 0.1508 | 48 × 35 | 850 | 0.549 / 0.549 | 4 s | putar 0.204 → 0.197; geser 0.010 → 0.010; ISO 131.9 |
| 108 | 09:20:10 / 16:20 | taruh | 44.923 | 0.6795 | 0.1107 | 48 × 35 | 850 | 0.545 / 0.549 | 5 s | putar 0.973 → 0.190; geser 0.014 → 0.010; ISO 132 |
| 111 | 09:30:16 / 16:30 | taruh | 45.155 | 0.7597 | 0.0975 | 48 × 35 | 850 | 0.5255 / 0.5255 | 3 s | putar 0.162 → 0.167; geser 0.011 → 0.011; ISO 82.6 |
| 117 | 13:49:57 / 20:49 | taruh | 45.006 | 0.1928 | 0.2201 | 48 × 35 | 850 | 0.541 / 0.541 | 3 s | putar 0.182 → 0.162; geser 0.011 → 0.011; ISO 83.4 |
| 120 | 13:51:22 / 20:51 | pegang | 44.257 | 0.5195 | 0.2883 | 48 × 35 | 850 | 0.541 / 0.541 | 10 s | putar 4.373 → 4.017; geser 0.023 → 0.026; kemiringan 0.39 → 0.62; ISO 199.3 |
| **123** | **15:38:01 / 22:38** | taruh | 45.539 | **0.2155** | 0.2554 | 48 × 35 | 850 | 0.5686 / 0.5725 | 4 s | **putar 0.166 → 0.160; geser 0.008 → 0.008**; ISO 85.1 |
| 126 | 15:57:19 / 22:57 | taruh | 45.184 | 0.1955 | 0.2157 | 48 × 35 | 850 | 0.5647 / 0.5647 | 3 s | putar 0.143 → 0.170; geser 0.010 → 0.013; ISO 83.1 |

- All entries have `lensaX` 1, empty `catatan` (so "terverifikasi"), and `modeUji` false. Card tilt `miringDerajat` was 0.31–2.08°. Card spread `sebaranCM` was 0.045–1.274 cm. — [log4](<log4>)
- **15:38Z registration** [log]: the phone was still during both reference photos (putar 0.166 and 0.160 °/s, geser 0.008 g, both far under 5 °/s and 0.03 g). The photos were 4 s apart. nccBaseline was still only **0.2155**. The user confirmed in chat that the phone was not moved ("daftari wadah tanpa mindahin hp"). — [log4 lines 121-123](<log4>), [T line 519](<T>)
- [log] fpBaseline (0.2554 at 15:38) is about the same size as in the moved and pegang cases (0.22–0.29). So FP does not separate "not moved" from "moved" either.

**cekWadah / cekWadahGagal entries** [log]

| line | waktu (Z) | profile in use (baseline) | NCC | feature print | deviasi cahaya | selisih kecerahan | result |
|---|---|---|---|---|---|---|---|
| 96 | 08:22:34 | line 95 (ncc 0.994, fp 0.044) | 0.943 (≥ 0.80) | 0.129 (≤ 0.15) | 0.008 | −0.005 | pass |
| 112 | 09:30:22 | line 111 (0.760, 0.098) | 0.921 (≥ 0.71) | 0.056 (≤ 0.293) | 0.023 | 0.010 | pass |
| 113 | 13:45:50 | line 111 (0.760, 0.098) | 0.775 (≥ 0.71) | 0.160 (≤ 0.293) | 0.033 | −0.012 | pass |
| 127 | 15:57:30 | line 126 (0.196, 0.216) | **−0.010** (skipped) | 0.322 (≤ 0.647) | **0.268 > 0.25** | 0.019 | **fail: cahayaBeda** |
| 128 | 15:58:18 | line 126 | **−0.056** (skipped) | 0.332 | **0.282 > 0.25** | 0.049 | **fail: cahayaBeda** |

- Lines 127–128 have NCC `lolos: true` despite values of about 0. This proves that the build installed at 15:57 had the skip rule (`minNCC = −1`) [log]. `cekWadahGagal` exists only in that build. — [Kamera:304](<Kamera>)
- Line 127 came 11 s after registration (15:57:19 → 15:57:30). Overall brightness was within 2%, but one 4×4 cell differed by 26.8%. — [log4](<log4>)

**hitung entries** [log]
- Lines 97, 98, and 114 (08:22:41, 08:22:53, 13:45:59) all had `perFoto` [0, 0, 0, 0, 0] and failed with wadahKosong. panjangPX was 17.01 / 17.01 / 17.004 and sisiDeteksiPX 1195.588 / 1195.588 / 1200.992.
- No v5 count with benur in the box exists in the logs. — [log4](<log4>)

**Other** [log]
- Lines 0–18 are an older schema: 8 `kerataan` lines (Nov 5), 5 count lines of `v1-sederhana`, and 8 `scan` lines (ARKit, Nov 6–7).
- 64 `ujiKartu` lines come from the card-distance test.
- One old v1 count (2026-11-05T20:58:25Z) with 364–531 detections per photo failed on `benurTerlaluKecil`. That was different code. — [log4 line 8](<log4>)

### Inferences
- Only one registration (08:22:19, ncc 0.994) produced a high baseline. Its acuan frames scored sharpness 155–156, while later empty-box frames are said to score about 30. That suggests a scene with more texture at that moment, but the scene is not recorded. [inference]
- Gaps of 3–5 s between acuan 1 and acuan 2 mean the phone was almost certainly not lifted and replaced between them in 7 of 10 registrations. The second photo still needs ≥ 1.2 s of camera setup plus 15 stable frames. So the "lift-and-replace" baseline was mostly never measured as designed. [inference from code timing, Kamera:222-229, and log gaps]
- The 48.0 × 35.0 values equal the default corner rectangle exactly. `LayarSudutDasar` seeds the corners at the nominal box (52 − 4) × (39 − 4) = 48 × 35 cm. The one dragged registration measured 45.278 × 39.432 cm, which gives 900 ml instead of 850 ml. — [Kartu:439-445](<Kartu>), [Inti:236-238](<Inti>), [computed: 45.278 × 39.432 × 0.5 = 892.7 → 900]
- The bukti photo (15:57) shows the yellow default rectangle sitting inside the real floor on the short axis. So the corner/edge-band registration check for 9 of 10 profiles was evaluated on an assumed rectangle, not on the real floor. [observation of bukti_kecil.jpg + code]

### Gaps
- The light-map failure at 15:57 has no saved image, so it is not known which cell changed or why. Candidates: torch glint on the water, a hand or shadow, a lid gap. The 16:02Z code that saved failure JPEGs is not in the current code.
- The logs carry no build identifier. Whether the 13:45:50 cek wadah used plain `ncc` or `nccPosisi` cannot be determined from the log. Entries ≤ 09:30Z predate the `nccPosisi` edit (09:55Z), so they used plain `Rumus.ncc`. — [T line 390](<T>)

---

## Q4. After cek wadah the phone is lifted to add benur. What protects the counting position?

### Takeaway
Once cek wadah passes, the flow goes to "masukkan benur", the user lifts the phone, then "hitung". The only checks that respond to phone **height** are the benur-size check, at ±35% around a constant expected size, and indirectly brightness. Only the edge band responds to **shift or lowering**, and only when benur are actually detected within 3% of the image edge. ±35% allows a camera distance of about 33.3–69.2 cm around 45 cm.

### Cited Findings
- [code] The flow is `pilih → cekWadah → masukkanBenur ("kembalikan HP ke posisi") → hitung`. Two paths reach hitung without a new cek wadah: "Tambah hitungan dari kantong yang sama" (→ masukkanBenur → hitung) and "Foto ulang" (→ hitung). — [App:221-286](<App>)
- [code] `gerbangHitung` checks only stillness, brightness ±25%, and (pegang only) sharpness and tilt. — [Inti:504-515](<Inti>)
- [code] Benur size: the median of max(w, h) of the boxes must be within ±35% of panjangPX. The photo is rescaled using the **registered** Z₀, so if the phone is really at Z, benur appear at (Z₀/Z) × expected. — [Inti:596-598](<Inti>), [Hitung:93-96](<Hitung>)
- [computed] Size ∝ 1/Z, and the condition is 0.65 ≤ Z₀/Z ≤ 1.35, so Z ∈ [Z₀/1.35, Z₀/0.65]:
  - Z₀ = 45 → **33.3–69.2 cm** (−11.7 / +24.2 cm).
  - Z₀ = 45.539 (15:38 profile) → 33.7–70.1 cm.
  - Z₀ = 45.184 (15:57) → 33.5–69.5 cm.
  - In pixels for PL-10: 11.06–22.96 px around 17.01 px.
  - This asymmetric 33–69 cm band matches what the assistant stated at 14:22Z and 15:51Z. — [T lines 501, 613](<T>)
- [code] Edge band: any detection whose centre is within 3% of an image edge → dasarTerpotong. — [Inti:591-592](<Inti>)
- [computed] Geometry from line 92 (fx 3067.268 on 4032 × 3024; Z 45.232; real floor 45.278 × 39.432 cm):
  - The frame covers 59.46 × 44.59 cm, and the floor fills 76% × 88% of it.
  - The margin between the floor edge and the frame edge is 7.09 cm (long axis) and 2.58 cm (short axis).
  - The 3% band is 1.78 / 1.34 cm wide.
  - With the phone centred, benur enter the band after a sideways shift of about 1.2 cm on the short axis or about 5.3 cm on the long axis.
  - Lowering the phone to about 42.5 cm puts the floor's long edges into the band. Below about 40.0 cm, the floor's long sides leave the frame.
  - **Raising** the phone never triggers the edge band.
- [code + memory] There is a known risk that the size check may be miscalibrated. snap_now boxes may cover only the head (about 8 px vs about 19 px full length at the old scale), so the check "may always fail". — [Mem](<Mem>)
  - [log] The check has never run on v5 data: all three v5 counts had 0 detections. — [log4 lines 97, 98, 114](<log4>)

### Inferences
- Between cek wadah and the count, phone height is guarded only to roughly −26% / +54% of the registered distance, through benur size. That is far wider than the ±0.5 cm card accuracy at registration. The training-distance band itself is 35–55 cm.
- A partial cut of the floor is caught only if some benur happen to sit in the outer 3% strip. Benur in the cut-off area are invisible and simply not counted.
- Since NCC is skipped and FP is loose (Q5), cek wadah itself does not verify height on this rig either. So in practice phone height is verified once, by the card at registration, and afterwards only by the ±35% benur-size band.

### Gaps
- The real median box length of PL-10 on this rig at 45 cm (1x, rescaled) is unmeasured. Without it, neither the 17-px expectation nor the ±35% band is validated, and tightening to 15–20% (proposed in [T line 613](<T>)) cannot be set.
- How brightness (±25%) responds to a height change under the torch is unmeasured.

---

## Q5. Conditions that are weakly guarded or unguarded

### Takeaway
On the current rig, two conditions are strongly guarded: phone still (gyro/accel at acuan and hitung) and registration distance (card). Phone height at count time is loose (±35% size → 33–69 cm). Same box is weak (FP limit 0.65–0.77 here; NCC skipped). Whole floor in frame is partial (edge band only when benur are near the edge; registration corners left at defaults). Water volume and tilt in taruh mode are not checked at all.

### Cited Findings
| Ideal condition | Where checked | Strength on this rig | Evidence |
|---|---|---|---|
| Same phone height | Card at registration (≤ 5° tilt, spread ≤ 1.5 cm). Count time: benur size ±35%. Cek wadah: NCC (skipped) | Registration strong. **Count: ~33–69 cm.** Cek wadah: none | [Inti:256-259, 596-598](<Inti>); [computed] |
| Same box | Feature print ≤ max(3 × fpBaseline, 0.15). NCC skipped | **Weak.** Limits for the post-13:49 profiles are 0.660 / 0.865 / 0.766 / 0.647. Same-box FP values seen: 0.056–0.332. No different-box value has ever been measured | [log4]; [computed: 3 × 0.2554 = 0.766] |
| Whole floor in frame | Registration: dragged corners outside 3% (non-blocking). Count: benur centres in the 3% edge band | **Partial.** 9/10 profiles used default 48 × 35 corners, not the real floor. The edge band fires only if benur lie there. It is checked only after benur are added, never at cek wadah | [Kartu:439-445](<Kartu>), [Inti:379-390, 591-592](<Inti>), [log4] |
| Similar light | Light map ≤ 0.25 and brightness ±25% (cek wadah). Brightness ±25% (hitung) | Working and strict. It blocked the 15:57 session (0.268 / 0.282) | [log4 lines 127-128](<log4>) |
| Phone still | Gyro ≤ 5 °/s, accel ≤ 0.03 g at acuan and hitung | Strong (values ≈ 0.16 °/s when resting). **Not checked during cek wadah** | [Inti:469-473, 488-499](<Inti>) |
| Phone level | ≤ 5° at the card step. ≤ 10° at acuan and hitung **in pegang mode only** | Taruh mode: none after the card step | [Inti:483, 508-511](<Inti>) |
| Water volume (0.5 cm depth) | Instruction text only ("Tuang 850 ml air") | **Unguarded.** The volume also comes from the default 48 × 35 corners (850 ml vs 900 ml from the dragged corners) | [App:142, 227](<App>); [log4 line 92 vs others] |
| Phone returned after adding benur | Benur size + edge band only. "Tambah hitungan" and "Foto ulang" skip cek wadah | Loose | [App:233-286](<App>) |
| Correct stadium | Benur size ±35% (same check as height) | Height and stadium errors cannot be told apart | [Inti:596-598](<Inti>) |

- The FP check is silently skipped if no feature print was stored or computed. — [Inti:493](<Inti>), [Kamera:312](<Kamera>)
- Test mode (`gerbangPeringatan`) turns every gate into a warning. It was false in all v5 logs. — [Kamera:302](<Kamera>), [log4](<log4>)
- In T0 the assistant flagged that two count-gate thresholds conflict with the model: confidence 0.75 vs a snap_now mean of ≈ 0.45, and `terlaluRapat` at 5% vs 16% at 500 random benur. These are still the active values. — [T0 line 313](<T0>), [ambang](<ambang>)

### Inferences
- FP's ability to reject a *different* box is unknown. The limit is 2–3× the largest same-box value seen. An identical white styrofoam box would almost certainly pass, and the chat itself conceded this at 15:25Z. — [T line 515](<T>)

### Gaps
- There is no device data for: a different box, a raised or lowered phone during cek wadah, or any benur-size readings.

---

## Q6. History of the NCC explanation and the code changes

### Takeaway
NCC changed three times in the chat:
1. Plain NCC (Nov 6–7 design).
2. Blur plus ±3-px shift search (`nccPosisi`), 09:55Z.
3. Auto-skip when baseline < 0.6, 15:40Z.

A fourth change at 16:02Z reverted the skip and switched to block-averaged thumbnails. **That fourth change is not in the code on disk today.** The code files (and the memory file) were rewritten at 2026-11-09 00:13:53 WIB, after the transcript ends, and match the post-15:40Z state. The Notes doc written at 17:09Z describes the 16:02Z state, so it disagrees with the current code.

### Cited Findings
- **Nov 6 (T0):**
  - The assistant built the gates from the user's spec, including "ambang cocok dari baseline, NCC, deviasi peta cahaya". — [T0 line 606](<T0>)
  - In the v1 design (Nov 7), NCC + FP matching against a reference photo with a lift-and-replace baseline was meant to confirm the same rig. — [Mem](<Mem>)
- **09:32Z** — the user reported: NCC fails after lifting the phone even though the whole floor is in frame. — [T line 325](<T>)
- **09:55Z change → `nccPosisi`** (3×3 blur + best shift ±3 px), used both for the baseline and for cek wadah. — [T line 390](<T>)
  - Stated reason: acuan pairs taken "in the same position" gave only 0.46–0.76, because torch glints, sensor noise, and mm-scale shifts were penalised.
  - Claim made then: a different height or a different box "tetap ditolak". — [T line 409](<T>)
- **14:22Z / 15:25Z explanations:**
  - The ideal-condition table: NCC guards height and box, the count-time size check guards height.
  - Height changes were said to be detectable because scaling can't be undone by the shift search. The assistant explicitly said this was "belum diukur". — [T lines 501, 515](<T>)
- **15:39Z** — the user: registered without moving the phone, and NCC still failed at cek wadah. — [T line 519](<T>)
- **15:40Z change → auto-skip.** `minBaselineNCC` 0.6 was added to ambang.json, `minNCC = −1` below it, the panel label became "dilewati (dasar polos)", and `cekWadahGagal` logging was added. — [T line 571](<T>)
  - Stated reason: the 15:38 baseline was 0.22 with the phone still (putar 0.16). The frame was said to hold "only a plain floor", so NCC measured noise.
  - The assistant also said its earlier claim (NCC detects height) "ternyata salah untuk setup ini". — [T line 591](<T>)
- **15:48–15:51Z** — the user objected, and the assistant explained:
  - NCC was designed when the lens was 0.6x, where walls were probably visible.
  - It was not re-checked after the switch to 1x.
  - Blur, shift, and skip were symptom patches made before looking at data.
  - The 15:51 strength table: height at count time "longgar" (33–69 cm), same box "lemah" (FP 0.77), water "tidak dicek". — [T lines 600, 613](<T>)
- **15:59Z** — the user: now light deviation blocks the count, and skipping NCC lets users count outside the box. — [T line 646](<T>)
- **16:02Z change** (in transcript):
  - The skip was reverted (`minBaselineNCC` removed).
  - The thumbnail became a block average (`Luma.perkecil`).
  - Failed checks would save grey JPEGs.
  - Diagnosis: the paper floor has about ±5 grey levels of contrast, and the single-pixel thumb was measuring noise. Mac simulation: 0.82 → 1.00.
  - The memory note added: "Never skip or loosen a gate to unblock". — [T lines 727, 739, 749, 762](<T>)
- **17:09Z** — the "ShrimpWatch — Catatan Pengerjaan" doc records the 16:02 state: "pelewatan NCC dibatalkan … Selesai", block-average thumb "belum dites di HP". — [T lines 833, 846](<T>)
- **Current disk state** [code / file metadata]:
  - Inti.swift, Kamera.swift, ambang.json, Cek/main.swift, and the memory file all have mtime 2026-11-09 00:13:53 (local), after the transcript's last event (17:10:28Z = 00:10 WIB).
  - Their contents contain `minBaselineNCC` 0.6 and the skip, the nearest-neighbour thumb, and no `perkecil` or failure JPEG.
  - The memory file lacks the 16:03Z note. — `ls -l` / grep of the project; [Inti:253-259](<Inti>), [Kamera:7-18](<Kamera>), [Mem](<Mem>)

### Inferences
- Each NCC change was a reaction to a device failure, explained before the data was examined. The sequence was: "too sensitive" (09:55), then "frame has no edges" (15:41), then "single-pixel thumb measures noise on a ±5-level scene" (16:04). The saved profile data (std 5.36 levels, visible paper edges) fits the third explanation best. That explanation is the one not present in the current code.
- Today the user faces a three-way mismatch: the code skips NCC, the Notes doc says the skip was cancelled, and the memory index omits the rule that was added.

### Gaps
- The transcript does not record what rewrote the files at 00:13:53 WIB (for example, a rewind or checkpoint restore).
- The block-averaged thumbnail was never run on the iPhone, so whether it raises the on-device baseline above 0.6 is unknown.
