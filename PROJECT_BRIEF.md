# 🚌 SmartTransit — Comprehensive Project & Architecture Brief 🇧🇼

> **Document Type:** Master System Specification & AI Agent Context Primer  
> **Target Audience:** AI Coding Assistants, Systems Architects, Technical Evaluators, and Engineers  
> **Project Repository:** `SmartTransit` (Botswana Intelligent Mobility Platform)  
> **Maintainer / Lead Systems Architect:** Arabang Benville Mothofela (*First Minds*)  

---

## 1. Executive Summary

**SmartTransit** is an intelligent, multi-modal public transit coordination, telematics, and fleet dispatch platform engineered specifically for the paratransit ecosystem of **Botswana and Southern Africa** (focusing initially on Greater Gaborone and key regional corridors including Molepolole, Francistown, Lobatse, and Kanye).

Unlike traditional Western transit systems governed by rigid timetables, African urban transit is informal, dynamic, and paratransit-dominant. Over **85% of motorized daily trips** in Greater Gaborone rely on:
1. **Minibus Combis (14–16 seaters):** Licensed by the Department of Road Transport and Safety (DRTS) along arterial corridors charging a gazetted statutory fare of **BWP 8.00**.
2. **Special Cabs (Sedans / Blue-Plate Taxis):** Point-to-point charters providing first- and last-mile connectivity (BWP 30.00 – 60.00).
3. **Intercity Express Coaches:** Long-distance buses operating out of the Gaborone Central Bus Rank.

SmartTransit bridges the information gap between commuters, drivers, operators, and municipal regulators through an active **Intelligent Transportation System (ITS)** that combines real-time GPS telematics, algorithmic anti-bunching headway control, spatial dispatch, and multi-modal journey planning.

---

## 2. The Core Problems Solved

| Problem in Botswana Transit | Current Reality | SmartTransit Algorithmic Solution |
| :--- | :--- | :--- |
| **Information Blackout** | Commuters experience unpredictable wait times (20–45+ min) with zero real-time visibility. | Real-time GPS map tracking with speed-floored ETA countdowns. |
| **Combi Bunching (Platooning)** | Combis cluster together on high-demand routes, creating long passenger starvation intervals and fuel waste. | **Newell–Daganzo Dynamic Headway Regularization** broadcasting real-time speed advisories (`SLOW DOWN`, `MAINTAIN PACE`, `HOLD 60s`) directly into the driver's cab. |
| **Naive ETA Divergence** | In apps like Google Maps or Vaya, when a combi stops at a traffic light or rank ($v \to 0$), ETA diverges to infinity. | **Speed-Floored Regularizer ($v_{\text{floor}} = 18\text{ km/h}$)** ensuring rock-solid arrival estimates even during prolonged passenger loading dwells. |
| **Fragmented Multi-Modal Trips** | Commuters needing a special cab $\to$ combi $\to$ intercity coach must negotiate three disconnected segments. | **NetworkX Graph-based Journey Planner (Dijkstra algorithm)** coordinating multi-leg transfers and aggregate fares. |
| **Manual Data Entry Fallacy** | Expecting busy combi conductors to manually tap seat counts fails within 48 hours. | **Autonomous Co-Movement Proximity Geofencing**: Boarding is automatically registered when passenger and driver share velocity vectors ($>2\text{ m/s}$) within $20\text{ meters}$. |
| **Lack of Regulatory Telematics** | DRTS and taxi associations have zero digitized data on route capacity, speeding, or demand heatmaps. | **Desktop Command Center (React + Leaflet)** for live fleet oversight, headway compliance monitoring, and statutory CSV/JSON reporting. |

---

## 3. High-Level System Architecture

```mermaid
graph TD
    subgraph Mobile Clients [Flutter Cross-Platform Client]
        CommuterApp[Commuter Mobile Interface<br/>Trip Planning, Hailing, Live Map]
        DriverApp[Driver In-Cab Telematics<br/>GPS Broadcast, Spacing Advisory]
    end

    subgraph Backend Core [Python FastAPI Engine]
        RestAPI[FastAPI REST API Gateway<br/>Auth, Trips, Routes, Gazetted Fares]
        SocketIO[Socket.IO Real-Time Gateway<br/>Bidirectional GPS, Live Telematics]
        HeadwayEngine[Newell-Daganzo Headway Service<br/>Anti-Bunching Regularization]
        DispatchEngine[k-NN Spatial Dispatch Engine<br/>Haversine Nearest-Taxi Matching]
        GraphRouter[Multi-Modal Graph Planner<br/>NetworkX Dijkstra Transfers]
    end

    subgraph Command Center [React Web Dashboard]
        AdminUI[React + Vite + Leaflet Web Console<br/>Live Fleet Map, Heatmaps, DRTS Reports]
    end

    subgraph Data & Cloud Layer [Supabase Cloud PostgreSQL]
        Postgres[(PostgreSQL 15 + PostGIS<br/>Spatial Schemas, RLS Policies)]
        Realtime[(Supabase Realtime Pub/Sub<br/>Database-Level Event Streaming)]
        EdgeFunctions[Deno Edge Functions<br/>Serverless Routing Fallback]
    end

    CommuterApp -->|REST API & WebSockets| Backend Core
    DriverApp -->|GPS Telemetry via Socket.IO| SocketIO
    DriverApp <---|Spacing Advisories| HeadwayEngine
    CommuterApp -->|Direct Fallback Query| Postgres
    AdminUI -->|Socket.IO Telematics Stream| SocketIO
    AdminUI -->|REST Analytics & Exports| RestAPI
    Backend Core -->|Async SQLAlchemy / Pooler| Postgres
```

---

## 4. Repository Structure & Key Components

The repository is structured into four main subsystems:

### 4.1 `smart_transit_app/` (Mobile Application)
* **Framework:** Flutter (Dart), cross-platform for Android & iOS.
* **Pre-built Release Artifacts:** `SmartTransit_v1.0.0.apk` & `SmartTransit_v1.1.0.apk` located in the root directory.
* **Core Modules:**
  * `lib/screens/commuter/`: Commuter journey planner, live vehicle tracking map, ride booking, fare estimator.
  * `lib/screens/driver/`: Driver shift toggle, real-time GPS background locator, passenger hail notification drawer.
  * `lib/screens/driver/spacing_advisory_widget.dart`: Visual headway pacing widget rendering dynamic instructions (`SPEED UP`, `SLOW DOWN`, `MAINTAIN GAP`).
  * `lib/providers/`: State management for authentication, transit telemetry, and Supabase client bindings.
  * `lib/core/theme.dart`: Curated design system tailored with Botswana national colors (sky blue, black, white) and sleek dark-mode glassmorphic aesthetics.

### 4.2 `backend/` (Telematics & Algorithmic Engine)
* **Framework:** Python 3.11+, FastAPI, Uvicorn, Python-SocketIO.
* **Core Modules:**
  * `app/sockets/dispatch.py`: Real-time WebSocket connection lifecycle, GPS coordinate ingestion, driver telemetry broadcasting.
  * `app/services/headway_service.py`: Newell–Daganzo anti-bunching algorithm calculating distance and time headways between successive corridor vehicles.
  * `app/services/ai_orchestrator.py`: Multi-modal journey planning, backward-scheduled arrival estimation, and trip route optimization.
  * `app/services/dispatch_engine.py`: Sub-millisecond $k$-NN spatial search for matching on-demand charter cabs using Haversine spherical geometry.
  * `app/models/` & `app/schemas/`: Pydantic schemas and SQLAlchemy ORM models for `Trip`, `Route`, `Stop`, `Vehicle`, `DriverProfile`, `User`, `TaxiBooking`.
  * `tests/`: Automated unit and integration test suite (`pytest`, `test_headway.py`).

### 4.3 `dashboard/` (Administrative & Regulatory Command Center)
* **Framework:** React 18, Vite, TailwindCSS / Vanilla CSS, Leaflet.js.
* **Features:**
  * Real-time map displaying all moving combis, blue-plate taxis, and active passenger hail pins across Gaborone.
  * Corridor velocity and vehicle spacing telemetry metrics.
  * Passenger demand density heatmaps.
  * Statutory transit reporting (RPT-01 to RPT-05) for DRTS regulatory compliance.

### 4.4 `supabase/` (Database & Edge Layer)
* **Database:** PostgreSQL with PostGIS spatial extensions.
* **Schema:** `supabase/migrations/20260822000000_smarttransit_schema.sql`.
* **Key Tables:** `users`, `driver_profiles`, `vehicles`, `routes`, `stops`, `route_stops`, `trips`, `hails`, `driver_locations`.
* **Security:** Row Level Security (RLS) policies allowing public authenticated read, driver coordinate streaming, and passenger hail creation.

---

## 5. Mathematical Formulations & System Algorithms

### 5.1 Dynamic Headway Spacing Regularization (Anti-Bunching)
To prevent combis from bunching into platoons, the backend calculates the operational time headway $h_i$ of vehicle $i$ relative to lead vehicle $i-1$:
$$h_i = \frac{d_{i-1} - d_i}{\bar{v}}$$
Where $d$ is the curvilinear distance along the corridor and $\bar{v}$ is the historical average corridor speed. The spacing advisory $A_i$ is generated against the target schedule headway $H^*$:
$$A_i = \begin{cases} \text{SLOW DOWN / HOLD } \Delta t & \text{if } h_i < H^* - \epsilon \\ \text{SPEED UP} & \text{if } h_i > H^* + \epsilon \\ \text{MAINTAIN PACE} & \text{otherwise} \end{cases}$$

### 5.2 Speed-Floored ETA Calculation
To prevent mathematical explosion when vehicles dwell at ranks or red lights ($v \to 0$):
$$\text{ETA} = \frac{D_{\text{remaining}}}{\max(v_{\text{instantaneous}}, v_{\text{floor}})} + \sum_{k=1}^{N_{\text{stops}}} t_{\text{dwell}, k}$$
Where $v_{\text{floor}} = 18\text{ km/h}$ (empirically derived from Gaborone arterial traffic) and $t_{\text{dwell}} = 45\text{ seconds}$ per intermediate boarding stop.

### 5.3 Spatial $k$-Nearest Neighbors ($k$-NN) Taxi Dispatch
Calculates spherical great-circle distances using the Haversine formula across active taxi geolocations:
$$d = 2R \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$
Matches the top $k=5$ idle drivers within a $5.0\text{ km}$ geofence and dispatches the hail notification in parallel via WebSockets.

---

## 6. Local Botswana Transit Specifications (Domain Grounding)

* **Arterial Corridors:**
  * Route U1: Gaborone Bus Rank $\leftrightarrow$ University of Botswana (UB) $\leftrightarrow$ BBS Mall
  * Route U2: Gaborone Bus Rank $\leftrightarrow$ Tlokweng
  * Route U3: Gaborone Bus Rank $\leftrightarrow$ Mogoditshane
  * Route U4: Gaborone Bus Rank $\leftrightarrow$ Gaborone West (G-West)
  * Regional Corridors: Gaborone $\leftrightarrow$ Molepolole, Lobatse, Francistown
* **Fare Structures (Botswana Pula - BWP):**
  * Combi Fare: Standard statutory gazetted fare of **BWP 8.00** per one-way trip.
  * Special Cab (Charter): Base fare BWP 30.00 + incremental distance/time surcharges.
  * Intercity Coach: Corridor-distance tiered fares (e.g., Gabs–Francistown ~ BWP 110–140).

---

## 7. How Any AI Agent Should Work With This Codebase

When an AI agent is tasked with adding features, debugging, or writing documentation for SmartTransit:
1. **Never treat it as a generic Western transit app:** Always consider paratransit constraints (low data bandwidth, informal boarding stops, no fixed timetables, driver smartphone GPS rather than fixed vehicle computers).
2. **Preserve the Multi-Modal Model:** Keep the distinct handling between fixed-route combis (headway-regulated) and on-demand special cabs (dispatch-regulated).
3. **Respect the Tech Stack:**
   * Mobile: Flutter / Dart in `smart_transit_app/`.
   * Real-time: FastAPI / Python-SocketIO in `backend/`.
   * Web: React / Leaflet in `dashboard/`.
   * Database: Supabase PostgreSQL + PostGIS in `supabase/`.
4. **Maintain Existing Algorithms:** Do not replace the Newell–Daganzo headway logic or the speed-floored ETA calculation with naive formulas.
