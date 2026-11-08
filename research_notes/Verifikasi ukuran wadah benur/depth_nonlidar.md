# Depth and distance measurement on a non-LiDAR iPhone (iPhone 17, wide + ultrawide) for verifying camera height (~55–68 cm) and box floor size (~48×33 cm) on white styrofoam

Research date: 2026-11-07. Hardware context: iPhone 17 (non-Pro), A19, 48MP Fusion Main 26 mm f/1.6 + 48MP Fusion Ultra Wide 13 mm f/2.2 120°, "2x telephoto" listed as a 12MP crop of the main sensor, no LiDAR mentioned in the specs — [Apple iPhone 17 specs](https://www.apple.com/iphone-17/specs/).

## 1. Dual-camera disparity depth (AVDepthData via builtInDualWideCamera)

### Takeaway
Stereo depth (wide + ultrawide) is supported on iPhones (not iPads) and can be detected at runtime. Apple documents dual-camera depth as **disparity with `.relative` accuracy**: "an individual point isn't a good estimate of real-world distance." So it is a weak primary gate for an absolute 55–68 cm check, and it is weakest on exactly our target: smooth, textureless white surfaces.

### Cited Findings
- Apple Media Engineer (June 2024): "We do not support stereo (wide + ultrawide, aka dual wide) depth data delivery on iPads. We do support it on iPhones though." — [Apple Developer Forums 756719](https://developer.apple.com/forums/thread/756719)
- Apple does not publish a per-device depth support matrix. To check, enumerate `device.formats` and look for a non-empty `supportedDepthDataFormats`. If none exist, the device does not support depth. — [Apple Developer Forums 756719](https://developer.apple.com/forums/thread/756719)
- Depth capture only works if you explicitly select a depth-capable virtual device. The default back camera does not enable it. You then set `photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported`, and a later reconfiguration briefly interrupts capture. — [Apple: Capturing photos with depth](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md)
- Apple: "Each point in a depth map captured by a dual camera device measures disparity units of 1/meters, and offers `AVDepthData.Accuracy.relative` accuracy. An individual point isn't a good estimate of real-world distance, but the variation between points is consistent enough to use for depth-based image processing effects." Only TrueDepth is described as `.absolute` (meters). — [Apple: Capturing photos with depth](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md)
- Enabling depth on a dual camera locks the zoom factor of both constituent cameras. — [Apple: Capturing photos with depth](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md)
- iPhone 17 is reported to deliver depth correctly. One developer forum post (in search snippets, not opened) says depth-photo orientation comes out landscape on iPhone 17 and later, while the same code works on iPhone 17 Pro Max (iOS 26.1). This is anecdotal. — search result surfaced via [Apple Developer Forums (depth on iPhone 17)](https://developer.apple.com/forums/thread/724137) *(unverified: the snippet's attribution to this thread is unclear)*
- Textureless surfaces are a known failure mode for dual-camera depth. Patents say accuracy drops on smooth, low-texture surfaces and that stereo depth is unreliable without reference texture. — [USPTO 11494925](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11494925); [USPTO 11025814](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11025814)
- Research on dual-camera plus dual-pixel depth (Google, 2020, older) also says it does not work on textureless regions and suggests active sensors. — [Du²Net, arXiv 2003.14299](https://arxiv.org/pdf/2003.14299)
- One developer reported noisier builtInDualWideCamera raw depth on iOS 16 than iOS 15 (old, anecdotal). — [Stack Overflow mirror](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/74033725/ios-16-has-more-noise-in-stream-of-raw-depth-values)

### Inferences
- `.relative` accuracy means the calibration (absolute offset/scale) of disparity is not guaranteed. A median of disparity over the box floor could still serve as a *coarse* sanity check, provided it is calibrated once per device against a tape measure. It should not be the primary distance gate.
- The ribbed styrofoam may supply enough texture for stereo matching on the ribs, but a flat white floor under diffuse light probably will not. Expect holes or heavily filtered (interpolated) values there. Use `isDepthDataFiltered = false` and count invalid pixels to find out.
- The wide–ultrawide baseline is only ~1 cm (not found in sources, see Gaps). Disparity resolution therefore gets coarse quickly with distance, though 0.5–0.7 m is within the range Portrait mode is designed for.

### Gaps
- No Apple or peer-reviewed figure for builtInDualWideCamera depth accuracy (absolute error, noise, min/max range) at 30–100 cm. The same is true for depth-map resolution on iPhone 17. Typical depth maps are low-resolution (on the order of hundreds of px wide), but I found no iPhone 17 figure. Query `supportedDepthDataFormats` on the device.
- No source found for the physical wide↔ultrawide baseline on iPhone 17.
- Not verified whether `AVCaptureDepthDataOutput` (streaming/video depth) is offered for builtInDualWideCamera on iPhone 17, or only photo depth. Check at runtime via `activeFormat.supportedDepthDataFormats`.
- No study of iPhone stereo depth on white styrofoam or similar textureless materials.

## 2. Focus distance (lensPosition / minimumFocusDistance / Cinematic)

### Takeaway
`lensPosition` is a unitless 0–1 value. Apple says explicitly that it does not correspond to a physical distance and is not consistent from device to device. It only works as a distance proxy after per-device, per-lens empirical calibration, so it is not reliable for a ±5 cm gate.

### Cited Findings
- Apple: a lens position value does not correspond to an exact physical distance and is not a consistent focus distance across devices. The range is 0.0 (closest focus) to 1.0 (furthest), and 1.0 is not infinity. — [Apple: lensPosition](https://developer.apple.com/tutorials/data/documentation/avfoundation/avcapturedevice/lensposition.md) (via search summary); [Apple: Capture device focus](https://developer.apple.com/documentation/avfoundation/capture-device-focus.md)
- `minimumFocusDistance` is the only focus property in physical units (millimeters). — [Apple: Capture device focus](https://developer.apple.com/documentation/avfoundation/capture-device-focus.md)
- Developers calibrate empirically. On an iPhone 13, infinity focus was at lensPosition ≈0.808 (wide/tele) and ≈0.84 (ultrawide), and users asked whether the optimum drifts over time. — [Apple Developer Forums 706755](https://developer.apple.com/forums/thread/706755)
- A Stack Overflow answer (old) calls lensPosition "just some arbitrary value" and calibrated it with ARKit. — [SO mirror](https://kaweah.freedombox.rocks/kiwix/stackoverflow.com_en_all_2023-11/questions/51405903/accurate-and-current-fieldofview-of-avcapturedevice)
- Thin-lens math (1/d = 1/f − 1/p) needs a physical lens-to-sensor distance, which the 0–1 value does not provide. — [Justia patent 8803987](https://patents.justia.com/patent/8803987)
- iPhone 17 supports Cinematic mode video up to 4K30. — [Apple iPhone 17 specs](https://www.apple.com/iphone-17/specs/)

### Inferences
- Even with a calibrated map, the depth of field at f/1.6 and ~60 cm, plus autofocus hunting on a white low-contrast floor, would likely blur a 55 vs 68 cm distinction. Lens position also changes with temperature and orientation (gravity on the voice-coil). Use it at most as a weak corroborating signal.

### Gaps
- No published accuracy for lensPosition→distance mapping on any iPhone.
- I did not verify Apple's newer Cinematic Video capture API (iOS 26) or whether it exposes metric disparity to third-party apps. Cinematic depth is presumably the same stereo/ML disparity and inherits section 1's limits.

## 3. Monocular depth models via Core ML (Depth Anything V2, Depth Pro)

### Takeaway
Apple's Core ML gallery ships only **Depth Anything V2 Small**. It is fast (~26–34 ms on recent iPhones) but outputs **relative** depth, so it cannot verify 55–68 cm by itself. **Depth Pro** claims metric depth with no intrinsics, but Apple publishes no official Core ML build and it is far heavier (0.3 s for 2.25 MP on a GPU). Neither has published accuracy at ~0.5 m on textureless close-range scenes.

### Cited Findings
- Apple's Core ML models page lists Depth Anything V2 as the only depth model: `DepthAnythingV2SmallF16.mlpackage` (49.8 MB) and a 6-bit palettized variant (19 MB), 24.8M params. Latency: iPhone 16 Pro 26.21 ms, iPhone 15 Pro Max 33.90 ms. Depth Pro is not listed. — [Apple Core ML Models](https://developer.apple.com/machine-learning/models/)
- Apple's HF model card: evaluated at a fixed 518×396 input. Latency is ~31 ms on iPhone 12 Pro Max (Neural Engine). The abs-rel error (0.0072 F32 / 0.0089 F16) is *vs. the PyTorch reference*, not vs. ground truth. — [HF apple/coreml-depth-anything-v2-small](https://huggingface.co/apple/coreml-depth-anything-v2-small)
- The Depth Anything V2 base models are for "robust **relative** depth estimation." Separate fine-tuned **metric** models (Small/Base) exist in the repo's `metric_depth` folder, but are not in Apple's Core ML gallery. — [GitHub Depth-Anything-V2](https://github.com/DepthAnything/Depth-Anything-V2)
- Depth Pro (Apple ML Research, 2024): "predictions are metric, with absolute scale, without relying on the availability of metadata such as camera intrinsics". It also estimates focal length and produces a "2.25-megapixel depth map in 0.3 seconds on a standard GPU" (GPU unnamed). — [arXiv 2410.02073](https://arxiv.org/abs/2410.02073); [Apple ML Research: Depth Pro](https://machinelearning.apple.com/research/depth-pro)
- The only Core ML Depth Pro found is a community 512×512 conversion split into 4 packages. It self-reports <1.0 s/frame on M2/M3 Macs, with no iPhone figure. — [HF aarondevstack/DepthPro-512x512-coreml](https://huggingface.co/aarondevstack/DepthPro-512x512-coreml/blob/main/README.md)
- Smartphone study (iPhone 13 Pro, white door in a white corridor, i.e. low-texture), unspecified "CoreML" RGB-only depth model: central absolute error 1.66 cm at 1 m, 6.22 cm at 2 m, 5.18 cm at 3 m. Peripheral errors were large (~±41 cm average). No distances under 1 m were tested. — [PMC10939328](https://pmc.ncbi.nlm.nih.gov/articles/PMC10939328/)

### Inferences
- Relative depth from Depth Anything V2 is still useful *within* a frame. It can check that the floor is planar and the phone is level (floor-depth gradient), and that the rim sits above the floor. It needs one metric anchor (e.g. the known rim size, section 5) to become metric.
- Depth Pro is general-purpose metric and trained on natural scenes. A close-up top-down view of a white box is out-of-distribution, so expect several-percent-to-10%+ scale error. That is too loose for a 55 vs 68 cm (≈±10%) gate, unless validated on the user's own setup. It would also add a large, non-gallery model.

### Gaps
- No Apple-published A19 latency for Depth Anything V2 (only A17 Pro/A18 Pro figures). A19 should be similar or faster.
- No metric-accuracy figures for Depth Pro or DA-V2-metric at 0.3–1 m indoor top-down views.

## 4. ARKit world tracking on non-LiDAR (camera height above a plane)

### Takeaway
ARKit visual-inertial odometry gives metric scale on non-LiDAR iPhones, but I found **no peer-reviewed cm-level figures for non-LiDAR plane/height accuracy**. Plane detection needs feature texture. A white styrofoam floor is a poor plane target, and non-Pro phones reportedly need more distance to detect a plane. The table or ground *around* the box is the better plane to detect.

### Cited Findings
- Developer report: on a non-Pro iPhone 15 (no LiDAR), detecting a tabletop plane needed ~15–16 in (38–41 cm) of distance, vs 8–10 in on an iPhone 8 (anecdotal). — [Apple Developer Forums 775198](https://developer.apple.com/forums/thread/775198)
- Vendor opinion: non-LiDAR feature points are "relatively inaccurate, unreliable, and unstable", while LiDAR makes plane detection stable. This is not a measurement. — [CurvSurf replies, Apple Developer Forums](https://origin-devforums.apple.com/forums/profile/CurvSurf/replies?page=2)
- A developer thread reports world-tracking drift on LiDAR devices (14 Pro/16 Pro) with iOS 26.4+, but not on non-LiDAR 14/15. — [Apple Developer Forums 827240](https://developer.apple.com/forums/thread/827240)
- ARKit face-distance study (TrueDepth front camera, 200–600 mm, robot arm): error 0.88%–9.07% depending on head pose. Accuracy depends on device model, temperature, and position. This is not a rear non-LiDAR test. — [Sensors 2023, 23(9):4486](https://www.mdpi.com/1424-8220/23/9/4486)
- iPhone 13 Pro study: ARKit_back (LiDAR + VIO) central error 1.37 cm at 1 m. Non-LiDAR iPhones were not tested. — [PMC10939328](https://pmc.ncbi.nlm.nih.gov/articles/PMC10939328/)
- Non-peer-reviewed 2026 app comparison: all AR measure apps were within ±5 mm of a laser for spans <1 m. Camera-only depth drifted to ±50 mm on longer spans. — [measuretape.app blog](https://measuretape.app/en/blog/best-ar-measure-apps-iphone-2026/)
- LiDAR-only reference figures (for contrast): iPhone 12 Pro ~±1 cm for objects >10 cm. — [Sci Rep 2021](https://www.nature.com/articles/s41598-021-01763-9)

### Inferences
- A workable ARKit flow: detect the horizontal plane of the table/floor the box stands on (textured surroundings), and read the camera height from `camera.transform` relative to that plane. Height above the box floor = height above table − box wall/base thickness. This needs the user to sweep the phone briefly and the surroundings to be in view. Expect roughly 1–3 cm error at <1 m, but that is an extrapolation without a non-LiDAR source.
- ARKit also provides per-frame `ARCamera.intrinsics`, which is useful for section 5.

### Gaps
- No controlled study of non-LiDAR ARKit plane-height or distance error at 0.3–1 m.
- Unknown whether ARKit will place a plane on the white styrofoam floor at all, and how stable it is.

## 5. Known-size object scale (pinhole model with intrinsics)

### Takeaway
Using intrinsics plus the box's known dimensions gives distance as Z = f_px·W/w_px. Pixel geometry is very precise at 60 cm, so the real limits are edge detection on white-on-white styrofoam, tilt, and box manufacturing tolerance. There is one key caveat: **you cannot use the floor's known size both to compute distance and to verify that same size**. One dimension must be the metric anchor (e.g. the rim) and another the thing being verified.

### Cited Findings
- `isCameraIntrinsicMatrixDeliveryEnabled` makes each video sample buffer carry `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix`. It must be set before `startRunning()`, and only if `isCameraIntrinsicMatrixDeliverySupported`. Available iOS 11+. — [Apple: isCameraIntrinsicMatrixDeliveryEnabled](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled.md)
- Depth captures also carry calibration metadata (depth data and "depth-related metadata" embedded in photos). — [Apple: Capturing photos with depth](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md)
- Main camera 26 mm equivalent; ultrawide 13 mm / 120°. — [Apple iPhone 17 specs](https://www.apple.com/iphone-17/specs/)

### Inferences (my calculations, not sourced)
- 26 mm equivalent on a 4:3 frame gives HFOV ≈ 67°, VFOV ≈ 53°. At 60 cm the frame covers ≈ 80 × 60 cm, so a 48 × 33 cm floor (plus rim) fits on the main camera, with little margin at the 55 cm low end. f_px ≈ 3000 px at 4032 px width. 48 cm at 60 cm ≈ 2400 px.
- Error propagation: δZ/Z ≈ δw/w. A 10 px edge error on 2400 px is 0.4%, about 2.5 mm at 60 cm. A 1 cm box tolerance on 48 cm is 2%, about 1.2 cm. Pixel quantization is negligible. Edge localization and box variance dominate.
- Tilt: use all four corners and solve a homography/PnP (with intrinsics) instead of a single width. This removes tilt and gives full camera pose (height + angle) from one frame.
- Making size verification non-circular:
  (a) Anchor on the **rim/outer top** (known spec) to get rim distance, then measure the floor with Z_floor = Z_rim + box depth (spec). Compare the floor's measured metric size to 48 × 33.
  (b) Anchor on an independent metric source (ARKit VIO height, section 4) and measure floor size from pixels.
  (c) Since rim and floor are both rectangles at different depths, their pixel-size ratio = Z_floor / Z_rim. With known box depth this gives both distances, using only one known size.
- Prior project memory says rectangle detection fails on this ribbed white styrofoam tray. Rim and floor corner detection is therefore the riskiest dependency. The method is only as robust as corner/edge extraction (consider fitting lines to rim edges against the darker background, which has more contrast than the floor's inner edges).
- Lens distortion: the main camera is low-distortion after ISP correction. Avoid the ultrawide for metric geometry unless you apply its distortion model.

### Gaps
- No published accuracy study for pinhole known-size distance on iPhone. The estimates above are first-principles.
- Not verified whether `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` reflects the post-crop/stabilization frame on iPhone 17 at all presets. Disable video stabilization for metric work.

## 6. Overall: most robust approach for white styrofoam and realistic accuracy

### Takeaway
For a white, low-texture box at 55–68 cm with no LiDAR, the most robust absolute signal is **geometry from known box dimensions plus camera intrinsics (pinhole/PnP)**. Realistic accuracy is ~1–2 cm distance error if the rim corners are found reliably. The independent cross-check is **ARKit VIO height above the surrounding table plane** (likely a few cm, not documented). Stereo disparity, focus position, and monocular ML depth are relative or uncalibrated. Use them only as secondary sanity or levelness checks.

### Cited Findings
- Dual-camera depth is relative-accuracy only. — [Apple: Capturing photos with depth](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md)
- lensPosition has no physical meaning across devices. — [Apple: Capture device focus](https://developer.apple.com/documentation/avfoundation/capture-device-focus.md)
- The Core ML gallery depth model (DA-V2) is relative. — [GitHub Depth-Anything-V2](https://github.com/DepthAnything/Depth-Anything-V2); [Apple Core ML Models](https://developer.apple.com/machine-learning/models/)
- A Core ML RGB depth model was ~1.7 cm off at 1 m centrally on a low-texture white scene, with large peripheral errors (iPhone 13 Pro). — [PMC10939328](https://pmc.ncbi.nlm.nih.gov/articles/PMC10939328/)
- Stereo depth degrades on textureless surfaces. — [USPTO 11494925](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11494925)

### Inferences
- Ranked for this use case:
  1. Pinhole/PnP from rim corners plus intrinsics (absolute, single frame, ~mm–cm). Weakness: corner detection on white.
  2. ARKit height over the table plane (absolute via IMU scale, needs a sweep and textured surroundings).
  3. Dual-wide disparity median (per-device calibrated, coarse).
  4. Depth Anything V2 (relative: planarity and levelness only).
  5. lensPosition (weak corroboration).
- A gate tolerance of 55–68 cm (±~6%) is comfortably within approaches 1 and 2. Floor-area verification to ±1 cm per side needs approach 1 with a non-circular anchor (rim or ARKit).
- Keep thresholds tunable and calibrate once on a real box with a tape measure. The user wants few, tunable gates.

### Gaps
- No direct empirical data on any of these methods with white styrofoam at 50–70 cm. A small on-device test (10–20 captures at measured heights) would settle the choice.
