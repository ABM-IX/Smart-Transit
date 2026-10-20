# SmartTransit: Academic Poster Master Prompt & Complete Text Guide 🇧🇼

**Institution:** Botswana Accountancy College (BAC) — School of Computing & Information Systems  
**Module:** Research & Innovation Project / Capstone Project Review  
**Project Title:** SmartTransit: A Real-Time Multi-Modal Intelligent Transport System for Gaborone  
**Authors:**
- Tadiwanashe Jedidiah Musikavanhu (`cse24-012`)
- Felix Kabira Kagwi (`cse24-106`)
- Arabang B Mothofela (`cse24-102`)
- Leon Green (`cse24-126`)  
**Supervisor:** Resego Tom Rabalone  
**Poster Standard:** Exact A3 Landscape (420mm × 297mm / Standard 1.414 Aspect Ratio)  
**Deliverable File:** [academic_poster.html](file:///c:/Users/araba/Desktop/SmartTransit/docs/academic_poster.html)

---

## 🚀 Part 1: Master Prompt to Give to Claude / Gemini

Copy and paste the exact prompt block below into **Claude 3.5 Sonnet (Artifacts)** or **Gemini 1.5 Pro / Advanced (Canvas)**:

```markdown
You are an expert Systems Architect, Academic Researcher, and UI/UX Designer.
Your task is to generate a publication-grade, production-quality academic research poster in a single self-contained HTML/CSS file (or Beamer/LaTeX) formatted for standard A4 Landscape (297mm x 210mm, aspect ratio 1.414:1).

The poster MUST follow this exact institutional template structure:
1. Deep Navy Blue Header Banner with geometric accents on left, network graph mesh on right:
   - Title: SMARTTRANSIT: A REAL-TIME MULTI-MODAL INTELLIGENT TRANSPORT SYSTEM FOR GABORONE
   - Authors: Tadiwanashe Jedidiah Musikavanhu (cse24-012) | Felix Kabira Kagwi (cse24-106) | Arabang B Mothofela (cse24-102) | Leon Green (cse24-126)
   - Affiliation: Supervisor: Resego Tom Rabalone | School of Computing and Information Systems | Botswana Accountancy College (BAC)
2. Two-column grid with 6 distinct color-coded cards, each having a numbered colored circle (1 to 6) in the header banner:
   - Left Column:
     • Box 1 (Soft Blue, #d7e8fa banner): "1 INTRODUCTION & PROBLEM STATEMENT" (Urban paratransit context, Gaborone combis/taxis, vehicle bunching, 4 literature gaps: Passive Tracking Fallacy, First/Last-Mile Void, Static GTFS Mismatch, Zero Regulatory Observability).
     • Box 3 (Soft Peach/Orange, #fde4d3 banner): "3 METHODOLOGY & SYSTEM ARCHITECTURE" (Pragmatist mixed-methods philosophy, 7 Agile Sprints over 12 weeks, 4-tier event-driven architecture, Horizontal 4-step pipeline: Data Collection -> Stream Processing -> Core Algorithms -> System Evaluation).
     • Box 5 (Soft Coral/Pink, #fcd9d9 banner): "5 CONCLUSION & CONTRIBUTION" (Active coordination over passive tracking, turnkey engineering contribution with 6 formal algorithms, public transit parity).
   - Right Column:
     • Box 2 (Soft Green, #d2f0db banner): "2 AIM & RESEARCH OBJECTIVES" (Aim: Real-time multi-modal ITS actively coordinating rather than passively displaying vehicles. 6 specific objectives: Real-time telemetry, Spatial k-NN dispatch, Headway spacing regulation, Automated geofencing, Multi-modal backward-scheduled routing, Regulatory telematics).
     • Box 4 (Soft Purple/Lavender, #ecddfd banner): "4 RESULTS, CORE ALGORITHMS & EVALUATION" (Table of 7 formal algorithms with math formulas and parameters, evaluation targets table, in-cab HUD pacing badge widget, theoretical discussion citing Newell, Daganzo, Delling, Bareth & Kothari).
     • Box 6 (Soft Teal/Cyan, #d0f3ef banner): "6 RECOMMENDATIONS & FUTURE WORK" (Policy recommendations for DRTS and Combi Associations, 4 study limitations, 3 future extensions: Orange Money/BURS, BLE offline mesh, SADC corridors).
3. Bottom Footer Banner (#e8ecf2):
   - Left: Book icon + 9-10 APA 7th edition academic references (Cervero 2000, Daganzo 2009, Newell 1974, Bast 2016, Bareth & Kothari 2015, Delling 2014, Lusenge 2020, Sinnott 1984, Tirachini 2020).
   - Right: Clean vector QR code box + label "SMARTTRANSIT REPO: Full System Specs, FastAPI & Flutter Code".

Aesthetic and Technical Constraints:
- Use WCAG 2.2 AA compliant contrast and modern typography (Inter / Segoe UI).
- Tabular figures and monospace font for mathematical formulas and code variables.
- Include `@media print { @page { size: A4 landscape; margin: 0; } }` so clicking Print / Ctrl+P immediately exports a crisp, perfectly fitted PDF without overflowing to page 2.
- No filler, no empty boilerplate, no stereotypical AI-generated rainbow gradients. Everything must be grounded in the Greater Gaborone informal transport domain.
```

---

## 📋 Part 2: Complete Verbatim Text & Wording Content

Use this text if you are manually designing or copying into PowerPoint, Canva, Figma, Illustrator, or LaTeX:

### [HEADER]
- **Main Title:** SMARTTRANSIT: A REAL-TIME MULTI-MODAL INTELLIGENT TRANSPORT SYSTEM FOR GABORONE
- **Sub-headline:** Active coordination of combis, taxis and intercity buses in Botswana's semi-formal transport network
- **Group Members:** Tadiwanashe Jedidiah Musikavanhu (cse24-012) | Felix Kabira Kagwi (cse24-106) | Arabang B Mothofela (cse24-102) | Leon Green (cse24-126)
- **Supervisor & Institution:** Supervisor: Resego Tom Rabalone | School of Computing and Information Systems | Botswana Accountancy College (BAC)

---

### [BOX 1] INTRODUCTION & PROBLEM STATEMENT
- **Background & Urban Context:**
  Informal and semi-formal paratransit carries **70%–90%** of motorized passenger trips in developing African cities (Cervero, 2000). In Greater Gaborone, public transit operates across three uncoordinated tiers: local combis (minibuses), standard shared/special private taxis, and regional intercity buses (Lusenge, 2020).
- **Problem Statement:**
  Decentralized and unmonitored operations lead to severe **vehicle bunching** (long service droughts followed by clustered arrivals), unpredictable commuter waiting times, arbitrary off-meter taxi fares, and fragmented transfers between suburban origins and arterial corridors.
- **Literature Review & Identified Research Gaps:**
  1. *Passive Tracking Fallacy:* Commercial apps (e.g., inDrive, Yango) plot vehicles on maps but offer zero active corridor-level headway control loops to prevent bunching (Daganzo, 2009).
  2. *First/Last-Mile Void:* Peri-urban commuters in Mogoditshane or Tlokweng lack coordinated links between on-demand cabs and arterial combi routes.
  3. *Static GTFS Mismatch:* Traditional schedule-dependent routing fails in paratransit where vehicles depart based on occupant demand ("depart-when-full") rather than timetables.
  4. *Zero Regulatory Observability:* DRTS authorities lack live operational telematics to audit route compliance, fares, and bottleneck patterns.

---

### [BOX 2] AIM & RESEARCH OBJECTIVES
- **Project Aim:**
  To design, architect, and evaluate **SmartTransit**, a real-time multi-modal Intelligent Transportation System (ITS) that actively coordinates Gaborone's taxis, combis, and intercity buses rather than merely displaying them passively.
- **Core Research & Engineering Objectives:**
  - **O1. Real-Time Telemetry:** Stream 1 Hz vehicle GPS telemetry over low-latency persistent WebSockets (FastAPI + Socket.IO) to waiting commuters and fleet managers.
  - **O2. Spatial Taxi Dispatch:** Rank and dispatch the 5 nearest available special cabs ($k=5$) within 500 ms using Haversine geodesic indexing.
  - **O3. Dynamic Anti-Bunching Regulation:** Evaluate consecutive vehicle headways on shared corridors and broadcast in-cab pacing advisories (`SPEED_UP` / `SLOW_DOWN` / `MAINTAIN`).
  - **O4. Autonomous Co-Movement Geofencing:** Automate trip state transitions (WAITING $\rightarrow$ ON_BOARD $\rightarrow$ COMPLETED) via spatial proximity ($d \le 20\text{m}$) and velocity co-movement ($v > 2\text{m/s}$).
  - **O5. Multi-Modal Journey Planning:** Synthesize connected taxi-combi-bus itineraries using NetworkX directed graphs with backward-scheduling buffers.
  - **O6. Regulatory Oversight:** Provide a desktop React web dashboard with live fleet maps and 5 statutory export reports (RPT-01 to RPT-05).

---

### [BOX 3] METHODOLOGY & SYSTEM ARCHITECTURE
- **Research Philosophy & Design:**
  Pragmatist mixed-methods philosophy combining quantitative telemetry metrics (wait-time delta, GPS precision, socket latency) with qualitative driver compliance and combi association focus groups.
- **Agile Development Schedule (7 Sprints / 12 Weeks):**
  - *Sprint 1:* Research & Requirements Gathering (User stories, literature baseline).
  - *Sprint 2:* UI/UX Design & Prototyping (Figma mockups, database schemas).
  - *Sprint 3:* Core Real-Time Development (FastAPI, Socket.IO, GPS streams).
  - *Sprint 4:* AI & Graph Implementation (Multi-modal backward-scheduling).
  - *Sprint 5:* Integration & Performance Testing (End-to-end socket testing).
  - *Sprint 6:* User Acceptance Testing (Pilot study with 10–15 drivers and commuters).
  - *Sprint 7:* Optimization & Statutory Documentation (Final system defense).
- **Horizontal Process Flow:**
  `[1. Data Collection: 1Hz GPS & Telemetry]` $\rightarrow$ `[2. Stream Processing: FastAPI Gateway & Pub/Sub]` $\rightarrow$ `[3. Core Algorithms: Headway, k-NN & Graph AI]` $\rightarrow$ `[4. System Evaluation: UAT & Telematics Audit]`
- **Layered Architecture:**
  - *Presentation Layer:* Flutter Mobile App (Driver HUD & Passenger UI) + React/Vite Dispatch Dashboard (Leaflet GIS).
  - *Gateway Layer:* FastAPI REST API + Python Socket.IO event gateway.
  - *Service Layer:* `geo.py` (Haversine), `headway.py` (Pacing), `fare.py` (Tariff), `ai_orchestrator.py` (Graph).
  - *Persistence Layer:* PostgreSQL (Supabase) + in-memory live tracking state.

---

### [BOX 4] RESULTS, CORE ALGORITHMS & EVALUATION
- **Algorithm Reference Summary:**
  | Algorithm | Mathematical Formulation / Operational Logic | Key Parameter / Target |
  | :--- | :--- | :--- |
  | **Haversine Distance** | $d = 2R \cdot \operatorname{atan2}(\sqrt{a}, \sqrt{1-a})$ | $R = 6,371\text{ km}$; $<1\text{ ms}$; $<0.3\%$ error |
  | **Spatial $k$-NN Dispatch** | $\operatorname{argmin}_{D' \subseteq D_{\text{avail}}, |D'|=k} \sum \mathcal{H}(p_{\text{req}}, \operatorname{coords}(d_i))$ | $k=5$ cabs; alert $<500\text{ ms}$; 15 s window |
  | **Anti-Bunching Pacing** | $\Delta d < 200\text{m} \rightarrow \text{SLOW}$; $\Delta d > 800\text{m} \rightarrow \text{SPEED}$ | $200\text{m} / 800\text{m}$ thresholds; 1s refresh |
  | **Speed-Floored ETA** | $v_{\text{eff}} = \max(5.0\text{ m/s}, v_{\text{inst}})$; $\tau_{\text{ETA}} = \lfloor d / v_{\text{eff}} \rfloor$ | $18\text{ km/h}$ floor; eliminates gridlock error |
  | **Co-Movement Geofence** | $\text{ON\_BOARD}: d \le 20\text{m} \land v > 2\text{m/s}$; $\text{COMPLETED}: d > 60\text{m}$ | Hands-free ticketing; eliminates tap-in delays |
  | **Multi-Modal AI Graph** | $T_{\text{arr}}^{\text{combi}} = T_{\text{dep}}^{\text{bus}} - 15\text{ min}$; $C(e) = \alpha \tau + \beta F + \gamma \text{Pnl}$ | 15-min transfer buffer; plan latency $<350\text{ ms}$ |
  | **Piecewise Tariff Engine** | $\text{Combi}: \text{BWP } 8.00$; $\text{Special}: \max(40, 40 + 6d + t)$ | Statutory DRTS compliance; zero overcharging |

- **Evaluation Framework Targets (Pilot $N=15$):**
  - *App Response Time:* Target $< 2.0\text{ s}$ (Observed: $340\text{ ms}$ API / $<100\text{ ms}$ Sockets)
  - *GPS Precision:* Target within $10\text{ m}$ (Achieved via Native Fused Location)
  - *Corridor Wait Reduction:* Target $25\%$ improvement on bunched routes
  - *AI Multi-Modal Success:* $>95\%$ feasible itineraries generated
  - *Missed Stop Reduction:* $30\%$ improvement via geofenced arrival chime
  - *User Satisfaction:* $\ge 4.0 / 5.0$ on standardized UAT Likert survey

- **Discussion:**
  The closed-loop headway monitoring directly disrupts the positive-feedback cycle of bus bunching proved by Newell (1974) and Daganzo (2009). Dynamic speed-flooring protects ETA calculations from arithmetic explosion during peak gridlock, while co-movement geofencing eliminates physical interaction during transit (Bareth & Kothari, 2015).

---

### [BOX 5] CONCLUSION & ACADEMIC CONTRIBUTION
1. **Active Coordination over Passive Tracking:** SmartTransit demonstrates that decentralized paratransit can achieve transit regularity without requiring costly, rigid timetables by combining mobile GPS telemetry with real-time headway control.
2. **Turnkey Technical Contribution:** Delivered an event-driven system architecture with 6 mathematically verified algorithms, transparent dual-rate DRTS fare estimation, and a macro-regulatory operations dashboard.
3. **Public Transit Equity:** Connects peripheral commuters from unserved neighborhoods to high-capacity arterial routes, establishing true first-to-last-mile connectivity.

---

### [BOX 6] RECOMMENDATIONS & FUTURE WORK
- **Policy & Operational Recommendations:**
  - Pilot in-cab headway displays with Gaborone Combi Associations along high-frequency corridors (e.g., Station – BBS Mall – Broadhurst).
  - Mandate DRTS web dashboard usage for annual public transport route planning and operator license compliance.
- **Academic Limitations:**
  - 12-week capstone project timeframe; geographic focus restricted to Greater Gaborone.
  - Pilot UAT sample size of 10–15 drivers and commuters; reliance on commercial 3G/4G cellular coverage.
- **Future Technical Extensions:**
  - Integrate Botswana Unified Revenue Service (BURS) / Orange Money cashless QR payments.
  - Implement Bluetooth Low Energy (BLE) peer-to-peer mesh sync for passenger detection in cellular dead-zones.
  - Expand multi-modal graph topology across Francistown and SADC intercity corridors.

---

### [FOOTER] REFERENCES & SCAN CODE
- **References (APA 7th Edition):**
  1. Bareth, G., & Kothari, H. (2015). Smart automated fare collection system using GPS and mobile geofencing. *Procedia Computer Science*, 57, 1204–1211.
  2. Bast, H., Delling, D., Goldberg, A., et al. (2016). Route planning in transportation networks. *Algorithm Engineering*, LNCS 9220, 19–80.
  3. Cervero, R. (2000). *Informal Transport in the Developing World*. UN-Habitat, Nairobi.
  4. Cover, T., & Hart, P. (1967). Nearest neighbor pattern classification. *IEEE Trans. Information Theory*, 13(1), 21–27.
  5. Daganzo, C. F. (2009). A headway-based approach to eliminate bus bunching. *Transp. Res. Part B*, 43(8-9), 913–921.
  6. Delling, D., Pajor, T., & Werneck, R. F. (2014). Round-based public transit routing. *Transp. Science*, 49(3), 591–604.
  7. Lusenge, A. (2020). Alleviating urban traffic congestion: Case of Gaborone City. *JESD*, 11(8), 1–6.
  8. Newell, G. F. (1974). Control of pairing of vehicles on a public transportation route. *Transp. Res.*, 8(3), 248–262.
  9. Sinnott, R. W. (1984). Virtues of the Haversine. *Sky & Telescope*, 68(2), 159.
  10. Tirachini, A. (2020). Ride-hailing, ride-pooling and public transport: A review. *Transp. Res. Part A*, 135, 201–221.
- **Scan Code Callout:**
  - QR Code linked to SmartTransit repository, live Swagger API docs, and architectural defense specifications.

---

## 🖨️ Part 3: How to Print / Download the Perfect A3 PDF

### Why did the previous download look different from the browser?
In your screenshot, three specific browser printing issues occurred:
1. **Paper Size Mismatch:** The browser print dialog defaulted to standard **A4** (or Letter) with 10mm default margins, squashing the vertical canvas and pushing Boxes 5, 6, and the Footer onto an invisible Page 2!
2. **Margin Header Clipping:** Default browser margins print the document URL and date along the top edge, which overlaps and clips the deep blue title header.
3. **Background Graphics Unchecked:** Without forcing background color printing, the colored cards and gradient banners render blank or washed out.

### The Fix (Follow These Exact Print Dialog Settings in Chrome/Edge):
The file [academic_poster.html](file:///c:/Users/araba/Desktop/SmartTransit/docs/academic_poster.html) is now engineered to strict **A3 Landscape (420mm × 297mm)**:

1. Open [academic_poster.html](file:///c:/Users/araba/Desktop/SmartTransit/docs/academic_poster.html) in Google Chrome or Microsoft Edge.
2. Click the blue **"Download / Print PDF (A3)"** button at the top right (or press `Ctrl + P`).
3. In the print dialog, adjust these 5 settings under **"More settings"**:
   - **Destination:** *Save as PDF*
   - **Layout:** *Landscape*
   - **Paper size:** Select **A3** (420 × 297 mm)
   - **Margins:** Select **None** *(Crucial: removes the 10mm margin and stops header clipping!)*
   - **Options:**
     - ✅ **Check "Background graphics"** *(Mandatory: renders all card colors and header gradients)*
     - ❌ **Uncheck "Headers and footers"** *(Removes the browser URL/date stamps)*
4. Click **Save**.

The resulting PDF will match the browser view on a single A3 sheet, vector-sharp with no cut-off elements.
