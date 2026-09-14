# SmartTransit — Complete System Use Cases, Engineering Diagrams & Operational Requirements Specification 🇧🇼

> **Document Type:** Master System Specification & Academic Defense Reference  
> **Target Audience:** Academic Supervisors, Lecturers, External Examiners, Capstone Review Panels (University of Botswana, Botho University, BAC), and Systems Engineers  
> **Project:** SmartTransit (Botswana Intelligent Mobility Platform)  
> **Lead Architect / Researcher:** Arabang Benville Mothofela (*First Minds*)  
> **Date:** September 2026  
> **Version:** 2.0.0 (Production & Academic Milestone Release)

---

## 📑 Table of Contents
1. [Executive Summary & Purpose](#1-executive-summary--purpose)
2. [Hardware, Sensor & Telecommunications Prerequisites ("What We Need")](#2-hardware-sensor--telecommunications-prerequisites-what-we-need)
   * 2.1 Mobile Phone Client Hardware Specifications
   * 2.2 Telematics, GPS & Spatial Sensor Requirements
   * 2.3 Cellular Network, ISP & Telecommunications Requirements (Botswana Context)
   * 2.4 Cloud Server & Computational Infrastructure
3. [Physical Hardware Deployment & System Architecture Topology](#3-physical-hardware-deployment--system-architecture-topology)
4. [Comprehensive UML Use Case Diagrams & Specifications](#4-comprehensive-uml-use-case-diagrams--specifications)
   * 4.1 Master System Use Case Diagram
   * 4.2 Commuter Actor Use Case Flows
   * 4.3 Driver Actor Use Case Flows
   * 4.4 Regulatory Authority / DRTS Fleet Dispatcher Use Case Flows
   * 4.5 Formal Use Case Narrative Specifications
5. [System Interaction & Sequence Diagrams (Session Lifecycles)](#5-system-interaction--sequence-diagrams-session-lifecycles)
   * 5.1 Driver Telematics Broadcast & Newell–Daganzo Spacing Advisory Loop
   * 5.2 Commuter Combi Discovery & Speed-Floored Dynamic ETA Session
   * 5.3 On-Demand Special Cab Hail & $k$-NN Spatial Dispatch Session
   * 5.4 Autonomous Co-Movement Proximity Geofencing Session
   * 5.5 DRTS Regulatory Fleet Compliance Audit Session
6. [System Activity & Workflow Flowcharts](#6-system-activity--workflow-flowcharts)
   * 6.1 Commuter Multi-Modal Journey Decision Tree
   * 6.2 Driver Dynamic Headway Regularization Cycle
   * 6.3 $k$-NN Spatial Taxi Dispatch Engine Flow
7. [Data Flow Diagrams (DFD)](#7-data-flow-diagrams-dfd)
   * 7.1 DFD Level 0 — Context Diagram
   * 7.2 DFD Level 1 — Subsystem Process Decomposition
8. [System State Machine & Lifecycle Transition Diagrams](#8-system-state-machine--lifecycle-transition-diagrams)
   * 8.1 Driver Operational Lifecycle State Machine
   * 8.2 Hail Request & Taxi Ride Lifecycle State Machine
9. [Database Entity-Relationship Diagram (ERD) & Schema Specification](#9-database-entity-relationship-diagram-erd--schema-specification)
10. [Core Mathematical Formulations & Algorithmic Engine ("How It Works")](#10-core-mathematical-formulations--algorithmic-engine-how-it-works)
    * 10.1 Newell–Daganzo Dynamic Headway Regularization
    * 10.2 Speed-Floored Dynamic ETA Calculation
    * 10.3 Spherical Haversine $k$-Nearest Neighbors ($k$-NN) Dispatch
    * 10.4 Autonomous Co-Movement Proximity Geofencing
    * 10.5 Multi-Modal Graph Route Optimization (NetworkX Dijkstra)
11. [How We Intend to Build the Entire System (Engineering Roadmap)](#11-how-we-intend-to-build-the-entire-system-engineering-roadmap)
    * 11.1 Technology Stack Architecture & Rationale
    * 11.2 Dual-Protocol Communication Architecture (REST vs WebSockets)
    * 11.3 Phased Implementation & Deployment Blueprint

---

## 1. Executive Summary & Purpose

The purpose of this specification is to provide project supervisors, academic examiners, and technical evaluators with a rigorous, end-to-end blueprint of **SmartTransit**. 

This document addresses the exact questions raised during system defense review meetings:
1. **What physical hardware, sensors, and network infrastructure are required** for the platform to operate in the field?
2. **How does the system work from a user and actor perspective**, mapped through formal UML Use Case, Activity, and Sequence diagrams?
3. **What algorithms drive the platform**, specifically regarding vehicle anti-bunching, speed-floored arrival estimation, and spatial taxi dispatch?
4. **How do we intend to engineer, integrate, and deploy the entire system** using our chosen tech stack?

SmartTransit replaces static, inaccurate timetable assumptions with a live, event-driven cybernetic feedback loop specifically adapted to the paratransit conditions of **Greater Gaborone, Botswana**.

---

## 2. Hardware, Sensor & Telecommunications Prerequisites ("What We Need")

To operate reliably in an African urban mobility environment, SmartTransit is engineered around commodity mobile hardware and local cellular networks. The system does not require expensive, dedicated onboard vehicle computers (OBUs); it transforms standard commercial smartphones into telematics edge nodes.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        FIELD OPERATIONAL PREREQUISITES HIERARCHY                         │
├─────────────────────────┬─────────────────────────────┬─────────────────────────────────┤
│    1. SENSOR TIER       │     2. CONNECTIVITY TIER    │       3. CLIENT HARDWARE        │
│  - GPS / GNSS (A-GPS)   │  - 3G / 4G LTE Cellular     │  - Android 8.0+ / iOS 13+       │
│  - < 10m CEP Accuracy   │  - Mascom / Orange / BTC    │  - 2GB+ RAM, Quad-Core CPU      │
│  - 1 Hz Polling Rate    │  - < 5 MB/day Driver Budget │  - High-Nit Display, Dashboard  │
│  - Accelerometer/Gyro   │  - WSS Secure WebSockets    │    Magnetic/Cradle Car Mount    │
└─────────────────────────┴─────────────────────────────┴─────────────────────────────────┘
```

### 2.1 Mobile Phone Client Hardware Specifications

#### A. Driver Cockpit Device (In-Vehicle Combi / Taxi Beacon)
* **Operating System:** Android 8.0 (API Level 26) or higher / iOS 13.0 or higher.
* **Processor & Memory:** Minimum Quad-Core 1.5 GHz CPU, 2 GB RAM (Recommended: 3 GB+ RAM).
* **Display Requirements:** Minimum 5.0-inch LCD/OLED with $\ge 450\text{ nits}$ peak brightness to ensure glanceability under direct Botswana sunlight.
* **Battery & Power Delivery:** Minimum 3,000 mAh internal battery paired with a **12V–24V in-vehicle cigarette-lighter USB adapter (minimum 5V / 2.1A)**. Active GPS polling and screen-on driving HUD consume $\approx 8\text{--}12\%$ battery per hour.
* **Ergonomic In-Vehicle Mounting:** Heavy-duty dashboard suction cradle or air-vent magnetic mount positioned within the driver’s primary 20-degree field of forward vision to guarantee hands-free compliance under Botswana Road Traffic Act regulations.

#### B. Commuter Device (Handheld Mobile Client)
* **Operating System:** Android 6.0+ or iOS 12.0+.
* **Processor & Memory:** Standard entry-level smartphone (1 GB RAM minimum, 2 GB recommended).
* **Storage Footprint:** Less than 35 MB installed storage (Flutter release build optimized with ProGuard / tree-shaking).

---

### 2.2 Telematics, GPS & Spatial Sensor Requirements

The integrity of headway regularization and dispatch matching depends on high-quality sensor ingestion:

* **Global Navigation Satellite System (GNSS):**
  * Support for GPS (USA), GLONASS (Russia), and Assisted GPS (A-GPS) using cellular base-station triangulation for rapid Time-To-First-Fix (TTFF $< 3\text{ seconds}$).
* **Spatial Accuracy Threshold:**
  * Horizontal accuracy must satisfy **Circular Error Probable (CEP) $\le 10\text{ meters}$** under clear line-of-sight.
  * In degraded urban canyons (e.g., dense bus canopies at Gaborone Station Rank), accuracy must remain within $\le 25\text{ meters}$; readings with reported horizontal dilution of precision $(\text{HDOP}) > 4.0$ are rejected by the backend Kalman filter.
* **Telemetry Sampling Frequency:**
  * **Driver Cockpit:** Fixed **$1.0\text{ Hz}$** (1 coordinate packet per second) during active shifts.
  * **Commuter App:** Dynamic on-demand polling (1 sample every 10–30 seconds during active map views; zero background consumption when app is minimized).
* **Inertial Sensors (IMU):**
  * Three-axis accelerometer and gyroscope utilized for **autonomous co-movement vector verification** (detecting shared linear acceleration $>2.0\text{ m/s}^2$ between commuter and vehicle).

---

### 2.3 Cellular Network, ISP & Telecommunications Requirements (Botswana Context)

Real-time coordination across Gaborone requires reliable wireless transport across Botswana's licensed telecommunications carriers:

* **Supported Mobile Network Operators (MNOs):**
  * **Mascom Wireless** (Coverage: $\approx 95\%$ population 3G/4G footprint across Greater Gaborone).
  * **Orange Botswana** (Robust high-speed 4G/LTE along urban arterials: Nelson Mandela Drive, Kudumatse Drive).
  * **BTC Mobile** (Botswana Telecommunications Corporation — wide rural/suburban coverage including peri-urban G-West, Tlokweng, and Mogoditshane).
* **Network Bearer Requirements:**
  * **3G (HSPA+) / 4G LTE / 5G**: Minimum uplink throughput of $64\text{ kbps}$ and latency $< 250\text{ ms}$ to maintain WebSocket keep-alive frames.
* **Data Consumption Budget (Addressing Driver Cost Sensitivity):**
  * In Botswana, mobile mobile data is priced at a premium. SmartTransit uses compact JSON payloads over persistent WebSocket connections:
    $$\text{Packet Size} \approx 128\text{ bytes} \implies 1\text{ Hz} \times 3600\text{ s/hr} \times 8\text{ hrs} \approx 3.68\text{ MB per shift}$$
  * A full 8-hour driving shift consumes **under 5 megabytes**, costing drivers less than **BWP 1.50 per day** on local daily data bundles.
* **Offline Resilience & Network Dropout Handling:**
  * If a driver travels into a temporary cellular dead zone (e.g., cuttings along the A1 highway or underground rank concourses), the mobile client caches up to 120 telemetry pings in an in-memory ring buffer and bursts them asynchronously upon cellular handshake restoration.

---

### 2.4 Cloud Server & Computational Infrastructure

* **Application Host:** High-availability Linux container instance (Ubuntu 22.04 LTS / Debian 12, Python 3.11+, Uvicorn ASGI).
* **Server Compute:** Minimum 2 vCPUs, 4 GB RAM, with sub-50ms network peering to Southern African internet exchange points (JINX/CINX).
* **Database Layer:** Managed Supabase PostgreSQL 15 instance with PostGIS 3.3 spatial engine, spatial indexing (`GIST`), and Row-Level Security (RLS).
* **Transport Security:** Strict TLS 1.3 / SSL encryption across all REST endpoints (`https://`) and WebSocket connections (`wss://`).

---

## 3. Physical Hardware Deployment & System Architecture Topology

The following diagram illustrates how the physical hardware, sensors, telecom base stations, cloud backend, and administrative desktop consoles interconnect in the real world:

```mermaid
flowchart TB
    subgraph PhysicalField [Field Layer: Edge Devices & Sensors in Gaborone]
        subgraph DriverVehicle [Combi / Special Cab Cockpit]
            DriverPhone["Driver Smartphone<br/>(Android/iOS • Min 2GB RAM)"]
            GPSChip["GPS/GNSS Receiver<br/>(1 Hz Position • Bearing • Speed)"]
            DashboardMount["Heavy-Duty Cradle Mount<br/>(12V DC Constant Power)"]
            GPSChip --> DriverPhone
            DashboardMount -.->|Sustained Power| DriverPhone
        end

        subgraph CommuterPedestrian [Commuter Handheld]
            PassengerPhone["Commuter Smartphone<br/>(Android/iOS Handheld)"]
            PassengerGPS["Mobile Location Services<br/>(Fused Location Provider)"]
            PassengerGPS --> PassengerPhone
        end
    end

    subgraph TelecomTier [Botswana Telecommunications Infrastructure]
        CellTowers["Cellular Base Stations (BTS / eNodeB)<br/>Mascom • Orange Botswana • BTC"]
        ISP_Gateway["Packet Data Network Gateway (PGW)<br/>Public APN / Low Latency Internet"]
        DriverPhone -->|Wireless 3G/4G LTE| CellTowers
        PassengerPhone -->|Wireless 3G/4G LTE / Wi-Fi| CellTowers
        CellTowers --> ISP_Gateway
    end

    subgraph CloudBackend [Cloud Hosting & Computational Engine]
        LoadBalancer["TLS 1.3 Reverse Proxy / Load Balancer<br/>(SSL Termination • DDoS Shield)"]
        
        subgraph AppServer [FastAPI Telematics Server]
            FastAPI_REST["FastAPI REST API Gateway<br/>(Auth, Routes, Statutory Fares)"]
            SocketIO_Hub["Python-SocketIO Gateway<br/>(1 Hz Ingestion, Spacing Broadcasts)"]
            HeadwayWorker["Newell–Daganzo Headway Engine<br/>(Curvilinear Anti-Bunching)"]
            DispatchWorker["k-NN Haversine Taxi Dispatcher<br/>(5 km Radius Search)"]
            RoutingEngine["NetworkX Multi-Modal Router<br/>(Graph Dijkstra Shortest Path)"]
        end

        subgraph DatabaseTier [Supabase Cloud Infrastructure]
            PostgresDB[("PostgreSQL 15 + PostGIS<br/>Spatial Tables & RLS Policies")]
            RealtimePubSub["Supabase Realtime Engine<br/>(Postgres Change Streaming)"]
        end

        ISP_Gateway -->|Encrypted HTTPS / WSS| LoadBalancer
        LoadBalancer --> FastAPI_REST
        LoadBalancer --> SocketIO_Hub
        SocketIO_Hub <--> HeadwayWorker
        SocketIO_Hub <--> DispatchWorker
        FastAPI_REST <--> RoutingEngine
        FastAPI_REST --> PostgresDB
        SocketIO_Hub --> PostgresDB
        PostgresDB --> RealtimePubSub
    end

    subgraph OperationsConsole [Regulatory & Fleet Command Tier]
        AdminPC["DRTS / Fleet Operator Workstation<br/>(Desktop PC / Multi-Monitor Chrome Browser)"]
        AdminPC -->|HTTPS / WSS Live Stream| LoadBalancer
    end

    classDef hardware fill:#e1f5fe,stroke:#0288d1,stroke-width:2px;
    classDef telecom fill:#fff3e0,stroke:#f57c00,stroke-width:2px;
    classDef server fill:#e8f5e9,stroke:#388e3c,stroke-width:2px;
    classDef db fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    class DriverPhone,PassengerPhone,DriverPhone,PassengerPhone,AdminPC hardware;
    class CellTowers,ISP_Gateway telecom;
    class FastAPI_REST,SocketIO_Hub,HeadwayWorker,DispatchWorker,RoutingEngine server;
    class PostgresDB,RealtimePubSub db;
```

---

## 4. Comprehensive UML Use Case Diagrams & Specifications

SmartTransit models four primary actors:
1. **Commuter (Passenger):** Handheld user seeking corridor transit or point-to-point charters.
2. **Driver (Combi / Taxi Operator):** Cockpit operator generating spatial telemetry and receiving pacing commands.
3. **DRTS Regulator / Association Official:** Administrative authority auditing corridor health, route compliance, and safety.
4. **Autonomous System Engine:** Internal algorithmic actors (Headway Regularizer, $k$-NN Dispatcher, Speed-Floored ETA Calculator).

---

### 4.1 Master System Use Case Diagram

```mermaid
flowchart LR
    Commuter((👤 Commuter / Passenger))
    Driver((🚖 Driver Operator))
    Regulator((🏛️ DRTS Regulator / Admin))
    Engine((⚙️ Algorithmic Engine))

    subgraph SmartTransitPlatform [SmartTransit System Boundary]
        UC_Auth([UC-01: Authenticate & Select Role])
        UC_PlanTrip([UC-02: Plan Multi-Modal Journey])
        UC_TrackCombi([UC-03: Track Live Combi on Map])
        UC_ViewETA([UC-04: View Speed-Floored Countdown ETA])
        UC_HailTaxi([UC-05: Hail On-Demand Special Cab])
        UC_VerifyBoarding([UC-06: Autonomous Boarding Verification])
        UC_RateTrip([UC-07: Rate Trip & Driver])

        UC_ToggleShift([UC-08: Toggle Shift Online/Offline])
        UC_BroadcastGPS([UC-09: Stream 1 Hz GPS Telemetry])
        UC_ReceiveAdvisory([UC-10: Receive Newell-Daganzo Spacing Advisory])
        UC_AcceptHail([UC-11: Accept/Reject Passenger Hail])
        UC_CompleteTrip([UC-12: Conclude Transit Run / Fare Collection])

        UC_ViewFleet([UC-13: Monitor Citywide Live Fleet Map])
        UC_InspectBunching([UC-14: Audit Corridor Spacing & Bunching])
        UC_Heatmap([UC-15: View Passenger Demand Density Heatmaps])
        UC_ExportReports([UC-16: Generate Statutory DRTS Reports RPT-01..05])

        UC_CalcHeadway([UC-17: Compute Curvilinear Inter-Vehicle Headway])
        UC_MatchKNN([UC-18: Execute k-NN Spatial Driver Matching])
        UC_CalcETA([UC-19: Compute Speed-Floored Dynamic ETA])
    end

    Commuter --> UC_Auth
    Commuter --> UC_PlanTrip
    Commuter --> UC_TrackCombi
    Commuter --> UC_ViewETA
    Commuter --> UC_HailTaxi
    Commuter --> UC_VerifyBoarding
    Commuter --> UC_RateTrip

    Driver --> UC_Auth
    Driver --> UC_ToggleShift
    Driver --> UC_BroadcastGPS
    Driver --> UC_ReceiveAdvisory
    Driver --> UC_AcceptHail
    Driver --> UC_CompleteTrip

    Regulator --> UC_Auth
    Regulator --> UC_ViewFleet
    Regulator --> UC_InspectBunching
    Regulator --> UC_Heatmap
    Regulator --> UC_ExportReports

    Engine --> UC_CalcHeadway
    Engine --> UC_MatchKNN
    Engine --> UC_CalcETA

    UC_BroadcastGPS -.->|<<triggers>>| UC_CalcHeadway
    UC_CalcHeadway -.->|<<updates>>| UC_ReceiveAdvisory
    UC_HailTaxi -.->|<<triggers>>| UC_MatchKNN
    UC_MatchKNN -.->|<<dispatches to>>| UC_AcceptHail
    UC_TrackCombi -.->|<<includes>>| UC_ViewETA
    UC_CalcETA -.->|<<feeds>>| UC_ViewETA
```

---

### 4.2 Commuter Actor Use Case Flows

```mermaid
flowchart TB
    C((👤 Commuter))

    subgraph CommuterUseCases [Commuter Subsystem Functions]
        UC2_1[Search Origin & Destination]
        UC2_2[Select Transit Mode<br/>Combi vs Taxi vs Multi-Modal]
        UC2_3[Observe Moving Combi Marker]
        UC2_4[Receive Speed-Floored ETA Countdown]
        UC2_5[Request Special Cab Charter]
        UC2_6[Confirm Statutory Gazetted Fare BWP 8.00 / Metered]
        UC2_7[Trigger Emergency SOS / Contact Driver]
    end

    C --> UC2_1
    C --> UC2_2
    C --> UC2_3
    C --> UC2_4
    C --> UC2_5
    C --> UC2_6
    C --> UC2_7
```

---

### 4.3 Driver Actor Use Case Flows

```mermaid
flowchart TB
    D((🚖 Combi / Taxi Driver))

    subgraph DriverUseCases [Driver Subsystem Functions]
        UC3_1[Login via Phone & Select Assigned Route]
        UC3_2[Toggle Driving Mode HUD<br/>High Contrast 1-Meter Glanceable]
        UC3_3[Transmit Continuous GPS / Heading / Speed]
        UC3_4[View Dynamic Spacing Widget<br/>SLOW DOWN / SPEED UP / MAINTAIN]
        UC3_5[Receive Audio Chime on Pacing Alert]
        UC3_6[Receive 30-Second In-Cab Taxi Hail Drawer]
        UC3_7[Confirm Passenger Pickup / Drop-off]
    end

    D --> UC3_1
    D --> UC3_2
    D --> UC3_3
    D --> UC3_4
    D --> UC3_5
    D --> UC3_6
    D --> UC3_7
```

---

### 4.4 Regulatory Authority / DRTS Fleet Dispatcher Use Case Flows

```mermaid
flowchart TB
    R((🏛️ DRTS Officer / Fleet Manager))

    subgraph AdminUseCases [Web Command Center Functions]
        UC4_1[Authenticate with Regulatory Credentials]
        UC4_2[View Real-Time Multi-Layered Leaflet Map]
        UC4_3[Filter Fleet by Corridor<br/>Route U1, U2, U3, Regional Corridors]
        UC4_4[Inspect Bunching Metric<br/>Coefficient of Headway Variation C_vh]
        UC4_5[View Real-Time Passenger Hail Density Cluster Pins]
        UC4_6[Export Statutory Regulatory Audit CSV/JSON<br/>RPT-01 Fleet • RPT-02 Bunching • RPT-05 Safety]
    end

    R --> UC4_1
    R --> UC4_2
    R --> UC4_3
    R --> UC4_4
    R --> UC4_5
    R --> UC4_6
```

---

### 4.5 Formal Use Case Narrative Specifications

#### Use Case: UC-10 — Receive Newell–Daganzo Spacing Advisory
* **Primary Actor:** Combi Driver.
* **Secondary Actor:** Headway Engine (Backend).
* **Pre-conditions:**
  1. Driver is authenticated and has toggled shift status to `ONLINE`.
  2. Vehicle is assigned to a recognized arterial corridor (e.g., Route U1: Station $\leftrightarrow$ BBS Mall).
  3. At least two active vehicles are streaming telemetry along the corridor.
* **Normal Flow:**
  1. Driver’s mobile app captures raw GPS fix $(lat, lng, speed, bearing)$ at $1\text{ Hz}$.
  2. Mobile app emits `driver_location_update` over WebSocket.
  3. Backend Headway Engine snaps coordinate to corridor centerline and calculates distance $d_{ahead}$ to preceding combi.
  4. Backend computes operational headway $h_i = \Delta d / \bar{v}$ and compares it to nominal target $H^*$.
  5. Backend determines spacing status:
     * If $d_{ahead} < 200\text{ m}$: Status is set to `SLOW DOWN` (Red Alert).
     * If $d_{ahead} > 800\text{ m}$: Status is set to `SPEED UP` (Blue Alert).
     * Otherwise: Status is set to `MAINTAIN CURRENT SPEED` (Green Steady).
  6. Backend emits `spacing_advisory` event directly to driver’s socket.
  7. Mobile app updates the in-cab heads-up display widget with high-contrast color cards and distance metrics.
* **Alternative Flow (Single Vehicle on Route):**
  * If no preceding or following vehicle exists on the corridor, status defaults to `MAINTAIN PACE` with indicator `Corridor Clear`.
* **Post-conditions:** Driver adjusts speed accordingly, preventing bunching platoons and balancing passenger arrival intervals.

---

## 5. System Interaction & Sequence Diagrams (Session Lifecycles)

### 5.1 Driver Telematics Broadcast & Newell–Daganzo Spacing Advisory Loop

This sequence diagram depicts the sub-second telemetry cycle between the in-cab driver phone, the FastAPI WebSocket gateway, the Headway Engine, and the persistent database:

```mermaid
sequenceDiagram
    autonumber
    actor Driver as 🚖 Driver Mobile App
    participant SocketGW as ⚡ FastAPI Socket.IO Hub
    participant Headway as 🧠 Headway Engine
    participant PostGIS as 🗄️ Supabase PostgreSQL
    actor Commuter as 👤 Commuter Mobile App
    actor Admin as 🖥️ DRTS Command Center

    Driver->>SocketGW: connect(token, role="DRIVER", vehicle_id="B-123-ABC")
    SocketGW-->>Driver: connection_established (sid)
    Driver->>SocketGW: emit("join_corridor", {route_id: "route_u1"})
    
    loop Every 1.0 Second (1 Hz Telemetry Cycle)
        Driver->>Driver: Acquire GNSS Fix (Lat, Lng, Speed, Heading)
        Driver->>SocketGW: emit("driver_location_update", {lat, lng, speed, heading, route_id})
        
        par Parallel Processing & Broadcast
            SocketGW->>Headway: calculate_spacing_advisories(corridor_drivers)
            Headway->>Headway: Haversine distance to lead/lag vehicles
            Headway-->>SocketGW: return [{driver_id, status: "SLOW DOWN", ahead_m: 145}]
            SocketGW-->>Driver: emit("spacing_advisory", {status: "SLOW DOWN", ahead_dist: 145})
            
            and Corridor Public Broadcast
            SocketGW-->>Commuter: emit("vehicle_moved", {vehicle_id, lat, lng, speed})
            
            and Command Center Stream
            SocketGW-->>Admin: emit("telemetry_feed", {vehicle_id, lat, lng, bunching: true})
        end

        opt Every 5 Seconds (Async Persistence)
            SocketGW-)PostGIS: UPSERT INTO driver_locations (lat, lng, speed, updated_at)
        end
    end
```

---

### 5.2 Commuter Combi Discovery & Speed-Floored Dynamic ETA Session

This sequence demonstrates how a commuter standing at a roadside stop receives accurate countdown arrival times without mathematical infinity explosion when combis stop:

```mermaid
sequenceDiagram
    autonumber
    actor Commuter as 👤 Commuter App
    participant API as 🌐 FastAPI REST Gateway
    participant GeoService as 📐 Geo & Routing Engine
    participant PostGIS as 🗄️ Supabase PostGIS
    participant SocketGW as ⚡ Real-Time Socket.IO

    Commuter->>API: GET /api/v1/routes/nearby?lat=-24.654&lng=25.912
    API->>PostGIS: SELECT * FROM stops ORDER BY ST_Distance(...) LIMIT 5
    PostGIS-->>API: Nearest Stops (e.g., BBS Mall Rank)
    API-->>Commuter: Return Nearby Corridors (Route U1, U4)

    Commuter->>SocketGW: emit("subscribe_route", {route_id: "route_u1"})
    SocketGW-->>Commuter: subscription_confirmed

    loop Telemetry Push from Active Combis
        SocketGW-->>Commuter: emit("vehicle_moved", {vehicle_id, lat, lng, speed: 0.0})
        Commuter->>GeoService: calculate_eta(distance=1200m, instantaneous_speed=0.0 km/h)
        Note over GeoService: Apply Floor Speed: effective_v = max(0.0, 18.0) = 18 km/h<br/>Add Dwell Penalties: 1 intermediate stop * 45s
        GeoService-->>Commuter: ETA = (1200m / 5.0m/s) + 45s = 285 seconds (4 min 45 sec)
        Commuter->>Commuter: Update UI Countdown: "4 MIN AWAY • ON SCHEDULE"
    end
```

---

### 5.3 On-Demand Special Cab Hail & $k$-NN Spatial Dispatch Session

This sequence diagram models the end-to-end booking of a blue-plate taxi:

```mermaid
sequenceDiagram
    autonumber
    actor Passenger as 👤 Commuter
    participant API as 🌐 FastAPI REST / Hails
    participant Dispatcher as 🎯 k-NN Dispatch Engine
    participant SocketGW as ⚡ Socket.IO Gateway
    actor Driver1 as 🚖 Taxi Driver #1 (Nearest)
    actor Driver2 as 🚖 Taxi Driver #2
    participant PostGIS as 🗄️ PostgreSQL DB

    Passenger->>API: POST /api/v1/hails/create {pickup_lat, pickup_lng, dropoff_lat, dropoff_lng}
    API->>PostGIS: INSERT INTO hails (status="WAITING") RETURNING id
    API->>Dispatcher: trigger_dispatch(hail_id, pickup_coords)
    Dispatcher->>PostGIS: Query idle TAXI drivers within 5.0 km geofence
    Dispatcher->>Dispatcher: Rank candidates via Haversine great-circle distance
    Dispatcher-->>SocketGW: Top k=3 Candidates Identified

    par Parallel Broadcast to Candidate Cockpits
        SocketGW->>Driver1: emit("new_hail_offer", {hail_id, pickup_name, est_fare: 45.00, timeout: 30s})
        SocketGW->>Driver2: emit("new_hail_offer", {hail_id, pickup_name, est_fare: 45.00, timeout: 30s})
    end

    alt Driver 1 Accepts within 12 seconds
        Driver1->>SocketGW: emit("accept_hail", {hail_id, driver_id: "D-01"})
        SocketGW->>PostGIS: UPDATE hails SET status="ACCEPTED", driver_id="D-01"
        SocketGW-->>Passenger: emit("hail_confirmed", {driver_name: "Kabo", plate: "B-882-ATX", eta: 4})
        SocketGW-->>Driver2: emit("hail_cancelled_taken", {hail_id})
    else 30s Timeout (No driver accepts)
        Dispatcher-->>Passenger: emit("hail_timeout", {reason: "All drivers busy, retrying..."})
    end
```

---

### 5.4 Autonomous Co-Movement Proximity Geofencing Session

This sequence demonstrates the automatic detection of passenger boarding and egress without requiring manual conductor taps:

```mermaid
sequenceDiagram
    autonumber
    actor Commuter as 👤 Commuter Phone
    actor Driver as 🚖 Combi Telematics Phone
    participant Server as ⚡ FastAPI Real-Time Engine
    participant DB as 🗄️ Supabase Trips

    Note over Commuter, Driver: Commuter standing at bus stop; combi pulls up and stops.
    Driver->>Server: 1 Hz Telemetry (Coords, v=0 m/s)
    Commuter->>Server: Periodic Proximity Ping (Coords, v=0 m/s)
    
    Note over Commuter, Driver: Commuter boards vehicle. Combi accelerates down corridor.
    loop Every 2 Seconds
        Driver->>Server: Telemetry: Pos_D(t), v_D = 12.5 m/s, Heading_D = 182°
        Commuter->>Server: Telemetry: Pos_C(t), v_C = 12.2 m/s, Heading_C = 180°
        Server->>Server: Evaluate Co-Movement Invariant:<br/>1. Spatial Proximity: dist(Pos_C, Pos_D) < 20m (True, 4.2m)<br/>2. Velocity Concordance: |v_C - v_D| < 1.0 m/s (True, 0.3m/s)<br/>3. Speed Threshold: v > 2.0 m/s (True, 12m/s)<br/>4. Temporal Persistence: t_consecutive >= 10 seconds (True)
    end

    Server->>DB: UPDATE trips SET status="BOARDED", actual_pickup_time=NOW()
    Server-->>Commuter: Push Notification: "Boarding Confirmed on Route U1"
    Server-->>Driver: HUD Indicator: Passenger Count Increment (+1)
```

---

### 5.5 DRTS Regulatory Fleet Compliance Audit Session

```mermaid
sequenceDiagram
    autonumber
    actor Officer as 🏛️ DRTS Compliance Officer
    participant WebUI as 🖥️ React Command Center
    participant REST as 🌐 FastAPI Analytics Router
    participant DB as 🗄️ PostgreSQL Analytics Store

    Officer->>WebUI: Navigate to "Regulatory Audits & Exports"
    WebUI->>REST: GET /api/v1/reports/corridor-headways?date=2026-09-13
    REST->>DB: Query aggregated corridor logs & bunching incidents
    DB-->>REST: Aggregated Metric Records
    REST-->>WebUI: Return Headway Distributions & C_vh Coefficients
    WebUI->>WebUI: Render Interactive Box-Plot & Bunching Hotspot Heatmap
    Officer->>WebUI: Click "Export Statutory RPT-02 (CSV)"
    WebUI->>REST: GET /api/v1/reports/export?type=RPT-02&format=csv
    REST-->>Officer: Deliver Authenticated CSV Download (DRTS-RPT02-20260913.csv)
```

---

## 6. System Activity & Workflow Flowcharts

### 6.1 Commuter Multi-Modal Journey Decision Tree

```mermaid
flowchart TD
    Start([Commuter Opens SmartTransit App]) --> EnterDest[Input Destination in Gaborone]
    EnterDest --> GeoLocate[Acquire Fused GPS Coordinates]
    GeoLocate --> QueryGraph[Query Multi-Modal Graph Router]
    
    QueryGraph --> ModeDecision{Choose Preferred Mode}
    
    ModeDecision -->|Fixed-Route Combi| CombiPath[Display Approaching Combis & Stops]
    CombiPath --> CombiETA[Render Speed-Floored Countdown ETA]
    CombiETA --> BoardCombi[Walk to Roadside Stop & Board]
    BoardCombi --> AutoDetect[Autonomous Co-Movement Detects Trip Start]
    AutoDetect --> PayGazetted[Pay Statutory BWP 8.00 Gazetted Fare]
    PayGazetted --> EndCombi([Trip Concluded at Drop-off])

    ModeDecision -->|On-Demand Special Cab| CabPath[Display Upfront Metered Fare Estimate]
    CabPath --> HailCab[Submit Hail Request to Dispatch Engine]
    HailCab --> WaitForDriver{Driver Accepts within 30s?}
    WaitForDriver -->|Yes| CabArrives[Driver Arrives at Pickup Coordinates]
    WaitForDriver -->|No / Timeout| ExpandSearch[Expand Radius from 5km to 8km]
    ExpandSearch --> WaitForDriver
    CabArrives --> InTransitCab[In-Cab Navigation & Live Metering]
    InTransitCab --> EndCab([Arrive at Destination & Digital Payment])

    ModeDecision -->|Multi-Modal Combined| MultiPath[Synthesize Multi-Leg Transfer Plan]
    MultiPath --> Leg1[Leg 1: Special Cab from Home to Gaborone Station Rank]
    Leg1 --> Leg2[Leg 2: Intercity Coach from Station to Francistown]
    Leg2 --> EndMulti([Seamless Multi-Modal Transfer])
```

---

### 6.2 Driver Dynamic Headway Regularization Cycle

```mermaid
flowchart TD
    DStart([Driver Toggles Shift to ONLINE]) --> RouteSelect[Select Assigned Corridor e.g. Route U1]
    RouteSelect --> StartGPS[Start Background Telemetry Engine @ 1 Hz]
    
    StartGPS --> ReadSensors[Read GPS Lat, Lng, Speed, Bearing]
    ReadSensors --> EmitSocket[Emit driver_location_update via WebSocket]
    
    EmitSocket --> ServerSnap[Backend Snaps Position to Corridor Curve]
    ServerSnap --> QuerySurrounding[Identify Preceding Vehicle i-1 and Following Vehicle i+1]
    
    QuerySurrounding --> HasPreceding{Preceding Vehicle Found?}
    HasPreceding -->|No| SoloStatus[Status = 'MAINTAIN PACE - CLEAR CORRIDOR']
    HasPreceding -->|Yes| ComputeDist[Calculate Curvilinear Distance d_ahead]
    
    ComputeDist --> EvaluateThresholds{Evaluate Spacing Criteria}
    EvaluateThresholds -->|d_ahead < 200 meters| SlowDown[Set Status: 'SLOW DOWN'<br/>Red Cockpit Alert • Audio Chime]
    EvaluateThresholds -->|d_ahead > 800 meters| SpeedUp[Set Status: 'SPEED UP'<br/>Blue Cockpit Alert • Close Gap]
    EvaluateThresholds -->|200m <= d_ahead <= 800m| Maintain[Set Status: 'MAINTAIN PACE'<br/>Green Steady • Optimal Headway]
    
    SlowDown --> SendClient[Emit spacing_advisory Payload to Driver]
    SpeedUp --> SendClient
    Maintain --> SendClient
    SoloStatus --> SendClient
    
    SendClient --> RenderHUD[Driver Heads-Up Display Updates in Cab]
    RenderHUD --> Wait1s[Sleep for 1000 ms]
    Wait1s --> ReadSensors
```

---

### 6.3 $k$-NN Spatial Taxi Dispatch Engine Flow

```mermaid
flowchart TD
    HStart([Commuter Submits Hail Request]) --> ExtractCoords[Extract Pickup Lat, Lng & Service Type]
    ExtractCoords --> BoundingBox[Construct Initial 5.0 km Spatial Bounding Box]
    BoundingBox --> PostGISFilter[Query driver_locations: is_online=true AND service_type='TAXI']
    
    PostGISFilter --> AnyFound{Candidate Drivers >= 1?}
    AnyFound -->|No| IncrementRadius[Expand Radius to 8.0 km]
    IncrementRadius --> PostGISFilter
    
    AnyFound -->|Yes| HaversineLoop[Compute Spherical Haversine Distance for Each Driver]
    HaversineLoop --> SortCandidates[Sort Ascending by Distance]
    SortCandidates --> SliceTopK[Select Top k=5 Nearest Idle Drivers]
    
    SliceTopK --> ParallelDispatch[Broadcast Hail Payload via WebSockets]
    ParallelDispatch --> StartTimer[Initialize 30-Second Countdown Timer]
    
    StartTimer --> CheckResponse{Driver Accepts?}
    CheckResponse -->|Driver i Accepts| LockHail[Atomic Transaction: Assign Hail to Driver i]
    LockHail --> NotifyOthers[Send hail_cancelled to Remaining 4 Candidates]
    NotifyOthers --> RoutePassenger[Stream Driver Location & ETA to Commuter]
    RoutePassenger --> HDone([Dispatch Complete])

    CheckResponse -->|Timer Expires 30s| CheckRetry{Retry Count < 3?}
    CheckRetry -->|Yes| ReDispatch[Re-query Next k Candidates]
    ReDispatch --> ParallelDispatch
    CheckRetry -->|No| FailDispatch[Return 'No Drivers Available' to Commuter]
    FailDispatch --> HDone
```

---

## 7. Data Flow Diagrams (DFD)

### 7.1 DFD Level 0 — Context Diagram

```mermaid
flowchart LR
    CommuterUser((Commuter / Passenger))
    DriverUser((Driver Operator))
    DRTSUser((DRTS Regulator))
    TelecomMNO((Mobile Operators<br/>Mascom/Orange/BTC))

    SystemBox[[SmartTransit Platform<br/>Core Real-Time System]]

    CommuterUser -->|Trip Requests, Hail Submissions, Ratings| SystemBox
    SystemBox -->|Live Vehicle Maps, Speed-Floored ETAs, Driver Profiles| CommuterUser

    DriverUser -->|1 Hz GPS Telemetry, Shift State, Hail Accepts| SystemBox
    SystemBox -->|Newell-Daganzo Spacing Advisories, Dispatch Offers| DriverUser

    DRTSUser -->|Audit Queries, Compliance Inspection Requests| SystemBox
    SystemBox -->|Live Fleet Telematics, Corridor Metrics, Statutory CSVs| DRTSUser

    TelecomMNO <-->|IP Packet Bearer / 3G/4G/5G Wireless Transport| SystemBox
```

---

### 7.2 DFD Level 1 — Subsystem Process Decomposition

```mermaid
flowchart TB
    subgraph ExternalEntities [External Actors]
        Commuter((👤 Commuter))
        Driver((🚖 Driver))
        Regulator((🏛️ DRTS Official))
    end

    subgraph CoreProcesses [SmartTransit Level 1 Processes]
        P1["1.0<br/>Authentication & Session Manager"]
        P2["2.0<br/>Telematics Ingestion & Coordinate Filter"]
        P3["3.0<br/>Newell–Daganzo Headway Regularizer"]
        P4["4.0<br/>Spatial k-NN Dispatch Engine"]
        P5["5.0<br/>Speed-Floored ETA & Routing Engine"]
        P6["6.0<br/>Statutory Regulatory Reporter"]
    end

    subgraph DataStores [Database Repositories]
        D1[("D1: Users & Driver Profiles")]
        D2[("D2: Live Driver Locations (In-Memory/PostGIS)")]
        D3[("D3: Transit Routes & Waypoints")]
        D4[("D4: Hail Bookings & Trips")]
        D5[("D5: Historical Telematics Audit Store")]
    end

    Commuter -->|Credentials| P1
    Driver -->|Credentials| P1
    Regulator -->|Credentials| P1
    P1 <-->|Read/Write Profile| D1

    Driver -->|Raw GPS Packets (1 Hz)| P2
    P2 -->|Validated Spatial Coords| D2
    P2 -->|Filtered Coordinate Stream| P3
    P2 -->|Log Historical Run| D5

    D3 -->|Corridor Geometry| P3
    D2 -->|Active Driver Spacing| P3
    P3 -->|Spacing Advisories| Driver

    Commuter -->|Hail Request Coordinates| P4
    D2 -->|Idle Taxi Positions| P4
    P4 -->|Dispatch Notification| Driver
    P4 <-->|Create / Update Trip Record| D4
    P4 -->|Trip Confirmation| Commuter

    D2 -->|Live Moving Positions| P5
    D3 -->|Stop Sequences| P5
    P5 -->|Countdown Dynamic ETAs| Commuter

    Regulator -->|Audit Query Parameters| P6
    D5 -->|Historical Spacing & Speeds| P6
    D4 -->|Trip Volumes & Fares| P6
    P6 -->|Statutory CSV/JSON Reports RPT-01..05| Regulator
```

---

## 8. System State Machine & Lifecycle Transition Diagrams

### 8.1 Driver Operational Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> OFFLINE: App Launch

    OFFLINE --> AUTHENTICATING: Driver Enters Credentials
    AUTHENTICATING --> OFFLINE: Auth Failure
    AUTHENTICATING --> IDLE_OFFLINE: Auth Success

    IDLE_OFFLINE --> ONLINE_ACTIVE: Toggle Shift 'ONLINE'
    
    state ONLINE_ACTIVE {
        [*] --> CORRIDOR_CRUISING: En Route
        CORRIDOR_CRUISING --> DWELLING_AT_RANK: Speed < 2 km/h at Known Stop
        DWELLING_AT_RANK --> CORRIDOR_CRUISING: Speed > 5 km/h
        CORRIDOR_CRUISING --> BUNCHING_ALERT: d_ahead < 200m (Lead Vehicle Close)
        BUNCHING_ALERT --> CORRIDOR_CRUISING: d_ahead >= 200m (Driver Decelerated)
        CORRIDOR_CRUISING --> GAP_ALERT: d_ahead > 800m (Lagging Behind)
        GAP_ALERT --> CORRIDOR_CRUISING: d_ahead <= 800m (Driver Accelerated)
    }

    ONLINE_ACTIVE --> DISPATCHED_TAXI: Hail Accepted (Taxi Mode)
    DISPATCHED_TAXI --> PASSENGER_ONBOARD: Pickup Coordinates Reached
    PASSENGER_ONBOARD --> ONLINE_ACTIVE: Trip Concluded / Drop-off

    ONLINE_ACTIVE --> IDLE_OFFLINE: Toggle Shift 'OFFLINE'
    IDLE_OFFLINE --> [*]: App Terminated
```

---

### 8.2 Hail Request & Taxi Ride Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> PENDING: Commuter Submits Hail

    PENDING --> DISPATCHED: k-NN Matches Nearest Drivers (<= 5km)
    PENDING --> EXPIRED: No Active Drivers Available (30s)

    DISPATCHED --> ACCEPTED: Driver Confirms Acceptance
    DISPATCHED --> EXPIRED: All Candidate Drivers Timeout (30s)

    ACCEPTED --> EN_ROUTE: Driver Navigating to Pickup
    ACCEPTED --> CANCELLED_COMMUTER: Commuter Cancels Before Arrival
    ACCEPTED --> CANCELLED_DRIVER: Driver Cancels (Emergency)

    EN_ROUTE --> ARRIVED: Driver Enters Pickup Geofence (dist < 30m)
    ARRIVED --> ONBOARD: Passenger Boards Vehicle
    ONBOARD --> COMPLETED: Destination Geofence Reached & Fare Paid

    COMPLETED --> [*]
    CANCELLED_COMMUTER --> [*]
    CANCELLED_DRIVER --> [*]
    EXPIRED --> [*]
```

---

## 9. Database Entity-Relationship Diagram (ERD) & Schema Specification

The underlying schema is deployed on **Supabase PostgreSQL 15** with spatial extensions enabled (`uuid-ossp`, `postgis`):

```mermaid
erDiagram
    USERS ||--o{ DRIVER_LOCATIONS : "broadcasts"
    USERS ||--o{ TRIPS : "requests/operates"
    USERS ||--o{ HAILS : "submits"
    ROUTES ||--o{ ROUTE_STOPS : "comprises"
    STOPS ||--o{ ROUTE_STOPS : "associated_with"
    ROUTES ||--o{ TRIPS : "traverses"
    ROUTES ||--o{ DRIVER_LOCATIONS : "assigned_to"

    USERS {
        text id PK "UUID"
        text email UK "User Email"
        text full_name "Full Legal Name"
        text phone_number "MNO Phone Contact"
        text role "PASSENGER | DRIVER | DISPATCHER | ADMIN"
        text vehicle_plate "Blue-Plate / Combi Registration"
        text service_type "COMBI | TAXI | BUS"
        text assigned_route_id FK "References routes(id)"
        numeric rating "Default 5.00"
        boolean is_active "Account Active State"
        timestamptz created_at "Registration Timestamp"
    }

    ROUTES {
        text id PK "e.g. route_u1, route_u2"
        text name "Corridor Descriptive Name"
        text origin_name "e.g. Gaborone Station"
        text destination_name "e.g. BBS Mall"
        text route_type "COMBI | TAXI | BUS"
        numeric base_fare "Statutory Gazetted BWP 8.00"
        jsonb waypoints "Polyline Coordinates"
        boolean is_active "Operational Flag"
    }

    STOPS {
        text id PK "e.g. stop_bbs, stop_station"
        text name "Stop Name"
        double_precision latitude "Spatial Latitude"
        double_precision longitude "Spatial Longitude"
        text description "Physical Landmark"
    }

    ROUTE_STOPS {
        serial id PK "Sequential ID"
        text route_id FK "References routes(id)"
        text stop_id FK "References stops(id)"
        integer sequence_order "Order Index 1..N"
    }

    DRIVER_LOCATIONS {
        text driver_id PK "References users(id)"
        text service_type "COMBI | TAXI | BUS"
        text route_id FK "References routes(id)"
        double_precision latitude "Current GPS Latitude"
        double_precision longitude "Current GPS Longitude"
        double_precision speed "Speed in m/s or km/h"
        double_precision heading "Compass Bearing 0..360 deg"
        integer occupancy "Current Passenger Count"
        boolean is_online "Shift Online State"
        timestamptz updated_at "1 Hz Update Timestamp"
    }

    HAILS {
        uuid id PK "UUID Generation"
        text passenger_id FK "References users(id)"
        text route_id FK "Optional Route Link"
        text service_type "TAXI | COMBI"
        text status "WAITING | ACCEPTED | BOARDED | CANCELLED"
        double_precision pickup_lat "Origin Latitude"
        double_precision pickup_lng "Origin Longitude"
        double_precision dropoff_lat "Destination Latitude"
        double_precision dropoff_lng "Destination Longitude"
        numeric fare_estimate "Calculated Fare BWP"
        timestamptz created_at "Hail Request Time"
    }

    TRIPS {
        uuid id PK "UUID Generation"
        text passenger_id FK "References users(id)"
        text driver_id FK "References users(id)"
        text route_id FK "References routes(id)"
        text service_type "COMBI | TAXI | BUS"
        text status "PENDING | ACCEPTED | ONBOARD | COMPLETED | CANCELLED"
        numeric fare "Gazetted or Metered Fare BWP"
        integer rating "Commuter Score 1..5"
        text rating_comment "Review Feedback"
        timestamptz created_at "Trip Inception"
        timestamptz completed_at "Trip Conclusion"
    }
```

---

## 10. Core Mathematical Formulations & Algorithmic Engine ("How It Works")

### 10.1 Newell–Daganzo Dynamic Headway Regularization

To stop combis from clumping into platoons on high-demand corridors (e.g., Nelson Mandela Drive), SmartTransit implements a discrete dynamic headway regularizer adapted from the Newell car-following model and Daganzo's adaptive headway control:

Let:
* $N$ be the number of active combis on corridor $R$.
* $x_i(t)$ be the curvilinear position of vehicle $i$ along the corridor at time $t$.
* $\bar{v}$ be the rolling historical corridor transit speed (typically $30\text{ km/h} \approx 8.33\text{ m/s}$).
* $H^*$ be the target scheduled operational headway (e.g., $300\text{ seconds} = 5\text{ minutes}$).

The instantaneous spatial headway $\Delta d_i(t)$ between trailing vehicle $i$ and leading vehicle $i-1$ is:
$$\Delta d_i(t) = x_{i-1}(t) - x_i(t)$$

The operational time headway $h_i(t)$ is formulated as:
$$h_i(t) = \frac{\Delta d_i(t)}{\bar{v}}$$

The spacing advisory $A_i(t)$ emitted to the in-cab display is determined by dynamic threshold buffers $\epsilon_1 = 200\text{ m}$ and $\epsilon_2 = 800\text{ m}$:

$$A_i(t) = \begin{cases} 
\text{"SLOW DOWN"} & \text{if } \Delta d_i(t) < \epsilon_1 \quad (\text{Platooning danger; lead vehicle too close}) \\ 
\text{"SPEED UP"} & \text{if } \Delta d_i(t) > \epsilon_2 \quad (\text{Excess gap; starvation interval behind}) \\ 
\text{"MAINTAIN CURRENT SPEED"} & \text{if } \epsilon_1 \le \Delta d_i(t) \le \epsilon_2 \quad (\text{Equilibrium spacing}) 
\end{cases}$$

---

### 10.2 Speed-Floored Dynamic ETA Calculation

Naive arrival time formulas estimate $\text{ETA} = \frac{d}{v}$. However, when a public transit vehicle stops at a rank, passenger boarding stop, or red traffic light, $v \to 0$, causing the estimated time of arrival to diverge to infinity ($\infty$).

SmartTransit resolves this with an empirically derived **Speed-Floored Regularizer**:

$$\text{ETA}(d, v) = \frac{D_{\text{remaining}}}{\max(v_{\text{instantaneous}}, v_{\text{floor}})} + \sum_{k=1}^{N_{\text{intermediate}}} t_{\text{dwell}, k}$$

Where:
* $v_{\text{floor}} = 18.0\text{ km/h} \equiv 5.0\text{ m/s}$ (the empirical lower-bound crawl velocity of Gaborone arterial corridors during peak congestion).
* $t_{\text{dwell}} = 45\text{ seconds}$ per designated intermediate boarding stop between vehicle position and commuter stop.
* $D_{\text{remaining}}$ is calculated along the road network polyline.

**Mathematical Guarantee:**
$$\lim_{v_{\text{instantaneous}} \to 0} \text{ETA}(d, v) = \frac{D_{\text{remaining}}}{5.0\text{ m/s}} + N_{\text{stops}} \times 45\text{ s} < \infty$$
The arrival countdown remains smooth, monotonic, and bounded under all standstill conditions.

---

### 10.3 Spherical Haversine $k$-Nearest Neighbors ($k$-NN) Dispatch

When a commuter requests an on-demand special cab, the backend matches the nearest available drivers using great-circle spherical distance over the Earth's geoid:

$$\Delta \phi = \phi_2 - \phi_1, \quad \Delta \lambda = \lambda_2 - \lambda_1$$
$$a = \sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)$$
$$c = 2 \cdot \text{atan2}\left(\sqrt{a}, \sqrt{1 - a}\right)$$
$$d = R_{\text{earth}} \cdot c \quad \text{where } R_{\text{earth}} = 6,371,000\text{ meters}$$

The dispatch engine executes this calculation in $O(N)$ time over all idle drivers ($N \approx 50\text{--}500$), filters candidates within a $5.0\text{ km}$ geofence, ranks candidates in ascending order of distance, and dispatches the hail offer to the top $k=5$ drivers simultaneously via WebSockets.

---

### 10.4 Autonomous Co-Movement Proximity Geofencing

To verify passenger boarding without requiring driver attention or paper ticketing, SmartTransit uses **autonomous kinematic vector alignment**:

Let $\vec{P}_p(t), \vec{v}_p(t)$ be the position and velocity vector of the passenger's mobile phone, and $\vec{P}_d(t), \vec{v}_d(t)$ be that of the driver's vehicle phone. Boarding is verified if all four conditions hold for a sustained interval $\Delta t \ge 10\text{ seconds}$:
1. **Spatial Proximity:** $\|\vec{P}_p(t) - \vec{P}_d(t)\| \le 20.0\text{ meters}$.
2. **Velocity Vector Magnitude Match:** $|\|\vec{v}_p(t)\| - \|\vec{v}_d(t)\|| \le 1.5\text{ m/s}$.
3. **Heading Alignment:** $|\theta_p(t) - \theta_d(t)| \le 25^\circ$.
4. **Motion Threshold:** $\|\vec{v}_d(t)\| \ge 2.5\text{ m/s}$ (excluding stationary sidewalk bystanders).

When all invariants hold, the trip state transitions automatically from `ACCEPTED` to `BOARDED`.

---

### 10.5 Multi-Modal Graph Route Optimization (NetworkX Dijkstra)

Regional travel across Botswana frequently requires multi-leg combinations:
$$\text{Home (Walk)} \longrightarrow \text{Special Cab (Charter)} \longrightarrow \text{Combi (Corridor)} \longrightarrow \text{Intercity Bus (Regional Corridor)}$$

SmartTransit models the entire Gaborone transit network as a directed weighted multi-graph $G = (V, E)$. Edge weights $W_e$ are parameterized as a cost function combining financial fare and travel time:
$$W_e = \alpha \cdot \text{Time}_e + \beta \cdot \text{Fare}_e + \gamma \cdot \text{TransferPenalty}$$
Where $\alpha, \beta, \gamma$ are commuter preference weights. The shortest path is computed via Dijkstra’s algorithm in $O(|E| + |V| \log |V|)$ time.

---

## 11. How We Intend to Build the Entire System (Engineering Roadmap)

### 11.1 Technology Stack Architecture & Rationale

| Subsystem Tier | Chosen Technology | Engineering Justification |
| :--- | :--- | :--- |
| **Mobile Client** | **Flutter (Dart)** | Single cross-platform codebase compiling to native ARM binary for both Android and iOS. Delivers high-performance 60 FPS map rendering and continuous background location streaming. |
| **Backend API & Realtime** | **Python 3.11+ / FastAPI / Socket.IO** | Async event-driven architecture using `asyncio` and `uvicorn`. Capable of handling $10,000+$ concurrent persistent WebSocket connections with sub-15ms latency. Direct native integration with Python spatial and mathematical libraries (`numpy`, `math`, `networkx`). |
| **Database & GIS** | **Supabase PostgreSQL 15 + PostGIS** | Enterprise-grade spatial relational database. PostGIS provides hardware-accelerated spatial indexing (`GIST`) and native geometry functions (`ST_Distance`, `ST_DWithin`). Supabase Realtime enables event-driven pub/sub data synchronization. |
| **Web Command Center** | **React 18 / Vite / Leaflet.js** | Ultra-responsive desktop single-page application (SPA). Leaflet.js renders hundreds of moving vehicle markers seamlessly without the heavy licensing costs of Google Maps JavaScript API. |

---

### 11.2 Dual-Protocol Communication Architecture (REST vs WebSockets)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        HYBRID CLIENT-SERVER PROTOCOL TOPOLOGY                          │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│         REST HTTP/2 (Stateless)           │        WEBSOCKET WSS (Stateful Stream)     │
├───────────────────────────────────────────┼────────────────────────────────────────────┤
│  - User Authentication & Registration     │  - 1 Hz Driver GPS Telemetry Ingestion     │
│  - Static Route & Stop Queries            │  - Newell-Daganzo Spacing Advisory Push    │
│  - Initial Hail Submission                │  - Real-Time Vehicle Marker Map Streaming  │
│  - Trip History & Historical Analytics    │  - On-Demand Hail Dispatch Offer Chimes    │
│  - Statutory DRTS Report Generation (CSV) │  - Emergency SOS & Cancellation Broadcasts │
└───────────────────────────────────────────┴────────────────────────────────────────────┘
```

---

### 11.3 Phased Implementation & Deployment Blueprint

```mermaid
gantt
    title SmartTransit Implementation & Defense Timeline
    dateFormat  YYYY-MM-DD
    section Phase 1: Foundations
    Database Schema & PostGIS Setup      :done,    p1_1, 2026-08-15, 2026-08-25
    FastAPI Core REST Architecture       :done,    p1_2, 2026-08-22, 2026-08-31
    section Phase 2: Telematics & Logic
    Socket.IO Real-Time Dispatch Hub     :done,    p2_1, 2026-09-01, 2026-09-06
    Newell-Daganzo Anti-Bunching Service :done,    p2_2, 2026-09-03, 2026-09-08
    Speed-Floored ETA & k-NN Engine      :done,    p2_3, 2026-09-05, 2026-09-10
    section Phase 3: Mobile Apps
    Flutter Commuter Discovery UI        :done,    p3_1, 2026-09-01, 2026-09-08
    Flutter In-Cab Driver Driving HUD    :done,    p3_2, 2026-09-06, 2026-09-11
    APK Compilation (v1.0.0 & v1.1.0)    :done,    p3_3, 2026-09-10, 2026-09-12
    section Phase 4: Command Center
    React + Leaflet Live Fleet Console   :done,    p4_1, 2026-09-08, 2026-09-12
    DRTS Statutory Export Suite (RPT-01) :done,    p4_2, 2026-09-11, 2026-09-13
    section Phase 5: Field Pilot & Defense
    Road Testing (Station-UB-BBS Mall)   :active,  p5_1, 2026-09-14, 2026-09-21
    Academic Defense & Final Review      :         p5_2, 2026-09-22, 2026-09-28
```

1. **Phase 1 (Database & PostGIS Schema):** Deploy the core schema onto Supabase PostgreSQL. Configure Row Level Security (RLS) policies and seed arterial routes (Route U1, U2, U3, U4).
2. **Phase 2 (FastAPI Telematics & Algorithmic Core):** Implement the dual-tier communication engine. Develop the Newell–Daganzo headway service, the speed-floored ETA engine, and the $k$-NN spatial dispatch module.
3. **Phase 3 (Flutter Mobile Applications):** Build the cross-platform application with dual role switching. Engineer the high-contrast in-cab driver heads-up display (`DrivingMapView`) and the commuter live map.
4. **Phase 4 (Administrative Command Center):** Develop the React 18 / Vite / Leaflet desktop portal for fleet managers and DRTS officials, featuring real-time cluster tracking and statutory reporting.
5. **Phase 5 (Field Corridor Pilot & Academic Defense):** Conduct physical road tests along the Gaborone Station $\leftrightarrow$ University of Botswana $\leftrightarrow$ BBS Mall corridor to validate headway spacing compliance, GPS accuracy under local conditions, and cellular data consumption.

---

> **Academic Defense Note:** This specification document conforms to standard IEEE/ISO/IEC 12207 and 42010 software engineering architectural description standards. It establishes that SmartTransit is fully designed, algorithmically sound, mathematically grounded, and technically feasible for immediate deployment in the public transportation system of Botswana.
