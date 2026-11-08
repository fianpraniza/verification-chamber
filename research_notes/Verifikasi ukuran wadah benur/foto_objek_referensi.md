# Photo-based box measurement with an everyday reference object (ID-1 card / A4 / banknote / phone) on iPhone 17

Context: white styrofoam box, spec L 50–56 cm, W 36–38 cm, H 32–36 cm. Target device: iPhone 17 (no LiDAR), SwiftUI, Vision + AVFoundation only. Research date: 2026-11-07. Fetch budget was ~18 calls, and several primary PDFs (MDPI, OpenCV docs, Criminisi PDF) returned 403 or TLS errors, so some points rest on abstracts or search snippets. These are marked.

---

## 1. Accuracy with a coplanar reference, and how error grows when the reference is not in the measured plane

### Takeaway
Few published studies report mm-level error for "card/A4 in the photo" measurement. What exists is small-sample work (foot apps: ~0.18 EU shoe size MAE on n=10; DimensionApp claims ±5 mm) and vendor claims. The dominant error is not pixels. It is the **reference not lying in the measured plane**: scale is inversely proportional to camera distance, so a card on the box bottom used to measure the rim (~34 cm higher) gives errors of **tens of percent**, not millimetres.

### Cited Findings
- A UNIMAS (Malaysia) 2025 final-year project measured feet next to an A4 sheet used as the calibration reference. On 10 samples the MAE was 0.18 EU sizes, 80% exact size matches and 90% within ±0.5 size. Best results came with the phone ~40 cm high, at 90° (top-down), with the foot aligned. No mm/% figure was reported. — [UNIMAS ScholarHub](https://scholarhub.unimas.my/items/681adbcd-4d86-4f66-8d4b-a19973a5bca0/full)
- INESCOP YourFeet (iOS) uses an A4 sheet to convert pixels to real units and only says accuracy is "adequate". This is a vendor claim with no error figure. — [App Store: INESCOP YourFeet](https://apps.apple.com/app/id1464887668)
- A retailer foot-scan guide says the sheet must be standard-size, clean and flat, and that paper bending on carpet affects accuracy. — summarised in search results for [startriteshoes.com/clicknfit](https://startriteshoes.com/clicknfit) / [happylittlesoles.co.uk/sizewise](https://happylittlesoles.co.uk/sizewise) (search-snippet level, page not fetched)
- DimensionApp (Singh & Kumar, arXiv 2016, written as a 2014 project report) is an Android single-view-metrology app that claims "accurate upto +/- 5 mm". The abstract gives no evaluation details. This is an old source. — [arXiv 1609.07597](https://arxiv.org/abs/1609.07597)
- "Body Size Measurement Using a Smartphone" (MDPI Electronics 2021) reports ~95.6% accuracy and cites earlier smartphone body-measurement errors of 9–42 mm. Seen via search snippet only, since the full text returned 403. — [MDPI Electronics 10(11):1338](https://www.mdpi.com/2079-9292/10/11/1338)
- Patents state the coplanarity problem explicitly. If the reference object and the measured points are not in the same plane, the computed distance "becomes inaccurate". Placing the reference in the plane of both measurement points on a 3-D object is "particularly difficult or even impossible". — [US9599458B2](https://patents.google.com/patent/US9599458); [US11908153](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11908153)
- An ocular-measurement patent describes "parallax and scaling errors induced by the distance between the reference object and the object to be measured". The depth-shift scaling error shrinks as the subject moves further from the camera. — [US10201273](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10201273)
- A patent on ancillary objects corrects the depth offset with a scale factor from two planes at different distances, related by similar triangles. — [US11908153](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11908153)
- A study from Hochschule Mittweida found a pinhole-model approach more accurate than a single-camera stereo approach for smartphone measurement. Snippet only. — [repozitorij / search result](https://repozitorij.uni-lj.si/IzpisGradiva.php?id=120061) (attribution in the search summary is uncertain; treat as weak)

### Inferences
These are my own pinhole calculations, not from a cited study.
- Pinhole scale is mm/px ∝ Z (distance to plane). A reference at depth Z_ref used for a feature at depth Z_obj gives a relative error of (Z_ref − Z_obj)/Z_obj.
  - Card on **box bottom**, camera 60 cm above the rim (bottom at ~94 cm): rim dimensions come out **+57% too large**. Even at 1 m above the rim the error is +34%. To get the error under 1% with a 34 cm depth offset, the camera would have to be ~34 m away. **Unusable.**
  - Card on the **floor beside the box**: same problem. The floor is the box-bottom plane, but a top-down photo sees the rim.
  - Card **on the rim plane** (lying on the wall top, or on a stiff board laid across the opening): the error from card thickness (0.76 mm) is ~0.1% at 60 cm, which is negligible.
  - Practical tolerance: every 1 cm the reference sits off the measured plane costs ~1.7% at Z = 60 cm (~0.9 cm on a 56 cm length). The reference must be **flat on the same plane, within a few mm**.
- Pixel-level budget for the coplanar case. iPhone 17 Main is 26 mm-equiv. At 4:3 the horizontal FOV ≈ 1.33·Z, so filling the frame with a 56×38 cm rim plus margin needs Z ≈ 55–60 cm. At 4032 px wide that is ~50 px/cm (~0.2 mm/px).
  - ID-1 card ≈ 430 px long. With 1–2 px corner error, scale error ≈ 0.3–0.7%, or **~2–4 mm on 56 cm**.
  - A4 (297 mm) ≈ 1500 px, so scale error ≈ 0.1–0.2%, or **~1 mm on 56 cm**.
  - Detecting the edges of rough, rounded styrofoam (±1–3 mm) and imperfect top-down angle then dominate.
- Against the spec, width has only a 2 cm window (36–38 cm). A coplanar setup with A4 should give roughly ±3–5 mm total for L and W, which is good enough for pass/fail away from the limits. An ID-1 card gives roughly ±5–8 mm, which is marginal near the 36/38 cm limits. These are rough estimates and need validation against tape-measure ground truth.

### Gaps
- I found no peer-reviewed study that reports mm error for "credit card / A4 coplanar reference" on objects of ~50 cm. Validation on real boxes is needed.
- Wall-top width of the user's styrofoam boxes is unknown. If the wall is <5.4 cm, an ID-1 card cannot lie flat on the rim. A4 (21 cm) cannot either, unless it is laid on a stiff board or the closed lid.

---

## 2. Perspective (homography) correction with a known rectangle, and Apple Vision rectangle/document detectors and their limits

### Takeaway
Four corners of a known rectangle (card or A4) define a plane-to-plane homography. This removes perspective tilt **for that plane only**. Vision gives the corners: `DetectRectanglesRequest` (Swift, iOS 18+) / `VNDetectRectanglesRequest` (iOS 11+) and `VNDetectDocumentSegmentationRequest` (ML, iOS 15+). Apple documents tuning knobs but **no** contrast or minimum-pixel guarantees. Low contrast (white on white) is a known failure mode.

### Cited Findings
- `VNDetectRectanglesRequest` "finds projected rectangular regions", explicitly "like credit cards, business cards, documents, and signs". It returns `VNRectangleObservation` with normalized corners and confidence. Available on iOS 11+. — [Apple: VNDetectRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest.md)
- Tuning properties:
  - `minimumAspectRatio` / `maximumAspectRatio`, defined as shorter/longer side.
  - `quadratureTolerance`, the degrees a corner may deviate from 90°.
  - `minimumSize`, the minimum rectangle size "as a proportion of the smallest dimension" of the image.
  - `minimumConfidence` and `maximumObservations`.

  — [Apple: VNDetectRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest.md)
- Defaults per bindings and secondary docs: minimumAspectRatio 0.5 (range 0–1), quadratureTolerance 30° (range 0–45), maximumObservations 1. Apple's page does not show the defaults. — [docs.rs objc2-vision](https://docs.rs/objc2-vision/latest/aarch64-apple-ios-macabi/src/objc2_vision/generated/VNDetectRectanglesRequest.rs.html); [pub.dev unified_apple_vision](https://pub.dev/documentation/unified_apple_vision/latest/unified_apple_vision/VisionDetectRectanglesRequest-class.html)
- Swift-concurrency version `DetectRectanglesRequest` (struct, iOS 18+). It has the same knobs (`quadratureToleranceDegrees`, `minimumSize`, …), returns `RectangleObservation`, and can `perform(on: CVPixelBuffer / CMSampleBuffer / CGImage)`. — [Apple: DetectRectanglesRequest](https://developer.apple.com/documentation/vision/detectrectanglesrequest.md)
- `VNDetectDocumentSegmentationRequest` (iOS 15+) "detect[s] a document in an image". The result "contains the four corner points of a document's quadrilateral and saliency mask". Results are `[VNRectangleObservation]`, and only Revision1 is listed. — [Apple: VNDetectDocumentSegmentationRequest](https://developer.apple.com/documentation/vision/vndetectdocumentsegmentationrequest.md)
- Low contrast (subject the same colour as the background) is a common cause of Vision detection failure. The suggested mitigation is cropping to a region of interest. Third-party guide. — [lobehub axiom-vision-diag](https://lobehub.com/skills/charleswiltgen-axiom-axiom-vision-diag)
- Developers report the rectangle detector "struggle[s]" with edges even on simple images. Another rectangle detector (OpenMV) worked on high-contrast images but not on low-contrast ones. — [omz forum](https://forum.omz-software.com/post/46992); [OpenMV forum](https://forums.openmv.io/t/non-profit-film-scanner/2029)
- An open-source exploration of Vision rectangle-detection parameters exists. — [GitHub jbadger3/ExploringRectangleDetection](https://www.github.com/jbadger3/ExploringRectangleDetection)
- Background (OpenCV homography, from general knowledge; the OpenCV docs returned 403 so I could not verify them): a homography is a 3×3 matrix from ≥4 point correspondences, no 3 collinear, and it relates two images of the **same plane** (`getPerspectiveTransform` / `findHomography`). — [OpenCV homography tutorial](https://docs.opencv.org/4.x/d9/dab/tutorial_homography.html) (not fetched, 403)

### Inferences
- Pipeline with no third-party code:
  1. `DetectRectanglesRequest` with aspect ratio ~0.63 for ID-1 or ~0.707 for A4, then filter by aspect after rectification.
  2. Compute the homography from the 4 corners to a metric rectangle (85.60×53.98 mm or 210×297 mm). Core Image `CIPerspectiveCorrection` or a hand-written 8×8 DLT solve works (~30 lines with `simd`).
  3. Map the box's rim corners through the same homography and read L and W in mm.

  This is valid only if the rim lies in the reference's plane (see section 1).
- Use the homography's **residual** as a quality gate. The rectified reference should come back at the right aspect ratio, and the 4 corner angles should be near 90°. Reject frames where the detected quad's aspect ratio does not match the known one by >1–2%.
- Set `quadratureToleranceDegrees` low (~10–15°) when the user is asked to shoot top-down. This rejects skewed false positives such as the box rim itself, which is also a rectangle. Expect the **box rim to be detected as a rectangle too**, so filter by size and aspect ratio (box rim 0.64–0.76, ID-1 0.63, A4 0.707). The ID-1 and box aspect ranges overlap, so use size to tell them apart.
- `minimumSize` is relative to the image's short side. A card at ~430 px on a 3024 px short side is ~0.14, so set `minimumSize` ≈ 0.08–0.1.

### Gaps
- Apple documents no minimum pixel size, contrast threshold or accuracy for corner localisation. Sub-pixel accuracy of Vision corners is unknown, so corner refinement (edge fitting) may be needed.
- I found no documentation on whether `VNDetectDocumentSegmentationRequest` finds credit cards (it is trained for documents) or how it handles white-on-white.

---

## 3. Is A4 more accurate than an ID-1 card for a ~50 cm box? Rule of thumb on reference size

### Takeaway
Yes, if it is flat and coplanar. Scale error from corner localisation scales roughly with (target length / reference length). A4 is ~3.5× longer than an ID-1 card, so it cuts that error ~3.5×. But A4 is white (low contrast on styrofoam), bends easily, and is hard to place on a narrow rim.

### Cited Findings
- A patent notes a credit card is a poor reference for objects much smaller than it, and that accuracy degrades when the reference and target differ widely in scale. — [US9696897](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9696897)
- A small reference covers only a few pixels, which makes its measured length inaccurate. — [US12406383](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12406383)
- Coins, credit cards and rulers have all been used as references and "introduce variability". — [Object Size Estimation … ArUco (globalscients)](https://research.globalscients.com/index.php/jeecs/article/download/44/37)
- The A4 sheet must be flat, since bending affects accuracy. — summarised via [startriteshoes.com/clicknfit](https://startriteshoes.com/clicknfit) (snippet)

### Inferences
- Rule of thumb (error propagation): σ_L/L ≈ √2·σ_corner / l_ref,px. Target error grows linearly with L/l_ref. Example: ID-1 → 56 cm is a ×6.5 extrapolation, A4 long side → 56 cm is a ×1.9 extrapolation. Prefer a reference that is ≥ ⅓ of the target length.
- Reference options:
  - **ID-1 card.** Exact standard size, rigid, often coloured, so good contrast on white. Small, so larger extrapolation error.
  - **A4.** Large but white, flexible, and paper sizes vary ±1–2 mm by tolerance.
  - **Indonesian banknote.** Flexible, often creased, size differs by denomination. Not recommended.
  - **The phone itself.** It cannot appear in its own photo. A second phone would work but its size varies by model. Not recommended.
- Privacy: a KTP (Indonesian ID card) is ID-1, but photographing it captures personal data. The UX should ask for "any bank/ATM/e-money card, back side up" and never upload the image.
- Possible hybrid: an ID-1 card for detection robustness (colour contrast) plus a long-baseline mode where the user places the card twice (two photos) or uses two cards. Untested idea.

### Gaps
- I found no source with exact Indonesian banknote dimensions per denomination (2016/2022 series). Not researched further because it is not recommended.
- No measured comparison of A4 vs card accuracy for the same target.

---

## 4. Single-image metrology (Criminisi et al.): height or depth from one image, and whether it is practical on mobile

### Takeaway
Single-view metrology can measure heights (distances between parallel planes) from **one** image. It needs a reference plane's vanishing line, the vertical vanishing point, and **one known reference height** in the vertical direction. A top-down photo of a box gives almost no usable vertical vanishing point, and the method needs a known vertical reference, so it is **impractical for box height from a top-down shot**. An oblique photo with a card standing vertically against the wall would work in principle, but the UX is fragile.

### Cited Findings
- Criminisi, Reid & Zisserman, "Single View Metrology", ICCV 1999 (IJCV 40:123–148, 2000). 3D affine measurements come from a single perspective view, with minimal geometry: the vanishing line of a reference plane and a vanishing point for a direction not parallel to it. No camera calibration or pose is needed. It measures distances between planes parallel to the reference plane, area/length ratios, and camera position. It includes first-order error propagation that gives confidence intervals. These are old but foundational sources. — [Microsoft Research publication page](https://www.microsoft.com/en-us/research/publication/single-view-metrology-4/); [mlanthology ICCV 1999](https://mlanthology.org/iccv/1999/criminisi1999iccv-single)
- Example from the paper: a person's height was measured as 178.8 cm against a true 180 cm (~0.7%), with the person leaning. This is illustrative and not a systematic accuracy study (search-summary level, since the PDF fetch failed). — [PKU-hosted PDF](https://www.graphics.pku.edu.cn/docs/Criminisi99singleViewMetrology.pdf)
- DimensionApp applies single-view-metrology ideas on Android and claims ±5 mm. Old source, no evaluation shown. — [arXiv 1609.07597](https://arxiv.org/abs/1609.07597)

### Inferences
- Top-down view: the vertical direction is nearly parallel to the optical axis, so the vertical vanishing point sits near the image centre and is poorly conditioned. Height cannot be read reliably.
- Alternative "pinhole two-plane" trick for a top-down photo. With intrinsics (focal length in px), the card on the rim gives Z_rim = f·W_card / w_px. A second card on the inner bottom gives Z_bottom, so inner depth = Z_bottom − Z_rim. Error estimate: 1% error in each Z at ~60/94 cm gives about ±1 cm on depth. That is marginal against the 32–36 cm spec, and it needs two cards or two shots and good intrinsics.
- The "vertical walls" trick (ratio of inner-bottom to inner-rim pixel size gives the depth ratio) fails because moulded styrofoam boxes have draft (tapered walls). That is an assumption, since I found no source on the draft angle.
- For height, a **side photo** with the card standing upright against the outer wall, coplanar with that face, is simpler and reuses the same homography code. Alternatively, keep height on ARKit world tracking, as in the existing v1 prototype (ARKit works without LiDAR, at lower accuracy).

### Gaps
- I could not fetch the Criminisi full text for the quantitative experiment tables.
- No source on the accuracy of iPhone-reported intrinsics (focal length in px) for distance-from-card estimation.

---

## 5. Existing apps and projects that measure with a card or A4, and how they build the UX

### Takeaway
Consumer apps (foot sizers, ring sizers) use the same pattern: **known object next to target, top-down, phone parallel, alignment guide, flat surface**. Most publish only marketing accuracy claims. The honest ones say errors of up to about half a size are possible.

### Cited Findings
- Foot apps: A4-reference foot scanning (INESCOP YourFeet; Feet Meter; Start-rite Click'n'Fit; Happy Little Soles SizeWise).
  - UX rules: standard, clean, flat sheet; avoid carpet; stand straight; no socks.
  - The UNIMAS study gives the best capture as 40 cm and 90°.

  — [INESCOP YourFeet](https://apps.apple.com/app/id1464887668); [Feet Meter](https://apps.apple.com/us/app/id1234555375); [startriteshoes.com/clicknfit](https://startriteshoes.com/clicknfit); [happylittlesoles.co.uk/sizewise](https://happylittlesoles.co.uk/sizewise); [UNIMAS](https://scholarhub.unimas.my/items/681adbcd-4d86-4f66-8d4b-a19973a5bca0/full)
- A research paper notes that no foot app tells users how accurate the measurement is relative to true dimensions. — [ProQuest 2748560996](https://www.proquest.com/docview/2748560996) (snippet only)
- Patents on foot measuring and sizing apps describe the reference-sheet method. — [US11805861](https://patents.justia.com/patent/11805861)
- Ring sizers:
  - They calibrate the screen with a bank card (match an on-screen outline, adjust a slider). Then the user measures on screen or photographs the finger or ring next to a card.
  - Changing zoom after calibration breaks the result.
  - One retailer says small differences in how the card or ring is held shift results by up to half a size.
  - Vendor "jeweler-grade" claims are marketing.

  — [Ring Sizer (App Store)](https://apps.apple.com/us/app/-/id6761365066); [SizeMyRing](https://apps.apple.com/app/id6791215499); [Kate & Kole virtual sizer](https://ca.kateandkole.com.au/pages/virtual-ring-sizer); [checkringsize](https://checkringsize.pages.dev/about)
- An older Android "measure anything with A4 paper" app exists. — [AddictiveTips](https://www.addictivetips.com/android/measure-anything-with-an-a4-paper-and-your-android-phone)

### Inferences
Suggested UX for ShrimpWatch, kept to a few tunable gates as the user prefers:
1. **Instruction card:** "Place a bank card FLAT on the box rim (or on the closed lid), coloured side up. Hold the phone level above the box."
2. **Live gates:**
   - card detected (`DetectRectanglesRequest` on video frames)
   - phone tilt under ~5° from `CMMotionManager` gravity (CoreMotion, no deps)
   - whole rim visible
   - card aspect ratio within tolerance
3. **Auto-capture** when all gates hold for ~0.5 s, then show the rectified result with L × W in cm next to the spec range.
4. **Height:** a separate side shot with the card upright on the wall, or ARKit.

### Gaps
- I found no published, independent accuracy validation for any consumer card/A4 measuring app.
- I found no agriculture or aquaculture container-verification app using this method.

---

## 6. Risks: white styrofoam on light backgrounds, iPhone wide/ultra-wide lens distortion, mitigations

### Takeaway
The three main risks:
- **Low contrast:** a white A4 or white rim on white styrofoam and light floors weakens rectangle detection.
- **Ultra-wide distortion:** the 13 mm lens should be avoided. Use the 1× Main camera.
- **Non-coplanarity and tilt:** see section 1.

Use the 1× Main camera, leave Apple's geometric distortion correction on (it is the default), use a coloured card, and use the card's aspect ratio as a self-check.

### Cited Findings
- iPhone 17 rear cameras:
  - Main: 48 MP, 26 mm, ƒ/1.6, sensor-shift OIS.
  - Ultra Wide: 48 MP, 13 mm, ƒ/2.2, 120° FOV.
  - 2× option: 12 MP, 52 mm (crop of Main).
  - No LiDAR listed.

  — [Apple iPhone 17 specs](https://www.apple.com/iphone-17/specs/)
- `AVCaptureDevice` has `isGeometricDistortionCorrectionSupported` / `isGeometricDistortionCorrectionEnabled`. On dual-wide setups correction is on by default for the ultra-wide. Calibration-data delivery was reported unavailable while correction is enabled, so developers disable it to get intrinsics. — [Apple Dev Forums 741815](https://developer.apple.com/forums/thread/741815); [Apple Dev Forums 775111](https://developer.apple.com/forums/thread/775111)
- Delivering `cameraCalibrationData` (with `lensDistortionLookupTable`) requires virtual-device constituent photo delivery and distortion correction off, which is essentially multi-camera virtual devices. One developer could not get the lens-distortion lookup table with a single camera. — [Apple Dev Forums 767505](https://developer.apple.com/forums/thread/767505); [Apple Dev Forums 126798](https://developer.apple.com/forums/thread/126798)
- `AVCaptureConnection.isCameraIntrinsicMatrixDeliveryEnabled` attaches the intrinsic matrix to video sample buffers. It is settable only if supported and before `startRunning()`. — [Apple: isCameraIntrinsicMatrixDeliveryEnabled](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled.md)
- `AVCapturePhotoOutput.isContentAwareDistortionCorrectionEnabled` is a separate photo-pipeline setting that may slightly change FOV compared with the preview. — [Apple: isContentAwareDistortionCorrectionEnabled](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/iscontentawaredistortioncorrectionenabled.md)
- Low-contrast failure of rectangle detection is documented in third-party guides and forums. — [lobehub axiom-vision-diag](https://lobehub.com/skills/charleswiltgen-axiom-axiom-vision-diag); [OpenMV forum](https://forums.openmv.io/t/non-profit-film-scanner/2029)

### Inferences
- Use the **1× Main (26 mm)**, never 0.5×. Residual distortion after Apple's correction is likely sub-pixel to a few px at the frame edges. Keep the box in the central ~80% of the frame and the card near the measured corners. The homography assumes no distortion.
- For L/W with a coplanar reference, **intrinsics are not needed**: the homography absorbs focal length and tilt. Intrinsics are only needed for the distance-from-card (depth or height) tricks.
- Contrast mitigations:
  - a coloured card (bank card) instead of white A4
  - asking the user to put the box on a dark or contrasting surface, or to shoot in even light without a hard flash (hard flash blows out white styrofoam)
  - exposure locked or biased down (white subject), consistent with existing BenurGate experience with styrofoam framing
- Detecting the box rim itself on ribbed white styrofoam may be harder than detecting the card. Earlier BenurGate work already dropped rectangle detection for the ribbed tray. Fallback: **user drags 4 corner handles** on the frozen photo, with magnifier loupe. This removes the detector risk for the box and keeps auto-detection only for the card.
- Tilt: the homography corrects tilt for the reference plane. Tilt still matters when the card and rim are not exactly coplanar (the error grows with tilt × offset). Gate it at ≤5–10°.

### Gaps
- Apple does not document residual distortion after geometric correction on iPhone 17 Main. It needs an empirical test with a printed grid or tape measure.
- Whether iPhone 17 single-camera `AVCapturePhoto` exposes `cameraCalibrationData` on iOS 26/27 is unconfirmed. Forum reports suggest no for single-camera devices.
- No source on how Vision rectangle detection performs on ribbed styrofoam specifically. It needs a test on project photos.
