# UX and trust patterns for verifying container size and camera position (low-effort, mobile)

Researched 2026-11-07. Dates are shown on each source where known. Sources from before 2024 are marked **[older]**. Most capture-UX "evidence" comes from vendors, not independent studies, and this is flagged where it applies.

## 1. Guided capture UX (live feedback, auto-capture, one instruction at a time, haptics): effect on success rates

### Takeaway
Every major capture SDK (KYC, check deposit, document scanning) has standardised on the same loop: real-time quality checks, coaching prompts, auto-capture when the checks pass, and manual capture as a fallback. Vendors report clearly higher first-try pass and acceptance rates from this loop. No independent, controlled published study quantifies the lift, so the numbers below are directional.

### Cited Findings
- Smile ID (KYC vendor) says that, across millions of captures, auto-captured documents have "significantly higher pass rates" than manual captures, especially on mid-range phones. It attributes this to blur from tap delay and hand movement. Its design uses an auto-capture window of about 10 seconds, then falls back to manual capture. Poor lighting and cluttered backgrounds lower success for both modes. The page 404'd on direct fetch on 2026-11-07, so this content comes from the search index. — [Smile ID docs (legacy)](https://legacy-docs.usesmileid.com/further-reading/faqs/document-autocapture); [Smile ID docs](https://docs.usesmileid.com/further-reading/faqs/document-autocapture)
- HID Global's IDV SDK has an optional "Dynamic Capture Feedback" mode that coaches users to fix the device position or the environment. With it on, auto-capture requires a stable device, an in-focus document and correct framing in the viewfinder. With it off, auto-capture "may time out and transition to manual capture". — [HID Doc Scan SDK capture modes](https://docs.hidglobal.com/idv/docs/mobile-sdk-android/doc-scan-sdk-android-capturemodes.htm)
- Onfido reports that real-time image-quality detection meant fewer verifications failed on ID image quality and more people passed on the first attempt, which improved conversion. It also hides the submit button when an issue is detected. It gives no percentages. **[older, Nov 2022]** — [Onfido tech blog](https://medium.com/onfido-tech/helping-people-verify-their-identity-first-time-bc27587907b) (summary from search; the page returned 403 on fetch); [Onfido Android SDK](https://github.com/onfido/onfido-android-sdk/blob/11.1.0/)
- Mitek (mobile check deposit, MiSnap) says it checks image quality in real time and tells users what to adjust. A Mitek executive claims MiSnap images get a 35% higher acceptance rate, but the comparison baseline is not stated. A Mitek-sponsored survey found 19 of 20 institutions offer auto-capture, which "snaps the picture when it deems the image size, lighting and other criteria are correct". — [Mitek blog](https://www.miteksystems.com/blog/misnap-fraud-hides-behind-poor-images); [Mitek mobile capture](https://miteksystems.com/mobile-capture); [Digital Transactions on the Mitek-sponsored study](https://www.digitaltransactions.net/despite-increasing-adoption-theres-room-for-improvement-in-mobile-deposits-study-finds/)
- The same mobile-deposit survey found that a lingering pain point is users not being sure whether a deposit went through. This argues for a clear, persistent confirmation state after capture. — [Digital Transactions](https://www.digitaltransactions.net/despite-increasing-adoption-theres-room-for-improvement-in-mobile-deposits-study-finds/)
- A patent on automatic image capture argues that on-device real-time feedback "reduces user frustration" and avoids round-trip rejections from a back end. **[older]** — [USPTO 9307206](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9307206)
- Google ML Kit Document Scanner (Android) provides automatic capture with document detection, edge detection for cropping, automatic rotation and an on-device flow in a fixed, consistent UI. Developers can limit the page count and toggle gallery import, but cannot tune the coaching prompts. — [ML Kit document scanner](https://developers.google.com/ml-kit/vision/doc-scanner)
- Apple VisionKit's `VNDocumentCameraViewController` (iOS 13+) is a full-screen scanner with auto-capture and perspective correction. Its only API surface is a delegate and an `isSupported` check, with no configuration options. Custom flows use Vision's `VNDetectRectanglesRequest`, which exposes tunable aspect ratio, quadrature tolerance and minimum size. — [Apple VNDocumentCameraViewController](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller.md); [Apple VNDetectRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest.md); [Fatbobman write-up](https://fatbobman.com/en/posts/docscaner/)
- Apple HIG on haptics:
  - Prefer short haptics tied to discrete events.
  - Build a clear causal link between each haptic and the action that triggers it.
  - Make haptics optional, so the app still works without them.
  - Ensure vibrations "don't disrupt experiences involving device features like the camera, gyroscope, or microphone".
  - Use the predefined notification, impact and selection generators.

  — [Apple HIG: Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics.md)

### Inferences
- For ShrimpWatch, use the industry-standard loop: live checks, one coaching line at a time in Indonesian (e.g. "Dekatkan HP", "Tahan HP diam", "Cahaya terlalu gelap"), auto-capture when every check holds for N frames, and manual capture after a timeout of about 10 s.
- The vendors mostly attribute the gain to removing tap blur. That matters even more outdoors in glare and with wet hands.
- Play one success haptic (notification `.success`) at the moment of capture, not continuous buzzing while aiming. Apple warns that vibration can disturb the camera and IMU, which the pose and stability checks rely on.
- Ready-made document scanners (VisionKit, ML Kit) assume a flat, high-contrast rectangle. Per the project's own finding that a ribbed white styrofoam tray has no reliable rectangle, they are not a fit as-is. The UX pattern transfers, but the detector must be custom.

### Gaps
- No independent or peer-reviewed A/B data quantifies the success-rate lift of auto-capture or live feedback. All figures are vendor-reported (Smile ID, Mitek, Onfido).
- No public evidence was found on whether a single instruction at a time beats multiple simultaneous prompts. It is common vendor practice, but I found no study.
- No studies were found on capture UX for low-literacy users in Indonesia or Southeast Asia specifically.
- The claim that Google shut down its ARCore "Measure" app in 2021 over accuracy issues appears only in secondary reports and was not verified with Google.

## 2. Strict gating vs. warnings (soft validation)

### Takeaway
The established guidance is to hard-block only rules that can be checked with no false negatives. Anything probabilistic or open-ended should be a warning the user can override, ideally recorded. Preventing errors (constraints, good defaults) beats both.

### Cited Findings
- Baymard defines the terms this way: "Form validations enforce a set of rules and won't allow the user to proceed, while warnings alert the user about possible problems but will allow them to proceed."
- Baymard says to use validators only for rules that can be implemented with no false negatives (required fields, numeric-only inputs, date ranges). Warnings are for open-ended inputs where valid but unusual values exist.
- Baymard recommends combining the two: validators for baseline validity, warnings for likely mistakes.
- Baymard notes mobile users are more prone to input errors, which makes warnings especially valuable on mobile.
- Example: an e-mail validator that rejected "+" locked out real customers.

  **[older, Sept 2014]** — [Baymard: Validations vs Warnings](https://baymard.com/research-articles/validations-vs-warnings)
- Baymard found that 64% of top-100 e-commerce sites had no address warnings. Walmart and Target ask users to confirm a suspicious address and suggest corrections rather than blocking. **[older, 2014]** — [Baymard](https://baymard.com/research-articles/validations-vs-warnings)
- NN/g on preventing slips:
  - Constrain input only where clear rules define the acceptable options.
  - Give reasonable defaults that also teach users which values are plausible.
  - Use forgiving formats.
  - Prefer prevention over error messaging, and communicate errors "gracefully, actionably, and clearly".

  **[older, Aug 2015]** — [NN/g: Preventing User Errors: Avoiding Unconscious Slips](https://www.nngroup.com/articles/slips/)
- NN/g warns that many validation triggers are "too impulsive", showing errors before the user has finished. It says critical errors and warnings should be noticeable. — [NN/g: Hostile error messages](https://www.nngroup.com/articles/hostile-error-messages/)
- Design-system guidance from ServiceTitan Anvil: use an error when the user cannot proceed without resolving it, and a warning for a significant issue that may matter later. REI Cedar: aggressive real-time validation causes more errors and slower completion, so validate on change and then on submit. — [ServiceTitan Anvil: Errors and warnings](https://anvil.servicetitan.com/docs/web/patterns/errors-and-warnings); [REI Cedar: Error handling](https://cedar.rei.com/patterns/error-handling)
- Onfido's capture flow hides submit when a quality issue is detected on the first attempt. This is a hard gate that applies only to machine-detectable image quality. — [Onfido tech blog (via search)](https://medium.com/onfido-tech/helping-people-verify-their-identity-first-time-bc27587907b)
- HID's capture gate is strict while live feedback is on (stable, in focus, framed). Its fallback after a timeout is manual capture, not a dead end. — [HID capture modes](https://docs.hidglobal.com/idv/docs/mobile-sdk-android/doc-scan-sdk-android-capturemodes.htm)

### Inferences
- A gating rule for ShrimpWatch can be built in three tiers:
  1. **Hard block:** physically invalid states such as tray not in frame, camera not facing down, heavy motion blur, or exposure clipped. These are checkable with near-zero false negatives.
  2. **Warning with override:** distance or tilt slightly outside tolerance, reference-photo match borderline, or lighting different from the registered setup. The user can proceed, and the session is stamped as "dengan peringatan" (with a warning).
  3. **Silent log:** all raw metrics, for later audit.

  This matches the user's stated preference for few, tunable gates.
- Never let a warning become a dead end. After repeated failures, offer "Ambil manual" (manual capture) and flag the result rather than block. This mirrors the HID and Smile ID fallbacks.
- Show whether a result was a clean pass or a pass with a warning on the result screen and in any shared report. This answers the "did it go through?" uncertainty seen in mobile-deposit research.

### Gaps
- No study was found that quantifies abandonment from hard gates vs. warnings in capture flows specifically. The Baymard and NN/g evidence comes from form fields.
- No Apple HIG or Material page specific to soft validation of camera capture was found. Only the generic error and haptics guidance above applies.

## 3. How field data-collection apps (ODK, KoBoToolbox, CommCare) make measurements trustworthy

### Takeaway
Agricultural and health field-data tools rarely try to make one measurement provably correct. They make the process auditable instead, by recording:
- who entered the data (identity)
- when (tamper-resistant timing)
- where (GPS with accuracy)
- what changed and why (change tracking and required reasons)

On top of that they add supervisor review and photo evidence as ordinary fields.

### Cited Findings
- ODK form audit log:
  - Records start, question views, saves, finalisation and errors.
  - `track-changes=true` adds old and new values.
  - `track-changes-reasons=on-form-edit` stops edits to filled forms "without a reason being given".
  - `identify-user=true` requires a non-blank identity before filling or editing.
  - Location tracking takes `location-priority`, `location-min-interval` and `location-max-age`, and adds latitude, longitude and accuracy columns.

  — [ODK Form Audit Log](https://docs.getodk.org/form-audit-log/)
- ODK uses device time only for the form-start timestamp. Later events use elapsed time, so intervals stay reliable even if the user changes the clock. — [ODK Form Audit Log](https://docs.getodk.org/form-audit-log/)
- ODK states the purpose of the audit log as finding unusually fast or slow enumerators, checking whether they were at the correct location, and seeing "when, why and who changed answers", to feed into data validation. It warns that location tracking can invade privacy, notifies users, and logs (but doesn't block) disabling it. — [ODK Form Audit Log](https://docs.getodk.org/form-audit-log/); [ODK XForms client audit log spec](https://getodk.github.io/xforms-spec/#client-audit-logs) (via [mirror](https://scriptagc.wasmer.app/https_getodk_github_io/xforms-spec/client-audit-logs_html))
- KoBoToolbox uses the same audit format, with GPS latitude, longitude and accuracy, username and change reasons. Data managers use it "to verify that data collection activities are happening as planned". — [robotoolbox vignette: audit data](https://dickoa.r-universe.dev/robotoolbox/doc/audit-data.html)
- CommCare:
  - Automatic GPS capture saves location in form metadata, alongside a manual GPS question.
  - Supervisor review uses a `ready_for_supervisor` flag with case sharing, since there is no built-in "send to reviewer" feature.
  - Full copies of submitted forms can be reviewed in web reports.

  — [Dimagi wiki: Workflows enabled by case management](https://dimagi.atlassian.net/wiki/spaces/commcarepublic/pages/3025305640/Workflows+Enabled+by+Case+Management); [Dimagi forum: Supervisor app](https://forum.dimagi.com/t/supervisor-app-in-commcare/6096)
- An ODK deployment that monitored health officials in Punjab used a photo taken at the visit and submitted with the data as presence evidence. — [ODK forum: Punjab monitoring](https://forum.getodk.org/t/punjab-government-monitoring-health-officials-with-odk/851)

### Inferences
- For buyer–seller disputes over larval counts, the minimum evidence bundle per session would be:
  - the capture image(s) actually counted
  - the registered container ID and its registration photo
  - match score and pose metrics at capture
  - device timestamp plus monotonic elapsed time
  - GPS with accuracy (optional, with notice)
  - operator name
  - app and model version
  - any warning overrides, with a reason picker

  This mirrors ODK's identify-user, track-changes-reasons and location columns.
- Make results append-only. Any correction becomes a new record with a reason, which follows ODK's `track-changes-reasons` pattern. A hash of image plus metadata could make the record tamper-evident for disputes. This is my own extrapolation. None of these tools document cryptographic signing.
- Supervisor review can be light: the buyer or hatchery manager views flagged sessions only.

### Gaps
- No ODK, Kobo or CommCare documentation was found on image-based measurement verification. Photos are treated as plain attachments.
- No FAO or fisheries-specific app documentation on evidence or audit trails was found within this search budget.
- No published evidence was found on whether audit logs reduce disputes in aquaculture trade.
- Double data entry was not covered in the sources found.

## 4. Manual tape-measure accuracy by non-experts vs. AR measurement apps

### Takeaway
Tape measures are reliable on simple, well-defined dimensions when a standard procedure is followed. Reliability drops sharply with novices and with ambiguous landmarks.

AR and LiDAR apps on iPhone typically land within about 1 cm (LiDAR, controlled) up to a few inches (consumer AR, informal tests). Accuracy depends on viewing angle and device.

Apps that put a printed marker of known size in the frame reach clinical-grade agreement (ICC ≥ 0.95). There is no peer-reviewed study of Apple's Measure app itself.

### Cited Findings
- **Tape-measure reliability depends on the operator.**
  - Limb circumference: inter-rater ICC ≥ 0.95, except the lower leg (≥ 0.74), "provided that testers followed standardized measurement procedures".
  - Leg length: reliability was poor for novices, and the method is "operator dependent".
  - Scapular position: inter-rater ICC 0.19–0.45 when landmarks depend on palpation.

  **[older]** — [Rehabilitation Practice and Science](https://rps.researchcommons.org/journal/vol33/iss2/2); [Nova Southeastern PT thesis](https://nsuworks.nova.edu/hpd_pt_stuetd/127); [J Phys Ther Sci 2011](https://www.jstage.jst.go.jp/article/jpts/23/6/23_6_851/_article)
- A novice rater achieved within-session intra-rater ICC 0.98–0.99 with a tape measure for ankle dorsiflexion. Repeatability is fine; agreement between people is the weak point. — [PMC3362988](https://pmc.ncbi.nlm.nih.gov/articles/PMC3362988)
- iPhone LiDAR vs. tape on lower-limb circumference and volume showed excellent reliability and accuracy and cut measurement time significantly. — [PMC12190992](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12190992/)
- In forestry, iPhone LiDAR with the SiteScape app had a mean absolute error of 0.64 cm against tape references. — [Croatian Journal of Forest Engineering](https://crojfe.com/crojfe-data/authors/forkuo/)
- SAE 2021 studied bias and repeatability of iOS LiDAR 3D scans against string and tape measurements (abstract only). **[older]** — [SAE 2021-01-0891](https://saemobilus.sae.org/articles/bias-repeatability-measurements-3d-scans-made-using-ios-based-lidar-2021-01-0891)
- An AAPM 2021 ePoster found LiDAR within about ±1 cm, but it could not resolve below 1 cm. **[older, conference abstract]** — [AAPM 2021](https://w4.aapm.org/meetings/2021AM/programInfo/programAbs.php?aid=58217)
- **imitoMeasure** uses a printed adhesive marker of known size placed next to the wound to set scale, used by 12 clinicians trained only through the company's user guide.
  - Validity vs. ruler: ICC 0.97 for length and 0.95 for width.
  - Inter-rater reliability: ICC 0.97–0.99.
  - Minimal detectable change in area between raters: 35%.
  - Curved surfaces reproduced worse.

  — [Do Khac et al., JMIR mHealth uHealth 2021, PMC7943335](https://pmc.ncbi.nlm.nih.gov/articles/PMC7943335)
- Swift Wound (iPhone) was highly reliable and accurate against a digital planimeter, on plastic model wounds only. **[older, 2017]** — [PLOS One, PMC5560698](https://pmc.ncbi.nlm.nih.gov/articles/PMC5560698)
- In informal consumer tests, AR measuring apps were within roughly 2 inches on a large object. Accuracy improved when the camera was square-on, and results varied by a few inches between apps. A careful 6-ft test with Apple Measure matched the tape closely. These are not validation studies. — [iMore](https://www.imore.com/how-do-measurements-ar-iphone); [SlashGear](https://www.slashgear.com/1884872/how-accurate-iphone-measuring-app/); [Lifehacker AU](https://www.lifehacker.com.au/?p=843579)

### Inferences
- Tape input alone by farm workers is weak evidence. Inter-rater error is the documented failure mode, plus the risk of misreading which edge to measure (inner vs. outer rim, ribbed wall). Pairing the tape value with a photo of the tape laid across the container makes it reviewable.
- The strongest pattern in the literature is a known-size reference object in frame (imitoMeasure). A printed card or sticker of fixed size on the tray rim (or a known-size feature of a standard tray) gives scale without trusting tape or AR. It also doubles as a fiducial for camera-pose checks.
- AR or LiDAR (ARKit) measurement is good enough to sanity-check a declared size within about 1–2 cm on LiDAR iPhones. Use it as a cross-check that triggers a warning, not as the only source, especially on non-LiDAR iPhones.

### Gaps
- No peer-reviewed Bland-Altman study of Apple's built-in Measure app or non-LiDAR ARKit measurement against a tape was found.
- No study of completely untrained lay people measuring with a tape (as opposed to novice clinicians) was found.
- Peer-review status of the Slovenian tree-diameter and UK room-dimension LiDAR studies is unconfirmed: [repozitorij.uni-lj.si](https://repozitorij.uni-lj.si/IzpisGradiva.php?id=149253), [room study mirror](https://radiopharmaconnect.srsweb.org/users/489992/articles/1253435-an-investigation-into-the-accuracy-of-lidar-technology-for-in-home-rehabilitation-planning-a-proof-of-concept-study).

## 5. One-time setup registration (calibrate once, verify quickly each session)

### Takeaway
The closest documented industrial pattern is camera tamper or reference-image checking. A reference view is captured once at setup, and every new view is compared against it on edges that stay stable, with tolerances. Mature systems keep separate reference profiles for different lighting (day and night) and need several consecutive failures before alarming, to avoid false positives.

### Cited Findings
- Camera tamper detection runs a pipeline of feature extraction, a reference model, then a decision on the difference. Methods are full-reference, reduced-reference or no-reference. A covered or moved camera shows up as reference edges disappearing. — [arXiv 2310.07886 survey (2023)](https://arxiv.org/pdf/2310.07886)
- Bosch's "reference image check":
  - Compares the current view against a stored reference every 10 s to detect blinding, displacement or loss of illumination.
  - Needs edges that stay consistent across all hours and seasons.
  - Works better with separate day and night reference profiles.
  - Cannot tell which kind of tampering occurred.

  — [Bosch VCA tamper detect white paper](https://cdn.commerce.boschsecurity.com/public/documents/TN_VCA_tamper_detect_WhitePaper_enUS_22996235531.pdf); [Bosch/Keenfinity KB](https://knowledge.keenfinity-group.com/video-systems/article/how-to-configure-bosch-camera-tamper-detection)
- A tamper-detection patent updates the reference edge image by blending in recent images and requires several consecutive suspicious frames before alarming. This reduces false alarms from temporary obstructions. **[older]** — [USPTO 8073261](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8073261)
- Wound-measurement apps with a printed marker show that a one-time physical scale reference plus a quick per-capture detection is workable for non-specialist users trained only through a user guide. — [PMC7943335](https://pmc.ncbi.nlm.nih.gov/articles/PMC7943335)

### Inferences
Proposed flow for ShrimpWatch:

1. **Registration** (once per tray, about 1–2 minutes, with a supervisor if possible):
   - name or number the tray
   - enter its tape size and take a photo with the tape visible
   - run an optional ARKit/LiDAR cross-check (warning only if the difference exceeds tolerance)
   - capture the reference photo(s) at the correct height
   - store everything as a signed "container profile"
2. **Each session** (a few seconds):
   - pick the tray, or detect it via a sticker or QR on the rim
   - the live view matches against the reference on stable features (rim, marker)
   - auto-capture once the pose holds within tolerance

   Hard-block only if the match clearly fails. Otherwise warn and log.
3. **Re-registration:** suggest it, don't force it, when match scores drift over several sessions, mirroring Bosch's consecutive-failure and reference-update logic. Allow two lighting profiles (outdoor and indoor hatchery lamp), as Bosch does for day and night.

A sticker or QR of known size on the tray solves identity, scale and pose in one cheap object. This is extrapolated from the imitoMeasure marker and the tamper-detection reference-edge findings, not from a single source that recommends it.

### Gaps
- No published consumer or industrial UX study was found that measures "calibrate once, verify fast" against per-session full verification for user effort or error rates.
- No source was found on how ribbed or low-texture white surfaces (styrofoam) affect reference-image matching. The Bosch guidance on needing consistent edges suggests they are a weak point. That is an inference.
- Indonesian-language UX copy guidance for low-literacy agricultural users was not researched within this budget.
