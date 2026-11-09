# Verifying camera height and position, container identity, and floor coverage for ShrimpWatch (iPhone 17 without LiDAR, styrofoam box, about 45 cm)

Scope note: "Apple-only" means Vision, AVFoundation, ARKit, CoreMotion and simd. Anything that needs third-party code is marked **[3rd-party]**. Numbers I derived myself rather than took from a source are marked as inferences.

## Q1. Checking camera height and scale at count time (fiducials, scale from larvae, sensors, mechanical rigs)

### Takeaway
Two checks are strongest and need no friction beyond a one-time sticker. The first is a permanently fixed, known-size, high-contrast marker: a QR code read with Vision, or a printed black square read with VNDetectRectanglesRequest, measured with the pinhole model and the per-frame intrinsic matrix. The second is a rig or stand that physically sets the height. Scale estimated from the larvae themselves works as a soft secondary sanity check but cannot be a hard gate. ARKit without LiDAR, lensPosition and CoreMotion cannot measure height on a plain white floor under water. CoreMotion is still useful for tilt.

### Cited Findings
**Marker-based distance accuracy**
- AprilTag with the camera aimed at the tag center: mean absolute distance (depth) errors of about 0.26 cm at 30 cm, 0.63 cm at 50 cm and 0.48 cm at 70 cm. Lateral errors were about 0.09, 1.52 and 1.79 cm. The paper reports overall averages of about 0.40 cm for distance and 1.0 cm lateral. **[AprilTag = 3rd-party]** — [Abbas et al., "Analysis and Improvements in AprilTag Based State Estimation", Sensors 2019, PMC6960891](https://pmc.ncbi.nlm.nih.gov/articles/PMC6960891/)
- The same study names yaw/viewing-angle misalignment as the dominant error source: accuracy is best when the camera points at the tag center. Off-axis lateral spreads reached about 12–14 cm at 70 cm before correction. The paper gives no error-versus-tag-size data. — [PMC6960891](https://pmc.ncbi.nlm.nih.gov/articles/PMC6960891/)
- In general, marker pose accuracy falls as distance grows for a given tag size, and small tags stop being detected at longer range. Example from a UAS study: 2σ height error 0.32 m at 4 m, below 0.1 m near touchdown. — [arXiv 1908.06381](https://arxiv.org/pdf/1908.06381)
- Underwater AprilTag detection accuracy fell roughly linearly with distance, and underwater calibration could compensate. — [IROS 2023 entry (unpaywall)](https://unpaywall.org/10.1109%2FIROS55552.2023.10341764) (snippet only; full text not read)
- ArUco localization accuracy versus marker count, orientation and distance has been studied experimentally. I read only the abstract, so I have no numbers. **[ArUco = OpenCV, 3rd-party]** — [arXiv 2509.17345](https://arxiv.org/pdf/2509.17345v3)

**Apple-only marker building blocks**
- Vision barcode observations expose corner points (topLeft, bottomLeft, ...) in normalized coordinates with a bottom-left origin. Apple's WWDC21 sample draws the QR quadrilateral from them. — [WWDC21 10041](https://developer.apple.com/videos/play/wwdc2021/10041/)
- A developer reports that Vision's QR topLeft/topRight/bottomLeft corners appear to match the finder-pattern corners. Apple has not confirmed this in documentation. — [Apple Developer Forums thread 773735](https://developer.apple.com/forums/thread/773735)
- Vision does not return distance. The usual approach combines the corners, the code's known physical size and the camera intrinsics, then solves pose (often with OpenCV solvePnP **[3rd-party]**). — [Stack Overflow answer (archive)](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/44579839/ios-revert-camera-projection)
- Core Image's CIQRCodeFeature also gives the QR's image-coordinate corners and is Apple-only. — [Apple docs CIQRCodeFeature](https://developer.apple.com/documentation/coreimage/ciqrcodefeature.md)
- Setting `isCameraIntrinsicMatrixDeliveryEnabled` on a video connection (before `startRunning()`) makes each AVCaptureVideoDataOutput sample buffer carry a `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` attachment, which gives the focal length in pixels for the pinhole formula. — [Apple docs](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled)
- AVCameraCalibrationData carries the pixel focal length, principal point and distortion. Its values are relative to `intrinsicMatrixReferenceDimensions` and must be rescaled if the image size differs. One developer got 3.5 cm instead of 8.5 cm by skipping that step. — [Apple docs AVCameraCalibrationData](https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata); [Apple forum 705386](https://developer.apple.com/forums/thread/705386)
- ARKit image tracking (ARReferenceImage + ARImageAnchor) gives the 6-DoF pose of a known printed image. ARKit "needs to know the image's physical size" to determine position and orientation accurately. `estimatedScaleFactor` reports how far the observed scale differs from the declared size. Apple publishes no mm-accuracy figure. — [Apple docs ARReferenceImage.physicalSize](https://developer.apple.com/documentation/arkit/arreferenceimage/physicalsize); [ARImageAnchor](https://developer.apple.com/documentation/arkit/arimageanchor)
- A developer forum thread reports missed ARKit image detections that correct physical size did not fix. This is anecdotal. — [Apple forum 685469](https://developer.apple.com/forums/thread/685469)

**Sensors without LiDAR**
- Without a depth sensor, ARKit relies on "discernible, relatively high contrast features". Plain white or solid-colour surfaces yield few or no feature points. — [Kin + Carta, Medium](https://medium.com/kinandcartacreated/augmenting-the-workplace-with-arkit-f65c1f50b67a); [Stack Overflow (archive)](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/57375040/to-implement-ar-with-plain-white-walls-floors)
- A CurvSurf engineer on Apple's forums calls non-LiDAR rawFeaturePoints "relatively inaccurate, unreliable, and unstable". — [Apple Developer Forums (CurvSurf)](https://origin-devforums.apple.com/forums/profile/CurvSurf/replies?page=2)
- Apple says LiDAR mesh raycasts can hit "surfaces with little or no features, like white walls". That capability is missing on a non-LiDAR iPhone. — [Apple docs: Visualizing and interacting with a reconstructed scene](https://developer.apple.com/documentation/arkit/visualizing-and-interacting-with-a-reconstructed-scene)
- `lensPosition` "doesn't correspond to an exact physical distance, nor does it represent a consistent focus distance from device to device". Its range is 0.0–1.0, and 1.0 is not infinity. It can only be set with `setFocusModeLocked(lensPosition:)`. — [Apple docs lensPosition](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lensposition)
- Apple exposes `minimumFocusDistance` (mm) but no API that maps lens position to distance. — [WWDC21 10047](https://developer.apple.com/videos/play/wwdc2021/10047/)

**How counting systems handle height**
- Bukas et al. (2024) counted shrimp in a commercial RAS from an iPhone 11 mini held at "a distance". Training categories were 80 cm and 120 cm. Users follow "provided guidelines when taking images (height, angle, image in focus)" rather than a rig. — [Bukas et al., J. Cleaner Production 468:143024 (2024)](https://doi.org/10.1016/j.jclepro.2024.143024)
- In the same paper's independent test, error grew with height. YOLOv5m6 MAPE was 7.39% at 100 cm, 10.44% at 125 cm and 16.94% at 185 cm. Faster R-CNN was 7.33%, 20.12% and 29.98%. The authors attribute part of this to height and density outside the training range, and recommend 50–100 cm lens-to-water distance. — [Bukas et al. 2024](https://doi.org/10.1016/j.jclepro.2024.143024)
- XpertSea photographs animals "in a predefined volume against a white background", so its geometry is fixed by the device. — [Bukas et al. 2024 (discussion)](https://doi.org/10.1016/j.jclepro.2024.143024)
- XpertCount is a closed "magic bucket" of about 5 gallons ($5,000) that counts and sizes larvae by machine vision and claims 95%+ accuracy. Its camera geometry is internal and fixed. — [Global Seafood Alliance Advocate](https://www.globalseafood.org/advocate/one-fish-two-fish-fish-counting-tech-nets-funding-for-canadian-engineering-firm/); [The Fish Site](https://thefishsite.com/articles/xpertsea-innovative-aquatic-organism-counter-hits-international-market-in-fall-2015)
- Smartphone larvae counters in the literature: Li et al. 2023 (*Animals* 13:2036, P. monodon keypoint counting, "needs only a smartphone", WeChat applet) and Shrimpseed_Net (*IEEE Access* 2023, CSRNet density map on a phone). Rothschild et al. (2023) used an iPhone 11 at 3024×4032 but did not report camera height or a stand. — [Li et al., MDPI Animals](https://www.mdpi.com/2076-2615/13/12/2036) (403 on fetch; summary from search snippet); [Shrimpseed_Net record](https://katalog.lib.cas.cz/KNAV/EdsRecord/edsdoj,edsdoj.666bacd55417435085f31df67d9b96c3); [Rothschild et al., arXiv/DeepAI](https://deepai.org/publication/computer-vision-system-to-count-crustacean-larvae)

**Larva size as a scale cue**
- P. vannamei PL12 (control group): total length 10.27 ± 0.52 mm. The "coefficient of variation of population sizes" was 17.51 ± 0.54% (mean ± SD across n = 3 tanks). — [PMC10072957 Table 4](https://pmc.ncbi.nlm.nih.gov/articles/PMC10072957/table/tab4) (figures from the search snippet; the page itself was blocked by a bot check)
- PL size uniformity decreases with age, and length gains are smaller than weight gains. — [Global Seafood Alliance, "What size are your postlarvae?"](https://www.globalseafood.org/advocate/what-size-are-your-postlarvae/)
- PL longer than 9 mm were mostly "good quality" in stress tests. Stocking at ≥9 mm total length is advised, which implies batch mean length varies with hatchery and condition, not only with PL day. — [Global Seafood Alliance, PL quality](https://www.globalseafood.org/advocate/shrimp-postlarvae-quality-part-1/)

### Inferences
- **Scale sensitivity (pinhole):** apparent size ∝ 1/Z. At Z = 45 cm, a 1 cm height error is a 2.2% scale change. The trained band of 44–46 cm is ±2.2%. A height check therefore needs about ±0.5 cm (about ±1.1% scale) resolution, the same as the validated ID-1 card.
- **Marker resolution estimate:** I estimated fx at about 2,900 px for a 4032-px-wide frame, assuming about 69° horizontal FOV on the main wide camera. Read the true fx from the intrinsic matrix. On that assumption, a 50 mm marker at 45 cm spans about 320 px. ±1 px of corner noise is about 0.3%, or about 0.14 cm. That is roughly the AprilTag figure (about 0.5 cm at 50 cm), so a 4–6 cm printed QR or square, measured from its side lengths, should match the card's ±0.5 cm. Averaging all four sides and several frames reduces noise. This assumes the camera is roughly perpendicular. With tilt, use the mean of the side lengths or a homography rather than one edge.
- **Apple-only recipe:** VNDetectBarcodesRequest (QR) gives corners and the payload. Average the four edge lengths in pixels and compute Z = fx · W_mm / w_px using `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix`. No PnP library is needed for a near-nadir camera. For tilt, a 4-point homography can be decomposed with simd, or tilt can be checked separately with CoreMotion. AprilTag/ArUco **[3rd-party]** add little at this range for a fixed, cooperative marker.
- **Marker placement:** put it above the waterline (rim top or upper inner wall), not on the submerged floor. Refraction through the water layer makes submerged objects appear closer and larger. By Snell's law, apparent depth ≈ real/1.33, so the effect changes with water depth. A rim marker sits at a fixed, known offset from the floor, which is calibrated once at registration (card at floor and marker together, store ratio). This is a derived inference; I found no measured study for this case.
- **Larva-length check:** at CV ≈ 17%, the median of N = 200 detections has a standard error of about 1.25 × 17% / √200 ≈ 1.5%. That is statistically tight enough. However, batch mean length can differ by 10%+ between PL ages and hatcheries, and curled or overlapping larvae shrink box sizes. Use it only as a soft warning (for example a median box diagonal more than ±10–15% from the training median), not as the height gate. It is better for catching gross errors such as a wrong zoom lens or a phone held at 30 cm.
- **lensPosition** is not a height signal here. Focus is locked at the card focus, so it reads back the same value at any height. Even with AF re-enabled, Apple states it is not a calibrated distance. At 45 cm a phone's depth of field is several cm, so the AF result is coarse. Repeatability with AF on the same device is untested, and lensPosition would at most be a weak ±several-cm tie-breaker.
- **ARKit world tracking / plane detection** is not reliable for height over a plain white floor under water with a torch (glare, no features, moving water). ARKit image tracking of the rim marker could work, but ARSession takes over the camera (format, focus, exposure), which may conflict with the locked focus/exposure pipeline and the torch. Vision on the existing AVCaptureSession is simpler.
- **CoreMotion** (CMDeviceMotion.gravity) gives tilt from vertical cheaply and continuously. It is the right Apple-only tilt gate (for example ≤3–5°). It cannot measure height.
- **Mechanical rig:** the only method that removes height error rather than detecting it, and the one fixed-geometry commercial counters (XpertCount) use. For hand-held mode, published phone-counting work (Bukas et al.) relies on guidelines plus training across heights. That suggests either a rig, a marker check, or training augmentation over the expected height range.

### Gaps
- No published accuracy for Vision QR- or rectangle-corner-based distance at about 45 cm. The estimate above is my own derivation and needs an on-device test (20 captures at 40/45/50 cm against a ruler).
- No Apple figure for ARImageAnchor pose accuracy. Whether ARKit can run with the torch on and a locked lens position is not confirmed.
- No sourced CoreMotion tilt accuracy figure (I did not fetch Apple's CMAttitude docs).
- PL10-specific within-batch length SD/CV not found. The closest figure is the PL12 CV of about 17.5% from one study, from a snippet only.
- XpertCount's internal camera height and optics are not published.
- Li et al. 2023 and Shrimpseed_Net capture protocols (height control) could not be read (MDPI 403).

## Q2. Checking that it is the same container

### Takeaway
Realistically, attach a machine-readable ID (QR) to each box. Vision decodes it with Apple frameworks only, and the same QR doubles as the scale marker from Q1. Image fingerprints of a plain white ribbed styrofoam box are not distinctive, which matches the project's earlier NCC failure.

### Cited Findings
- VNDetectBarcodesRequest returns the payload string plus corner geometry, so one sticker provides both identity and scale. — [WWDC21 10041](https://developer.apple.com/videos/play/wwdc2021/10041/); [Apple docs CIQRCodeFeature](https://developer.apple.com/documentation/coreimage/ciqrcodefeature.md)
- A benchmark found Apple Vision is a viable on-device iOS barcode reader alongside Dynamsoft, ML Kit and ZXing-CPP. — [Dynamsoft iOS barcode benchmark](https://www.dynamsoft.com/codepool/ios-barcode-scanner-benchmark-app-swiftui.html) (vendor-authored, so possibly biased)
- Feature-poor white surfaces give feature trackers almost nothing to lock onto, so appearance-based identity of a plain white box is weak. — [Stack Overflow (archive)](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/57375040/to-implement-ar-with-plain-white-walls-floors)

### Inferences
- **Recommended: QR sticker per box** (laminated or waterproof, on the rim top or upper wall above the waterline). The payload is a box ID the app stores at registration. Mismatch or absence gives a clear message ("Box B-07 expected, found B-03"). This costs no extra user action because it is read from the same frame used for counting.
- **Fallback when the QR is unreadable (glare, wet):** let the flow finish, flagged "identity unverified", per the user's "must always finish" rule. Don't block.
- Image fingerprints (Vision VNGenerateImageFeaturePrintRequest, NCC) would mostly measure lighting and water state, not box identity. I found no evidence they work on near-identical white boxes, so I don't recommend them.
- Identity alone doesn't prove the box is placed as registered. The QR's position in the frame (centroid, rotation) can additionally confirm the box sits under the camera the same way as at registration.

### Gaps
- No study on QR read rates on wet, laminated labels under a phone torch at 45 cm. Glare from the torch on lamination is a plausible failure mode, and a matte finish is likely better, but this is untested.

## Q3. Checking that the whole floor is in frame

### Takeaway
Detecting rim edges is unreliable on ribbed white styrofoam (the project already found rectangle detection unusable). The robust Apple-only option is a small high-contrast marker at each floor corner, or at two diagonal corners on the rim, and requiring all of them to be detected inside a safe margin of the frame. Widening the view to include the walls helps only if the model was trained on that framing. It also changes the scale per larva, which works against the fixed-scale model.

### Cited Findings
- Vision's rectangle and barcode observations give normalized corner coordinates, so "all markers inside frame by ≥ x% margin" is a direct check. — [WWDC21 10041](https://developer.apple.com/videos/play/wwdc2021/10041/)
- Bukas et al. observed that greater camera height covers a larger tank area, giving more animals per image and higher error. The 120 cm/white category had the most shrimp per image. Framing and scale cannot be changed independently with a fixed lens. — [Bukas et al. 2024](https://doi.org/10.1016/j.jclepro.2024.143024)
- Feature-based methods fail on low-contrast white surfaces, which explains why edge/rectangle finding on a white-on-white styrofoam rim is fragile. — [Kin + Carta, Medium](https://medium.com/kinandcartacreated/augmenting-the-workplace-with-arkit-f65c1f50b67a)

### Inferences
- **Corner markers:** 2–4 printed black squares or mini QR codes on the rim corners. If all are detected and each lies inside the frame with a margin, the floor between them is in frame. The four points also give a homography that reports tilt and rotation, and the distances between markers give a second scale estimate, which cross-checks Q1. One QR with ID (Q2) plus 2–3 plain squares is enough.
- **Including walls:** a wider view (stepping back, or the 0.5× ultra-wide) puts the floor edge visibly inside the frame. However, it shrinks larvae (the scale problem from Q1) and changes the lens (different distortion), so it needs retraining. Don't adopt it unless the model is retrained at that framing.
- **Cheaper partial check without markers:** count detections along the frame borders. Many larvae cut at the image edge suggest the floor extends beyond the frame. This is a heuristic and unvalidated.

### Gaps
- No source evaluates corner-marker framing checks for aquaculture containers. The method rests on general Vision capability plus geometry, and needs on-device testing.
- No data on how the model's count error changes when the box walls enter the frame (wall reflections, larvae on wall slopes).
