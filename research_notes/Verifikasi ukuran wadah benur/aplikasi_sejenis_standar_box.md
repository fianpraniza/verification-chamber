# Aplikasi sejenis & standar box: how shrimp-PL counting products handle container/scale, and whether Indonesian styrofoam boxes are standard

Research date: 2026-11-07. Budget-limited pass (~18 tool calls). Several primary sources (MDPI full text, SNI PDF, Telkom PDF) could not be read directly; this is flagged where relevant. Sources are mostly 2013–2025; dates marked.

## Q1. Per product/paper: container/device, how distance/scale is controlled, how setup is verified, accuracy claimed

### Takeaway
The products split into two groups. Dedicated hardware (XpertSea XperCount, SincereAqua, Can Tho optical counter) builds the geometry into the device. Phone apps (SeaThru Counter, PLCS/WeChat, Shrimptector, Bayline, YOLOv5 Indonesian apps) ask for a plain white container and give guidance. No source found describes a phone app that measures or verifies the container's physical size. Claimed accuracy sits around 88–97%, almost always vendor- or author-reported.

### Cited Findings
**XpertSea XperCount (Canada; info 2013–2018, current status unclear)**
- A dedicated tank-style device of about five gallons. The operator pours a sample of larvae into it, and it counts and sizes them with optics/photonics plus machine learning. It saves results to a cloud portal over wireless — [Aquaculture North America](https://www.aquaculturenorthamerica.com/taking-the-guesswork-out-of-inventory-management-2004/); [Global Seafood Alliance ("magic bucket")](https://www.globalseafood.org/advocate/one-fish-two-fish-fish-counting-tech-nets-funding-for-canadian-engineering-firm/)
- 2015 launch claim: counts within 10 seconds, in water volumes up to 10 L, with "up to 95%" accuracy — [The Fish Site, 2015](https://thefishsite.com/articles/xpertsea-innovative-aquatic-organism-counter-hits-international-market-in-fall-2015)
- A 2013 Journal of Xenobiotics paper describes XperCount as an optics-based enumeration device, developed with Aquarium du Québec — [DOAJ record](https://doaj.org/article/9fad87e37225425d89b30121e2b882e0)
- A 2018 article gave a price of about USD 5,000 (likely outdated) — [Hatchery International](https://www.hatcheryinternational.com/counting-on-smart-tech-3191/)
- A low-authority source says the technology later "evolved into a smartphone app". This is unconfirmed — [businessmodelcanvastemplate.com](https://businessmodelcanvastemplate.com/blogs/brief-history/xpertsea-brief-history)
- Scale control: implicit. The device fixes the camera-to-water geometry, so the user never deals with scale (inferred from the device descriptions above).

**SeaThru Counter by Algaeba (Thailand-tagged; article 5 Sep 2023)**
- Hardware clients receive a **white plastic box** for photo capture, and Algaeba "standardised lighting for every image in the box". Subscription (software-only) clients use **their own trays or plastic bowls**, with guidance on **size, colour and water depth**. Photos go through **LINE** to a cloud service (beta since Aug 2023). Recommended practice: shade against direct sun, flash in dim hatcheries — [The Fish Site, 2023](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)
- Accuracy: whiteleg shrimp PL 97% at 2,000 per box. It "may drop slightly" at 3,000–5,000 per box. Count returned in under 10 s. Used in hatcheries in 11 countries — [The Fish Site, 2023](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)
- The article does not mention a stand, camera height or any scale verification — [The Fish Site, 2023](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)

**Larvia (Ecuador; info up to mid-2021)**
- An AI service for counting, individual weight estimation, weight grading, uniformity, pigmentation/health, and geolocation of larvae and juveniles in raceways. Results in under 15 s, versus 3–5 min of manual counting. The output includes images so users can validate detections. AI models in use since 2018; juveniles added by June 2021. Markets: Ecuador, Peru, Mexico, Brazil, US, Nicaragua, Honduras, Saudi Arabia, Thailand — [IDB fAIr LAC](https://fairlac.iadb.org/en/larvia-shrimp-larvae-analysis-app-using-deep-learning)
- The App Store listing (copyright 2020) is for iPad/Mac. No tray is described — [App Store](https://apps.apple.com/ca/app/larvia/id1526163547)
- Capture hardware, and how weight is estimated from pixels (which needs scale), is **not publicly described** — [IDB fAIr LAC](https://fairlac.iadb.org/en/larvia-shrimp-larvae-analysis-app-using-deep-learning)

**PLCS — "Automatic Penaeus monodon Larvae Counting via Equal Keypoint Regression with Smartphones" (MDPI Animals 13(12):2036, 2023)**
- The method "only requires a smartphone to capture images without the need for any additional equipment". Delivered as a WeChat applet: the user takes a photo or picks one from the album — [aquahoy summary](https://aquahoy.com/application-developed-shrimp-larvae-counting-smartphones/); [MDPI](https://www.mdpi.com/2076-2615/13/12/2036)
- In the cloud pipeline, Mask R-CNN first **segments the container** out of the image to remove background interference, and counting runs only inside that region — [search summary of MDPI paper](https://www.mdpi.com/2076-2615/13/12/2036) (full text returned HTTP 403, so this could not be verified first-hand)

**Shrimptector (Telkom University, Indonesia)**
- An Android app. The user photographs benur in a **white container (wadah putih)**, and a deep-learning model counts them before stocking — [Telkom University Open Library PDF](https://openlibrarypublications.telkomuniversity.ac.id/index.php/engineering/article/download/30131/28366/59348) (PDF could not be text-extracted, so container size and camera height are unverified)

**Other Indonesian academic apps**
- A YOLOv5 mobile app for counting shrimp larvae reports an average accuracy of 91.03% — [IT Telkom Surabaya journal](https://journal.ittelkom-sby.ac.id/complete/article/view/647)
- SOPP-Benur CAK (Telkom University Surabaya) combines YOLOv12 counting with digital sales and shows the count to the buyer for transparency — [Telkom Surabaya PDF](https://bce-sby.telkomuniversity.ac.id/wp-content/uploads/2024/12/427-2051-1-PB.pdf)
- A Politeknik Negeri Jember thesis (2025) reports 85% accuracy for health classification plus counting of vannamei benur — [sipora.polije.ac.id](https://sipora.polije.ac.id/41849/1/Ringkasan.pdf)

**Bayline (iOS app, 2025)**
- Counts shrimp larvae from the phone camera and claims above 95% accuracy. It warns that results vary with image quality, water clarity and lighting — [App Store](https://apps.apple.com/py/app/bayline/id6748222604)

**Rothschild 2022, "Computer vision system to count crustacean larvae" (arXiv:2209.05834)**
- Tested an iPhone 11 and a Sony DSC-HX90V (88.4% detection accuracy) and a Nikon DSLR (86% at density 50), with YOLOv5. Images were taken in an industrial pond. Scale/distance control is not described in the abstract — [arXiv](https://arxiv.org/abs/2209.05834)

**Dedicated counters with fixed geometry**
- Can Tho University optical-sensor PL counter: about 6,000 PL/h, about 95% accuracy in initial tests — [CTU Journal](https://ctujsvn.ctu.edu.vn/index.php/ctujsvn/article/download/1808/2011/2011)
- SincereAqua SC-4K/20K/60K: cameras plus AI, 200k–3.6M shrimp/h, 0.1–5 g animals, "precision of 95 percent". Article dated 29 Oct 2024 — [Global Seafood Alliance](https://www.globalseafood.org/advocate/can-ai-transform-how-shrimp-farms-count-their-stock/)
- A Chinese group-standard draft for an intelligent shrimp-larvae counter exists (2024). Contents not reviewed — [ttbz.org.cn](https://www.ttbz.org.cn/upload/file/20240716/6385672631695374197716956.pdf)

### Inferences
- The market pattern: **either own the geometry (ship a box/device) or ignore physical scale entirely**. Phone apps that only count don't need scale. They just need the whole container in frame, and PLCS solves that by segmenting the container. Scale only matters for size or weight estimates (Larvia), and nobody publicly documents how they get it.
- SeaThru's two-tier model (supplied white box for hardware clients, "own tray + guidance" for subscription clients) is the closest commercial analogue to ShrimpWatch's choice between requiring a box and verifying arbitrary ones.

### Gaps
- XpertSea's current (2024–2026) product line, and whether XperCount is still sold. No authoritative source found.
- Larvia's capture setup and scale method. Not public.
- PLCS and Shrimptector full texts (container dimensions, camera height, dataset size). Fetch was blocked (403 / binary PDF).
- JALA, eFishery, AquaEasy: no evidence found that any of them offers PL counting from images. Not searched in depth, so treat as unknown rather than "no".

## Q2. Does anyone use indirect scale verification (known PL size at a stage, or a reference object in the tray)?

### Takeaway
No source found explicitly uses known PL body length, or a fiducial/reference object, to verify scale in a counting app. The documented "verification" mechanisms are container segmentation (PLCS), standardised lighting and box (SeaThru), and returning annotated images so a human can check the detections (Larvia).

### Cited Findings
- Larvia returns "images to validate detection accuracy" along with length/weight histograms. This is human-in-the-loop verification of detections, not of scale — [IDB fAIr LAC](https://fairlac.iadb.org/en/larvia-shrimp-larvae-analysis-app-using-deep-learning)
- PLCS segments the container with Mask R-CNN to remove background. This is region verification, not size verification — [aquahoy](https://aquahoy.com/application-developed-shrimp-larvae-counting-smartphones/)
- Rothschild 2022 fitted a Gompertz growth model (R² = 0.983) to manually measured larval lengths by stage. This shows stage-to-length curves exist and are predictable, but the paper does not use them for camera calibration — [arXiv](https://arxiv.org/abs/2209.05834)
- SeaThru gives users size/colour/water-depth guidance instead of measuring the container — [The Fish Site](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)

### Inferences
- Using PL body length as a ruler is technically plausible: Rothschild's growth curve shows length is predictable by stage. But PL8–PL15 roughly doubles in length over that range, and lots vary, so it gives only a coarse sanity check (an order-of-magnitude camera-distance check), not a precise one. This is an inference with no direct source.
- Since nobody documents scale verification, ShrimpWatch would be doing something novel there. It is not industry standard practice.

### Gaps
- No patents were searched for "reference marker tray larvae count". A patent search (Google Patents) could reveal fiducial-based approaches.

## Q3. Setup / onboarding UX patterns

### Takeaway
The observed patterns are light: a white container, shade or flash guidance, a photo submitted through a chat app (LINE/WeChat), and results with annotated images. Stands, QR-coded trays and explicit calibration steps were **not** found in any source reviewed.

### Cited Findings
- SeaThru: photo-taking techniques plus guidance on container size, colour and water depth. Shade in sunlight, flash indoors. Photos submitted through LINE — [The Fish Site](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)
- PLCS: a WeChat applet. Take a photo or choose one from the album, with no extra equipment — [aquahoy](https://aquahoy.com/application-developed-shrimp-larvae-counting-smartphones/)
- Shrimptector: photograph benur in a white container — [Telkom Univ.](https://openlibrarypublications.telkomuniversity.ac.id/index.php/engineering/article/download/30131/28366/59348)
- SOPP-Benur CAK: the count result is shown to the buyer, so counting doubles as a trust/transaction artifact — [Telkom Surabaya](https://bce-sby.telkomuniversity.ac.id/wp-content/uploads/2024/12/427-2051-1-PB.pdf)
- XpertSea: pour the sample into a device, and results sync to the cloud. A digital transaction report is available for sales — [Aquaculture North America](https://www.aquaculturenorthamerica.com/taking-the-guesswork-out-of-inventory-management-2004/)

### Inferences
- Commercial products put setup quality into **guidance plus a supplied box** rather than runtime checks. The gating in ShrimpWatch/BenurGate (ARKit scan, exposure checks) goes beyond what competitors document publicly.

### Gaps
- No screenshots or onboarding flows were reviewed (app binaries not inspected). No evidence either way on phone stands sold as accessories.

## Q4. Indonesian benur trade practice: counting, packing, and standard styrofoam box sizes

### Takeaway
SNI 7585:2010 governs land transport packing of vannamei benur: plastic bags with 1/4–1/3 water inside a plastic-lined styrofoam box with wrapped ice. It refers box size and strength to SNI 01-4855-2006 rather than fixing a single SKU. On marketplaces, "box benur" is mostly a generic **9–10 kg EPS fish/ice box, about 47 × 31–32 × 29 cm (~27 L)**, sold by many unbranded sellers. Counting in practice is manual sampling, which sources describe as slow and error-prone.

### Cited Findings
- SNI 7585:2010 (Produksi benih udang vaname — pengemasan/transportasi darat): bags filled with water to 1/4–1/3 of bag volume. Bags go into a styrofoam box lined with plastic. 2–3 bags of ice wrapped in absorbent paper go between the bags. Styrofoam "ukuran dan kekuatan sesuai SNI 01-4855-2006". Liner plastic 80 × 100 cm, ≥0.06 mm thick — [SNI 7585:2010 PDF (UNAIR mirror)](https://myamoora.unair.ac.id/pluginfile.php/11602/mod_resource/content/1/SNI%207585-2010%281%29.pdf) (this content comes from the search snippet; direct fetch returned the course page, not the PDF text)
- Tokopedia "STYROFOAM BOX BENUR 9 KG UKURAN 47 X 32 X 29 CM", about Rp57,000, also marketed for ice/fish/drinks — [Tokopedia search](https://www.tokopedia.com/find/styrofoam-makanan)
- Tokopedia "Box Busa Benur 10 kg 27 Liter", 47 × 31 × 29 cm, about Rp48,856 — [Tokopedia search](https://www.tokopedia.com/find/styrofoam-makanan)
- A Surakarta seller lists a "Box Benur" with no dimensions, and other sizes (5, 6 kg at 33 × 22 × 24 cm, 8 kg) appear under generic labels — [Tokopedia search](https://www.tokopedia.com/find/box-styrofoam-untuk-es)
- Manual counting at stocking uses sampling with small nets or by hand, described as time-consuming and prone to human error — [Polije abstract](https://sipora.polije.ac.id/42405/1/Abstrak.pdf); [Polije Bab 1](https://sipora.polije.ac.id/42405/2/Bab%201%20Pendahuluan.pdf)
- A 2025 vannamei PL counting paper calls manual spoon counting inaccurate — [IJIES / inass.org](https://inass.org/wp-content/uploads/2024/11/2025033101.pdf)
- Can Tho University: manual counting at suppliers is slow and imprecise (Vietnam context) — [CTU Journal](https://ctujsvn.ctu.edu.vn/index.php/ctujsvn/article/download/1808/2011/2011)

### Inferences
- The "box benur" is a **commodity size class** (by kg/liter), not a controlled SKU. Two listings for the "same" box already differ by 1 cm (31 vs 32 cm). Internal dimensions, rib pattern and wall thickness will vary by molder. Requiring "box 9–10 kg" would therefore constrain the footprint only to about ±1–2 cm, and only if the user actually buys that class.
- Benur ship **in plastic bags inside** the box. The box is a transport container, not necessarily the counting vessel. Whether hatcheries count PL inside the styrofoam box (as in ShrimpWatch's assumption) or in a basin/bowl needs field confirmation.

### Gaps
- Not found: the exact "sampling takar" procedure (volume per scoop, number of scoops, extrapolation formula). Indonesian searches returned only generic "sampling" descriptions. A hatchery SOP or a BBPBAP Jepara / BPBAP Situbondo manual is needed.
- Not found: benur density per bag (e.g. ekor/kantong at PL10) or the number of bags per box.
- SNI 01-4855-2006 content (box dimensions/strength classes) not retrieved.
- No brand or molder (e.g. a dominant Indonesian EPS fish-box manufacturer) identified.

## Q5. Is shipping/recommending a cheap accessory more practical than verifying arbitrary boxes?

### Takeaway
The evidence leans toward "recommend or supply a standard white container plus guidance" as the industry norm. SeaThru does exactly this, with a fallback to user trays. Generic EPS benur boxes are cheap (about Rp50–65k) and roughly standard by size class, so the app could name one size class and treat everything else as "best effort", instead of trying to verify arbitrary boxes.

### Cited Findings
- SeaThru supplies a white box to hardware clients, and software-only clients use their own trays with guidance — [The Fish Site](https://thefishsite.com/articles/the-aquatech-startup-thats-making-accuracy-count)
- XpertSea and SincereAqua remove the problem with dedicated hardware, at a cost (about USD 5,000 for XperCount in 2018) — [Hatchery International](https://www.hatcheryinternational.com/counting-on-smart-tech-3191/); [Global Seafood Alliance](https://www.globalseafood.org/advocate/can-ai-transform-how-shrimp-farms-count-their-stock/)
- A 47 × 31–32 × 29 cm "box benur 9–10 kg" costs Rp48–57k on Tokopedia — [Tokopedia](https://www.tokopedia.com/find/styrofoam-makanan)
- PLCS works on arbitrary containers by segmenting them, with no extra equipment — [aquahoy](https://aquahoy.com/application-developed-shrimp-larvae-counting-smartphones/)

### Inferences
- For **counting only**, no competitor verifies physical scale. Whole-container-in-frame plus segmentation is enough. Scale verification matters only if ShrimpWatch's count depends on density per area or camera distance (for example, to reject too-high shots where faint PL become sub-pixel). If so, a cheap recommended box (or a printed sticker/marker of known size placed in or on the box) is cheaper to support than ARKit-measuring every box. This is an inference with no source showing a marker-based PL counter.
- Given the project context (ribbed white styrofoam, no reliable rectangle detection), "recommend the 9–10 kg ~47 × 31 × 29 cm class, warn otherwise" fits the few-tunable-gates preference better than hard verification.

### Gaps
- No field data on what fraction of Indonesian hatcheries/tambak already use the 9–10 kg box for counting, versus basins (baskom) or buckets.
- Not found: any Indonesian vendor selling a phone stand or counting tray for benur.
