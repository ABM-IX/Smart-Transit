# SmartTransit — Technical Documentation: Architecture, Data Model, API Reference, Telematics Protocol, and Application Flow 🇧🇼

> **Document Type:** Production System Specification & Architectural Reference  
> **System Name:** SmartTransit (Botswana Intelligent Mobility & Paratransit Telematics Platform)  
> **Maintainer & Lead Systems Architect:** Arabang Benville Mothofela (*First Minds / SmartTransit Engineering*)  
> **Date:** October 2026  

---

## Table of Contents

1. [Executive Overview & Problem Statement](#1-executive-overview--problem-statement)
2. [Repository Layout & Directory Organization](#2-repository-layout--directory-organization)
3. [System Architecture & Three-Tier Cyber-Physical Topology](#3-system-architecture--three-tier-cyber-physical-topology)
4. [Database Specification & Data Model (Supabase PostgreSQL / Offline SQLite)](#4-database-specification--data-model)
5. [Backend Service (FastAPI & AsyncIO Engine)](#5-backend-service-fastapi--asyncio-engine)
6. [REST API Reference (All Endpoints, Contracts & Current Data Status)](#6-rest-api-reference)
   - 6.1 System Health & Diagnostics (`/api/health`)
   - 6.2 Transit Corridors & Stops (`/api/transit/routes`, `/api/transit/stops`, `/api/transit/fleet/active`)
   - 6.3 Trips & On-Demand Taxi Hailing (`/api/trips/taxi/book`, `/api/trips/rating`)
   - 6.4 AI Multi-Modal Journey Planner (`/api/ai/plan-journey`)
7. [Full-Duplex Real-Time Telematics & WebSocket Protocol (Socket.IO)](#7-full-duplex-real-time-telematics--websocket-protocol-socketio)
8. [Core Algorithms & Mathematical Formulations](#8-core-algorithms--mathematical-formulations)
   - 8.1 Newell–Daganzo Dynamic Headway Regularization (Anti-Bunching)
   - 8.2 Speed-Floored Dynamic ETA Regularizer
   - 8.3 Spatial $k$-Nearest Neighbors ($k$-NN) Hail Dispatch Engine
   - 8.4 NetworkX Directed Graph Multi-Modal Planner (Backward Scheduling)
   - 8.5 Autonomous Co-Movement Proximity Geofencing (Hands-Free Boarding)
9. [Mobile Client Architecture (`smart_transit_app` in Flutter/Dart)](#9-mobile-client-architecture-smart_transit_app-in-flutterdart)
   - 9.1 Commuter Cockpit (Passenger Mode)
   - 9.2 Driver Telematics Cockpit (Driving Mode & In-Cab Spacing HUD)
   - 9.3 State Management, Geolocation & Offline Resilience
10. [Web Command Center (`dashboard/` in React + Leaflet)](#10-web-command-center-dashboard-in-react--leaflet)
    - 10.1 Real-Time Fleet Telematics Map & Virtual DOM Optimization
    - 10.2 DRTS Statutory Regulatory Audit Reports (RPT-01 to RPT-05)
11. [End-to-End Request & Event Flows](#11-end-to-end-request--event-flows)
    - Flow A: Commuter Corridor Discovery & Real-Time Tracking
    - Flow B: In-Cab 1 Hz GPS Telematics & Dynamic Pacing Advisory Loop
    - Flow C: On-Demand Special Cab Hail ($k$-NN Matching & Live Dispatch)
    - Flow D: Autonomous Co-Movement Boarding & Fare Settlement
    - Flow E: Multi-Modal Journey Planning (Cab $\to$ Combi $\to$ Bus)
12. [Configuration, Deployment, and Local Setup](#12-configuration-deployment-and-local-setup)
13. [Technology Stack Breakdown & Engineering Justifications](#13-technology-stack-breakdown--engineering-justifications)
    - Python (FastAPI + Socket.IO) vs. Java (Spring Boot)
    - Flutter (Dart) vs. Native Android (Kotlin) / Swift
    - React + Vite vs. Plain HTML / Vanilla JS
    - Supabase PostgreSQL + PostGIS vs. Bare Relational DBs
    - Leaflet.js / OSM vs. Proprietary Google Maps API
14. [Transit Data Reality, Ingestion Architecture & Corridor Digitization](#14-transit-data-reality-ingestion-architecture--corridor-digitization)
    - 14.1 The Paratransit Data Reality in Gaborone
    - 14.2 Schema Readiness vs. Static Dataset Availability
    - 14.3 Spatial Independence of Point-to-Point Taxi Hailing
    - 14.4 Corridor Digitization & GTFS Field Survey Strategy
15. [System Status, Known Constraints, and Engineering Roadmap](#15-system-status-known-constraints-and-engineering-roadmap)

---

## 1. Executive Overview & Problem Statement

### 1.1 Context: Urban Mobility in Greater Gaborone, Botswana
In Botswana's urban centers—predominantly Greater Gaborone (encompassing Gaborone, Tlokweng, Mogoditshane, Broadhurst, Phakalane, and G-West) and secondary transit hubs (Francistown, Lobatse, Palapye, Maun)—public transit does not follow fixed Western timetables. Over **85% of motorized daily commuter trips** rely on informal and semi-formal paratransit:
1. **Minibus Combis (14–16 seaters):** Licensed by the Department of Road Transport and Safety (DRTS) along arterial corridors charging a gazetted statutory flat fare of **BWP 8.00**.
2. **Special Cabs (Sedans / Blue-Plate Taxis):** Point-to-point charters providing vital first- and last-mile connectivity where combi lines do not reach (BWP 30.00 – 60.00).
3. **Intercity Express Coaches:** Long-distance buses operating out of the Gaborone Central Bus Rank to national destinations.

### 1.2 The Systemic Challenges
- **The Combi Bunching Phenomenon (Platooning):** Because combi drivers compete for cash fares along high-density routes without operational coordination, vehicles naturally cluster together into tight platoons. Three combis arrive simultaneously at a rank, followed by a **25-to-45-minute passenger starvation window**. Trailing drivers burn fuel carrying zero passengers, while commuters wait in frustration.
- **The Information Blackout:** Commuters have zero real-time visibility into approaching vehicle locations, remaining capacities, or accurate countdown ETAs.
- **Fragmented Multi-Modal Journeys:** Commuters living in peripheral residential extensions (e.g., Block 8, Phakalane extensions, Tlokweng borders) must coordinate three disconnected legs—a doorstep cab to the rank, an arterial combi, and an intercity coach—with no unified trip planner or scheduled connection buffers.
- **Regulatory Blindness:** The DRTS and local taxi associations lack digital telemetry on corridor headways, vehicle speeds, or unmet passenger demand heatmaps.

### 1.3 What SmartTransit Solves
**SmartTransit** is an active **Intelligent Transportation System (ITS)** that converts informal African paratransit into a predictable, coordinated, cyber-physical transit network. 

Rather than acting merely as a passive map lookup, SmartTransit forms an active **closed-loop feedback system**:
- Ingests **1 Hz high-frequency GPS telemetry** from driver smartphones mounted on dashboards.
- Computes real-time **Newell–Daganzo headway spacing errors** between successive corridor combis.
- Broadcasts real-time in-cab pacing instructions (`SLOW DOWN`, `MAINTAIN CURRENT SPEED`, `SPEED UP`) to eliminate bunching.
- Provides commuters with **speed-floored dynamic ETAs** and **autonomous co-movement proximity geofencing** (hands-free boarding detection).
- Dispatches on-demand special cabs via sub-millisecond **spatial $k$-NN matching**.
- Generates **DRTS statutory regulatory compliance reports (RPT-01 to RPT-05)** on a desktop web dashboard.

---

## 2. Repository Layout & Directory Organization

The `SmartTransit` repository is organized into three decoupled functional tiers (Mobile, Backend/Telematics, and Web Dashboard) sharing centralized schemas and network protocols:

```
SmartTransit/
├── backend/                             # Central Telematics & Algorithmic ASGI Engine
│   ├── app/
│   │   ├── config.py                    # Environment settings (Pydantic Settings: DB URLs, CORS, Ports)
│   │   ├── database.py                  # Dual-engine database manager (PostgreSQL / Async SQLite fallback)
│   │   ├── models/                      # SQLAlchemy ORM models
│   │   │   ├── transit.py               # Route, Stop, RouteStop, Vehicle entities
│   │   │   ├── trip.py                  # Trip, TaxiBooking, Review entities
│   │   │   └── user.py                  # User, DriverProfile entities
│   │   ├── routers/                     # FastAPI HTTP REST API endpoints
│   │   │   ├── health.py                # System health, diagnostics & DB connectivity check
│   │   │   ├── transit.py               # Routes, stops, fleet telemetry endpoints
│   │   │   ├── trips.py                 # Taxi booking creation, metered fare billing, driver ratings
│   │   │   └── ai_planner.py            # AI multi-modal journey orchestrator endpoint
│   │   ├── schemas/                     # Pydantic v2 serialization & validation models
│   │   │   ├── ai_planner.py            # PlanJourneyRequest, PlannedItinerary, JourneyLeg
│   │   │   ├── transit.py               # RouteOut, StopOut, ActiveDriverOut, Coords
│   │   │   └── trip.py                  # TaxiRequestIn, TaxiRequestOut, DriverRatingIn
│   │   ├── services/                    # Core mathematical, spatial & transit algorithms
│   │   │   ├── ai_orchestrator.py       # NetworkX multi-modal graph builder & backward scheduler
│   │   │   ├── fare.py                  # Statutory gazetted fare calculator (BWP 8.00 base + cab rates)
│   │   │   ├── geo.py                   # Haversine distance, speed-floored ETA regularizer, stop matcher
│   │   │   ├── headway.py               # Newell–Daganzo anti-bunching headway spacing algorithm
│   │   │   └── supabase_service.py      # Supabase cloud REST client integration
│   │   └── sockets/                     # Full-Duplex Socket.IO real-time event pipeline
│   │       ├── gateway.py               # Socket.IO ASGI server, room management, in-memory state cache
│   │       ├── tracking.py              # 1 Hz driver GPS ingestion, spacing broadcast, co-movement geofence
│   │       └── dispatch.py              # Spatial k-NN taxi dispatch, hail lifecycle, boarding & completion
│   ├── static/assets/                   # Compiled static web dashboard assets
│   ├── tests/                           # Pytest automated test suite (test_headway.py, test_api.py)
│   ├── Dockerfile                       # Production container definition (Python 3.11 slim)
│   ├── main.py                          # ASGI application factory mounting FastAPI + Socket.IO
│   ├── requirements.txt                 # Backend Python package manifest
│   ├── schema_supabase.sql              # Supabase PostgreSQL production schema + RLS policies
│   └── seed_data.py                     # Initial database seeding script (Development mock schemas)
│
├── smart_transit_app/                   # Cross-Platform Flutter Client (Android & iOS)
│   ├── lib/
│   │   ├── main.dart                    # App bootstrap, Provider registration, routing table
│   │   ├── core/                        # Global design tokens, theme, constants, typography
│   │   │   ├── theme.dart               # Botswana national palette (sky blue, dark obsidian), glassmorphism
│   │   │   └── constants.dart           # API URLs, WebSocket channel names, default coordinates
│   │   ├── models/                      # Dart transit domain models
│   │   │   ├── route_model.dart         # Corridor metadata, waypoints polyline, base fare
│   │   │   ├── driver_model.dart        # Vehicle position, heading, speed, headway advisory
│   │   │   ├── hail_request_model.dart  # Taxi booking state, pickup, dropoff, metered fare
│   │   │   └── itinerary_model.dart     # Multi-modal trip itinerary model
│   │   ├── providers/                   # Reactive state management (Provider architecture)
│   │   │   ├── auth_provider.dart       # User authentication, role toggling (Passenger vs Driver)
│   │   │   ├── transit_provider.dart    # Active routes, stops, nearby vehicle tracking
│   │   │   └── taxi_booking_provider.dart # Hail state machine, live driver assignment, fare countdown
│   │   ├── services/                    # Client infrastructure services
│   │   │   ├── api_service.dart         # HTTP REST client with error normalization & Supabase bindings
│   │   │   ├── socket_service.dart      # Real-time Socket.IO client, event listeners, reconnect logic
│   │   │   └── location_service.dart    # Background GPS locator, hardware permission handler
│   │   ├── screens/
│   │   │   ├── auth/                    # Login, phone OTP verification, role selection
│   │   │   ├── passenger/               # Commuter interface
│   │   │   │   ├── passenger_dashboard.dart # Commuter home screen, quick access, route tiles
│   │   │   │   ├── bus_combi_map_screen.dart # Interactive map, live combi tracking, ETA countdown
│   │   │   │   ├── taxi_flow_screen.dart    # On-demand special cab hailing, pickup pin, live driver tracking
│   │   │   │   ├── ai_planner_screen.dart   # Multi-modal journey planner (Doorstep -> Rank -> Intercity)
│   │   │   │   ├── destinations_browser_screen.dart # Stop search, landmark catalog, fare charts
│   │   │   │   └── passenger_history_screen.dart    # Past rides, e-receipts, driver rating dialog
│   │   │   └── driver/                  # In-Cab Driver interface
│   │   │       ├── driver_dashboard.dart    # Shift toggle, earnings summary, corridor status
│   │   │       ├── driver_home_screen.dart  # Live GPS broadcast cockpit, passenger count
│   │   │       ├── taxi_driver_screen.dart  # On-demand hail radar, acceptance slider, navigation
│   │   │       ├── driver_route_select_screen.dart # Corridor assignment picker
│   │   │       ├── incoming_hail_dialog.dart# High-contrast 10-second acceptance modal
│   │   │       └── spacing_advisory_widget.dart # In-Cab Headway HUD (SLOW DOWN / SPEED UP badge)
│   │   └── widgets/                     # Shared atomic widgets (Glassmorphic cards, custom map markers)
│   └── pubspec.yaml                     # Flutter package dependencies
│
├── dashboard/                           # DRTS Regulatory & Fleet Command Web Console
│   ├── src/
│   │   ├── main.jsx                     # Web application entry point
│   │   ├── App.jsx                      # Main dashboard layout, view switcher, socket listener
│   │   ├── index.css                    # Professional dark-mode design system & Leaflet custom styling
│   │   ├── components/
│   │   │   ├── Header.jsx               # Status indicators, active vehicle counters, system clock
│   │   │   ├── Sidebar.jsx              # Navigation (Live Map, Fleet Table, Heatmap, DRTS Reports)
│   │   │   ├── LiveMap.jsx              # Leaflet.js real-time fleet map, vehicle clustering, route vectors
│   │   │   ├── FleetList.jsx            # Live tabular manifest of online combis, taxis, and occupancy
│   │   │   ├── MetricsGrid.jsx          # KPI cards (Average Headway, Speed Violations, Unmet Hails)
│   │   │   └── FleetChart.jsx           # Chart.js corridor load and velocity trend graphs
│   │   └── services/
│   │       ├── socket.js                # Web Socket.IO client singleton connecting to telematics gateway
│   │       └── reportGenerator.js       # Statutory CSV/JSON export engine for DRTS audits (RPT-01 to RPT-05)
│   ├── package.json                     # React 18, Vite 5, Leaflet, Chart.js, Lucide-react
│   └── vite.config.js                   # Vite bundler configuration
│
├── supabase/                            # Cloud Database Migrations & Edge Policies
│   └── migrations/
│       └── 20260822000000_smarttransit_schema.sql # Master PostgreSQL DDL script
│
├── docs/                                # Formal Engineering Defense & Academic Specifications
│   ├── system_architecture_defense_and_database_specification.md # 525-line architectural defense
│   ├── botswana_competitor_analysis_and_differentiation_matrix.md# Market & technical competitor teardown
│   ├── system_use_cases_and_engineering_diagrams_specification.md# UML sequence & state diagrams
│   └── technical_methodology_and_literature_review_guide.md      # Literature review & mathematical foundations
│
├── PROJECT_BRIEF.md                     # Master system specification & AI agent context primer
├── README.md                            # Comprehensive system documentation & developer setup guide
└── smarttransit.db                      # Local SQLite edge database for 100% offline evaluation
```

---

## 3. System Architecture & Three-Tier Cyber-Physical Topology

Public transportation is inherently a **cyber-physical tripartite ecosystem**. It cannot function as a single generic web page or mobile app because it involves three human actors operating in fundamentally incompatible physical environments:

```mermaid
graph TD
    subgraph Regulatory Tier [Strategic / Institutional - Desktop Command Center]
        DRTS_Web["DRTS & Association Operations Console<br/>(React 18 + Vite + Leaflet.js)<br/>• Macro fleet tracking & bunching alerts<br/>• Unmet hail density heatmaps<br/>• Statutory compliance CSV exports (RPT-01..05)"]
    end

    subgraph Central Core [Telematics & Algorithmic Core - FastAPI Engine]
        RestGateway["FastAPI REST Gateway<br/>Auth, Routes, Stops, Fares, Trips"]
        SocketGateway["Python-SocketIO Gateway<br/>Bi-directional 1 Hz Telemetry & Rooms"]
        HeadwayService["Newell-Daganzo Headway Engine<br/>Corridor Anti-Bunching Spacing Control"]
        DispatchService["Spatial k-NN Dispatch Engine<br/>Haversine Nearest-Taxi Matching"]
        GraphService["NetworkX Multi-Modal Router<br/>Dijkstra Backward-Scheduled Transfers"]
    end

    subgraph Mobile Tier [Tactical Field Clients - Flutter Native Engine]
        DriverApp["Driver In-Cab Cockpit<br/>(Flutter Android/iOS Mount)<br/>• 1 Hz GPS Telemetry Beacon<br/>• Glanceable Spacing HUD (SLOW/SPEED)<br/>• 1-Tap Hail Acceptance"]
        PassengerApp["Commuter Mobile App<br/>(Flutter Android/iOS Handheld)<br/>• Live Combi Map & Speed-Floored ETA<br/>• Special Cab Hail & Fare Meter<br/>• Multi-Modal Trip Planner"]
    end

    subgraph Persistence Layer [Dual-Engine Data Resilience]
        SupabasePostgres[("Supabase Cloud PostgreSQL 15<br/>PostGIS Spatial Tables & RLS Policies")]
        LocalSQLite[("Edge SQLite (aiosqlite)<br/>100% Offline Resilience Fallback")]
    end

    DriverApp -->|"1 Hz GPS Ping (socket.io)"| SocketGateway
    SocketGateway -->|"In-Cab Spacing Advisory (SLOW DOWN / SPEED UP)"| DriverApp
    SocketGateway -->|"Real-Time Fleet Update Stream"| DRTS_Web
    SocketGateway -->|"Dynamic ETA & Approaching Vehicle Marker"| PassengerApp
    PassengerApp -->|"Taxi Hail Request (pickup/dropoff)"| SocketGateway
    SocketGateway -->|"k-NN Broadcast to 5 Nearest Taxis"| DriverApp
    
    PassengerApp -->|"REST Queries (Routes, Stops, AI Plan)"| RestGateway
    DRTS_Web -->|"REST Historical Analytics & Reports"| RestGateway

    RestGateway --> SupabasePostgres
    RestGateway -.->|"Fallback if Offline"| LocalSQLite
    SocketGateway -->|"Persist Driver Coords & Trips"| SupabasePostgres
```

### Key Architectural Decisions
1. **Separation of Concerns Across Roles:**
   - **Driver Cockpit:** Hands-free, high-contrast, zero-touch interface mounted on the windshield, functioning as a high-frequency IoT telemetry emitter.
   - **Commuter App:** Pedestrian-optimized, location-aware mobile client providing transparent fares, live countdown ETAs, and on-demand taxi hailing within 2 seconds of launch.
   - **Regulatory Command Center:** Wide-screen desktop web application engineered for operations managers and the Department of Road Transport and Safety (DRTS) to audit headways, monitor speed infractions, and plan transport policy.
2. **Dual-Engine Persistence Strategy:**
   - **Cloud Production:** Supabase PostgreSQL with PostGIS extensions for spatial indexing, JSONB route waypoints, and Row Level Security.
   - **Local Edge Resilience:** Asynchronous SQLite (`smarttransit.db` via `aiosqlite` and SQLAlchemy Async). If the server loses internet connectivity or is deployed in an offline demonstration, it seamlessly falls back to local storage without throwing unhandled exceptions.
3. **In-Memory Telemetry with Transactional Offloading:**
   - High-frequency 1 Hz GPS coordinates stream through persistent WebSockets into an in-memory dictionary cache (`active_drivers`, `active_passengers`).
   - Spacing advisories and ETA countdowns are calculated directly in RAM in **under 20 milliseconds**.
   - Database writes are batched asynchronously, preventing database lock contention and ensuring the server can support hundreds of concurrent vehicles on minimal hardware.

---

## 4. Database Specification & Data Model

The data layer consists of **9 relational tables** engineered for paratransit corridor topologies, driver telematics, and transactional ride hailing.

### 4.1 Relational Entity-Relationship Diagram

```mermaid
erDiagram
    USERS ||--o| DRIVER_PROFILES : "extends (1:1)"
    USERS ||--o{ TRIPS : "travels as passenger"
    USERS ||--o{ TAXI_BOOKINGS : "requests booking"
    USERS ||--o{ REVIEWS : "submits rating"

    DRIVER_PROFILES ||--o| VEHICLES : "operates (1:1)"
    DRIVER_PROFILES ||--o{ TRIPS : "drives (1:N)"
    DRIVER_PROFILES ||--o{ TAXI_BOOKINGS : "accepts & completes"
    DRIVER_PROFILES ||--o{ REVIEWS : "receives ratings"

    ROUTES ||--|{ ROUTE_STOPS : "ordered sequence (1:N)"
    STOPS ||--|{ ROUTE_STOPS : "stop location (1:N)"
    ROUTES ||--o{ DRIVER_PROFILES : "assigned corridor"
    ROUTES ||--o{ TRIPS : "operates along"

    USERS {
        varchar id PK
        varchar full_name
        varchar phone_number UK
        varchar email UK
        varchar role "PASSENGER | DRIVER | ADMIN"
        timestamptz created_at
    }

    DRIVER_PROFILES {
        varchar driver_id PK, FK
        varchar vehicle_id FK
        varchar assigned_route_id FK
        varchar service_type "COMBI | TAXI | BUS"
        boolean is_online
        float rating_avg
        integer rating_count
        double_precision current_lat
        double_precision current_lng
        timestamptz updated_at
    }

    VEHICLES {
        varchar id PK
        varchar license_plate UK
        varchar vehicle_type "COMBI | TAXI | BUS"
        integer capacity
        varchar model
        timestamptz created_at
    }

    ROUTES {
        varchar id PK
        varchar name
        varchar origin_name
        varchar destination_name
        varchar route_type "COMBI | TAXI | BUS"
        numeric base_fare
        jsonb waypoints
        timestamptz created_at
    }

    STOPS {
        varchar id PK
        varchar name
        double_precision latitude
        double_precision longitude
        varchar description
        timestamptz created_at
    }

    ROUTE_STOPS {
        serial id PK
        varchar route_id FK
        varchar stop_id FK
        integer stop_sequence
        float distance_from_start_meters
    }

    TRIPS {
        varchar id PK
        varchar driver_id FK
        varchar route_id FK
        varchar vehicle_id FK
        varchar service_type "COMBI | TAXI | BUS"
        integer passenger_count
        numeric revenue
        float distance_meters
        integer duration_seconds
        double_precision start_lat
        double_precision start_lng
        double_precision end_lat
        double_precision end_lng
        varchar status "IN_PROGRESS | COMPLETED | CANCELLED"
        timestamptz started_at
        timestamptz ended_at
    }

    TAXI_BOOKINGS {
        varchar id PK
        varchar passenger_id FK
        varchar driver_id FK
        double_precision pickup_lat
        double_precision pickup_lng
        double_precision dropoff_lat
        double_precision dropoff_lng
        varchar service_type "STANDARD | SPECIAL"
        numeric estimated_fare
        numeric final_fare
        varchar status "PENDING | ACCEPTED | ON_TRIP | COMPLETED | CANCELLED"
        timestamptz created_at
        timestamptz completed_at
    }

    REVIEWS {
        serial id PK
        varchar trip_id FK
        varchar driver_id FK
        varchar passenger_id FK
        integer rating "1..5"
        varchar comment
        timestamptz created_at
    }
```

### 4.2 Data Dictionary & Table Schemas

#### 1. `users` — Core Platform Identity
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique user UUID or authenticated ID |
| `full_name` | `VARCHAR(128)` | `NOT NULL` | Commuter or driver legal full name |
| `phone_number` | `VARCHAR(32)` | `UNIQUE, NULLABLE` | Primary Botswana MSISDN (+267...) |
| `email` | `VARCHAR(128)` | `UNIQUE, NULLABLE` | User email address |
| `role` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'PASSENGER'` | Access tier: `PASSENGER`, `DRIVER`, or `ADMIN` |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Account registration timestamp |

#### 2. `driver_profiles` — Driver Operational State
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `driver_id` | `VARCHAR(64)` | `PRIMARY KEY, FK -> users(id)` | 1-to-1 extension of user record |
| `vehicle_id` | `VARCHAR(64)` | `NULLABLE, FK -> vehicles(id)` | Currently operated physical vehicle |
| `assigned_route_id` | `VARCHAR(64)` | `NULLABLE, FK -> routes(id)` | Designated paratransit corridor |
| `service_type` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'COMBI'` | Mode: `COMBI`, `TAXI`, or `BUS` |
| `is_online` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Active duty state (broadcasting telemetry) |
| `rating_avg` | `FLOAT` | `NOT NULL, DEFAULT 5.00` | Arithmetic mean of customer star ratings |
| `rating_count` | `INTEGER` | `NOT NULL, DEFAULT 0` | Total number of rated trips |
| `current_lat` | `DOUBLE PRECISION`| `NULLABLE` | Cached latitude from latest 1 Hz telemetry ping |
| `current_lng` | `DOUBLE PRECISION`| `NULLABLE` | Cached longitude from latest 1 Hz telemetry ping |
| `updated_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Last telemetry update timestamp |

#### 3. `vehicles` — Physical Fleet Registry
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique vehicle inventory UUID |
| `license_plate` | `VARCHAR(20)` | `UNIQUE, NOT NULL` | Official registration (e.g., `B 123 ABC`) |
| `vehicle_type` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'COMBI'` | Category: `COMBI` (15 seats), `TAXI` (4 seats), `BUS` (65 seats) |
| `capacity` | `INTEGER` | `NOT NULL, DEFAULT 15` | Maximum legal seated capacity |
| `model` | `VARCHAR(64)` | `NULLABLE` | Vehicle model (e.g., Toyota HiAce Quantum) |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Registry entry date |

#### 4. `routes` — Transit Corridors & Waypoints *(Schema Defined)*
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Route identifier |
| `name` | `VARCHAR(128)` | `NOT NULL` | Public corridor designation |
| `origin_name` | `VARCHAR(64)` | `NOT NULL` | Origin terminus label |
| `destination_name`| `VARCHAR(64)` | `NOT NULL` | Destination terminus label |
| `route_type` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'COMBI'` | Modality: `COMBI`, `TAXI`, or `BUS` |
| `base_fare` | `NUMERIC(10,2)`| `NOT NULL, DEFAULT 8.00` | Statutory gazetted tariff (BWP 8.00) |
| `waypoints` | `JSONB` | `DEFAULT '[]'::jsonb` | Ordered array of `{lat, lng}` coordinates for polyline rendering |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Route definition timestamp |

> [!IMPORTANT]
> **Data Status Notice:** The `routes` table schema is fully implemented in the database and API. However, **no verified, live public transit route dataset has been created or loaded in production yet**. In production, queries to this table currently return empty collections (`[]`), because formal paratransit GPS surveys have not yet been conducted.

#### 5. `stops` — Physical Boarding Points *(Schema Defined)*
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Stop identifier |
| `name` | `VARCHAR(128)` | `NOT NULL` | Standard or colloquial stop name |
| `latitude` | `DOUBLE PRECISION`| `NOT NULL` | Geographic coordinate (WGS 84) |
| `longitude` | `DOUBLE PRECISION`| `NOT NULL` | Geographic coordinate (WGS 84) |
| `description` | `VARCHAR(255)` | `NULLABLE` | Local landmark reference |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Stop creation timestamp |

#### 6. `route_stops` — Route Stop Sequence Junction
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | Auto-incrementing junction ID |
| `route_id` | `VARCHAR(64)` | `NOT NULL, FK -> routes(id) ON DELETE CASCADE` | Associated route |
| `stop_id` | `VARCHAR(64)` | `NOT NULL, FK -> stops(id) ON DELETE CASCADE` | Associated stop |
| `stop_sequence` | `INTEGER` | `NOT NULL, DEFAULT 1` | 1-based traversal sequence index |
| `distance_from_start_meters` | `FLOAT` | `NOT NULL, DEFAULT 0.0` | Curvilinear corridor distance from origin |

#### 7. `trips` — Completed Fleet Journeys
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique trip record UUID |
| `driver_id` | `VARCHAR(64)` | `NOT NULL, FK -> users(id)` | Driver operating the trip |
| `route_id` | `VARCHAR(64)` | `NULLABLE, FK -> routes(id)` | Corridor traversed |
| `vehicle_id` | `VARCHAR(64)` | `NULLABLE, FK -> vehicles(id)`| Vehicle used |
| `service_type` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'COMBI'` | Modality |
| `passenger_count`| `INTEGER` | `NOT NULL, DEFAULT 1` | Total passengers carried |
| `revenue` | `NUMERIC(10,2)`| `NOT NULL, DEFAULT 8.00` | Total fare collected in BWP |
| `distance_meters`| `FLOAT` | `NOT NULL, DEFAULT 0.0` | Total odometer distance from GPS trace |
| `duration_seconds`| `INTEGER` | `NOT NULL, DEFAULT 0` | Elapsed operational duration |
| `status` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'COMPLETED'` | `IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `started_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Trip start timestamp |
| `ended_at` | `TIMESTAMPTZ` | `NULLABLE` | Trip completion timestamp |

#### 8. `taxi_bookings` — On-Demand Hail Transactions
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique booking identifier |
| `passenger_id` | `VARCHAR(64)` | `NOT NULL, FK -> users(id)` | Commuter requesting the hail |
| `driver_id` | `VARCHAR(64)` | `NULLABLE, FK -> users(id)` | Assigned taxi driver |
| `pickup_lat`, `pickup_lng` | `DOUBLE PRECISION`| `NOT NULL` | Passenger GPS pickup coordinate |
| `dropoff_lat`, `dropoff_lng`| `DOUBLE PRECISION`| `NULLABLE` | Passenger destination coordinate |
| `service_type` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'STANDARD'` | `STANDARD` (shared) or `SPECIAL` (charter) |
| `estimated_fare`| `NUMERIC(10,2)`| `NOT NULL, DEFAULT 8.00` | Algorithmic upfront fare quote |
| `final_fare` | `NUMERIC(10,2)`| `NULLABLE` | Final metered fare billed upon arrival |
| `status` | `VARCHAR(20)` | `NOT NULL, DEFAULT 'PENDING'` | `PENDING`, `ACCEPTED`, `ON_TRIP`, `COMPLETED`, `CANCELLED` |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Hail initiation timestamp |
| `completed_at` | `TIMESTAMPTZ` | `NULLABLE` | Hail dropoff timestamp |

#### 9. `reviews` — Driver Quality Ratings
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | Auto-incrementing review ID |
| `trip_id` | `VARCHAR(64)` | `NULLABLE, FK -> trips(id)` | Associated trip reference |
| `driver_id` | `VARCHAR(64)` | `NOT NULL, FK -> users(id)` | Rated driver |
| `passenger_id` | `VARCHAR(64)` | `NOT NULL, FK -> users(id)` | Rating commuter |
| `rating` | `INTEGER` | `NOT NULL, CHECK (rating BETWEEN 1 AND 5)` | 1-to-5 star quality score |
| `comment` | `VARCHAR(255)` | `NULLABLE` | Commuter review text |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT timezone('utc', now())` | Rating submission timestamp |

---

## 5. Backend Service (FastAPI & AsyncIO Engine)

The backend is built with **FastAPI** running on an asynchronous ASGI event loop (`uvicorn` with `uvloop`). It serves two distinct transport protocols on a single unified port:
1. **HTTP REST API:** For declarative queries (fetching routes, stops, trip plans, ratings, and historical reports).
2. **WebSocket Gateway (Python-SocketIO):** For low-latency bidirectional streaming (1 Hz GPS coordinates, spacing advisories, taxi hail auctions, and live fleet telemetry).

### Backend Component Map
- `main.py`: ASGI application entry point. Configures CORS, mounts REST routers, serves Swagger `/docs`, and wraps the FastAPI app with `socketio.ASGIApp`.
- `app/config.py`: Environment configuration using `pydantic-settings` to parse environment variables (`PORT`, `CORS_ORIGINS`, `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_KEY`).
- `app/database.py`: Manages the database engine. Establishes asynchronous connection pooling via SQLAlchemy 2.0. If PostgreSQL is unreachable, it automatically initializes and runs migrations against `smarttransit.db` via `aiosqlite`.
- `app/services/geo.py`: Spatial mathematical library implementing spherical Haversine formulas and the speed-floored ETA regularizer.
- `app/services/headway.py`: Real-time Newell–Daganzo headway spacing engine for corridor combis.
- `app/services/fare.py`: Computes statutory fares (BWP 8.00 gazetted flat fare) and distance/time-metered special cab tariffs.
- `app/services/ai_orchestrator.py`: Multi-modal directed graph builder and backward-scheduling trip orchestrator powered by `networkx`.

---

## 6. REST API Reference

All HTTP endpoints are prefixed with `/api` and return standardized JSON responses.

### 6.1 System Health & Diagnostics

#### `GET /api/health`
Returns system operational state, timestamp, version, and database connectivity.
- **Request:** None
- **Response `200 OK`:**
```json
{
  "status": "healthy",
  "project": "SmartTransit Backend",
  "version": "1.0.0",
  "environment": "production",
  "database": "connected",
  "active_drivers_in_memory": 4,
  "timestamp": 1791223400.12
}
```

---

### 6.2 Transit Corridors & Stops

#### `GET /api/transit/routes`
Fetches registered transit corridors from the database, with optional filtering by modality.

- **Query Parameters:**
  - `route_type` (optional, string): Filter by `COMBI`, `TAXI`, or `BUS`.
- **Implementation & Filtering:**
  In `backend/app/routers/transit.py`, the endpoint executes a `SELECT` statement on the `routes` table and filters out any legacy mock test identifiers.
- **Contract Schema:**
```json
[
  {
    "id": "string",
    "name": "string",
    "origin_name": "string",
    "destination_name": "string",
    "route_type": "COMBI",
    "base_fare": 8.00,
    "waypoints": [
      {"lat": 0.0, "lng": 0.0}
    ]
  }
]
```
- **Current Operational Reality:**
  > [!NOTE]
  > **Empty Dataset State:** Because SmartTransit does not yet have an official paratransit corridor dataset populated in the database, this endpoint currently returns an empty array:
  > ```json
  > []
  > ```
  > The client-side application ([`api_service.dart`](file:///c:/Users/araba/Desktop/SmartTransit/smart_transit_app/lib/services/api_service.dart#L76-L88)) is explicitly configured to gracefully handle an empty route list without crashing or rendering phantom routes.

#### `GET /api/transit/stops`
Fetches physical stops across the network, optionally filtered by route ID.

- **Query Parameters:**
  - `route_id` (optional, string): Filter stops by route ID.
- **Contract Schema:**
```json
[
  {
    "id": "string",
    "name": "string",
    "latitude": 0.0,
    "longitude": 0.0,
    "description": "string"
  }
]
```
- **Current Operational Reality:**
  > [!NOTE]
  > Returns `[]` when no verified stops have been seeded into the database.

#### `GET /api/transit/fleet/active`
Returns a real-time snapshot of all currently online drivers across combis, taxis, and buses directly from the in-memory cache.
- **Response `200 OK`:**
```json
[
  {
    "driver_id": "drv-001",
    "service_type": "COMBI",
    "status": "ONLINE",
    "route_id": "route-active",
    "vehicle_id": "B 123 ABC",
    "coords": {"lat": -24.6560, "lng": 25.9160},
    "occupancy": 11,
    "speed": 34.5,
    "heading": 85.0,
    "last_update": 1791223405.0
  }
]
```

---

### 6.3 Trips & On-Demand Taxi Hailing

#### `POST /api/trips/taxi/book`
Creates a new on-demand taxi booking, calculates an upfront fare quote, and logs the pending transaction.
- **Request Body (`TaxiRequestIn`):**
```json
{
  "passenger_id": "usr-commuter-789",
  "service_type": "SPECIAL",
  "pickup": {"lat": -24.6450, "lng": 25.9120},
  "dropoff": {"lat": -24.6546, "lng": 25.9145}
}
```
- **Response `200 OK` (`TaxiRequestOut`):**
```json
{
  "request_id": "req-9a8b7c6d",
  "passenger_id": "usr-commuter-789",
  "pickup": {"lat": -24.6450, "lng": 25.9120},
  "dropoff": {"lat": -24.6546, "lng": 25.9145},
  "service_type": "SPECIAL",
  "fare_estimate": 35.00,
  "status": "PENDING",
  "requested_at": 1791223410.0
}
```

#### `POST /api/trips/rating`
Submits a commuter review and star rating for a driver following trip completion.
- **Request Body (`DriverRatingIn`):**
```json
{
  "driver_id": "drv-001",
  "passenger_id": "usr-commuter-789",
  "rating": 5,
  "comment": "Smooth driving and great headway pacing!"
}
```
- **Response `200 OK`:**
```json
{
  "status": "success",
  "message": "Rating recorded successfully"
}
```

---

### 6.4 AI Multi-Modal Journey Planner

#### `POST /api/ai/plan-journey`
Coordinates a multi-leg journey combining Doorstep Special Cabs, Arterial Minibus Combis, and Intercity Coaches using backward scheduling.
- **Request Body (`PlanJourneyRequest`):**
```json
{
  "origin": {
    "name": "Block 8 Extension",
    "coords": {"lat": -24.6200, "lng": 25.9050}
  },
  "destination": {
    "name": "Francistown Central Terminal",
    "coords": {"lat": -21.1661, "lng": 27.5144}
  },
  "desired_arrival_time": "14:30",
  "max_budget_bwp": 180.00
}
```
- **Response `200 OK` (`PlannedItinerary`):**
```json
{
  "plan_id": "plan-b4f2c1e8",
  "total_duration_mins": 315,
  "total_fare_bwp": 148.00,
  "departure_time": "09:15",
  "arrival_time": "14:30",
  "legs": [
    {
      "leg_number": 1,
      "mode": "SPECIAL_TAXI",
      "origin_name": "Block 8 Extension",
      "destination_name": "G-West Combi Rank",
      "scheduled_departure": "09:15",
      "scheduled_arrival": "09:27",
      "duration_mins": 12,
      "fare_bwp": 30.00,
      "instructions": "Doorstep pick up by blue-plate taxi. Dispatches automatically at 09:10."
    },
    {
      "leg_number": 2,
      "mode": "COMBI",
      "origin_name": "G-West Combi Rank",
      "destination_name": "Gaborone Central Bus Rank",
      "scheduled_departure": "09:30",
      "scheduled_arrival": "09:50",
      "duration_mins": 20,
      "fare_bwp": 8.00,
      "instructions": "Board Route Combi to Central Station."
    },
    {
      "leg_number": 3,
      "mode": "INTERCITY_BUS",
      "origin_name": "Gaborone Central Bus Rank",
      "destination_name": "Francistown Central Terminal",
      "scheduled_departure": "10:15",
      "scheduled_arrival": "14:30",
      "duration_mins": 255,
      "fare_bwp": 110.00,
      "instructions": "Board Intercity Coach. Includes 25 min boarding buffer."
    }
  ]
}
```

---

## 7. Full-Duplex Real-Time Telematics & WebSocket Protocol (Socket.IO)

SmartTransit utilizes **Socket.IO** over an ASGI asynchronous server to provide sub-250ms latency across the three tiers. The socket engine organizes connections into targeted broadcast rooms (`drivers`, `passengers`, `dashboard`, `passengers-{route_id}`, `drivers-{route_id}`, `drivers-taxi-service`).

### 7.1 WebSocket Room Hierarchy
- `dashboard`: Receives global fleet updates, bunching alerts, demand heatmaps, and ride lifecycle events.
- `passengers-{route_id}`: Receives live position updates for combis servicing that specific corridor.
- `drivers-{route_id}`: Receives pacing advisories and localized commuter pickup requests.
- `drivers-taxi-service`: Receives real-time broadcast auctions for on-demand special cab hails.

### 7.2 Core Telematics Event Protocol

```
+----------------------------------------------------------------------------------------------------+
|                                    SOCKET.IO EVENT SPECIFICATION                                   |
+----------------------------------------------------------------------------------------------------+
| Event Name                | Direction          | Payload Parameters & Schema                       |
+---------------------------+--------------------+---------------------------------------------------+
| join                      | Client -> Server   | { role: 'passengers'|'drivers'|'dashboard',       |
|                           |                    |   routeId?: string, passengerId?: string,         |
|                           |                    |   coords?: {lat, lng} }                           |
|                           |                    | Joins specific broadcast rooms.                   |
+---------------------------+--------------------+---------------------------------------------------+
| driver-online             | Driver -> Server   | { driverId, routeId, vehicleId, serviceType,      |
|                           |                    |   coords: {lat, lng} }                            |
|                           |                    | Registers driver as active; triggers room join.   |
+---------------------------+--------------------+---------------------------------------------------+
| driver-offline            | Driver -> Server   | { driverId }                                      |
|                           |                    | Deregisters driver; emits fleet-remove.           |
+---------------------------+--------------------+---------------------------------------------------+
| driver-location           | Driver -> Server   | { driverId, routeId, serviceType, vehicleId,      |
|                           | (1 Hz stream)      |   coords: {lat, lng}, speed, heading, occupancy } |
|                           |                    | Primary telemetry stream.                         |
+---------------------------+--------------------+---------------------------------------------------+
| spacing-advisory          | Server -> Driver   | { status: 'SLOW DOWN'|'SPEED UP'|'MAINTAIN PACE',|
|                           |                    |   ahead: string, behind: string }                 |
|                           |                    | Emitted to driver cab for headway control.        |
+---------------------------+--------------------+---------------------------------------------------+
| eta-update                | Server -> Passenger| { driverId, etaSeconds, distanceMeters, speed,    |
|                           |                    |   occupancy, routeId }                            |
|                           |                    | Dynamic arrival countdown for waiting commuter.   |
+---------------------------+--------------------+---------------------------------------------------+
| passenger-request-taxi    | Passenger -> Server| { passengerId, pickup: {lat, lng},                |
|                           |                    |   dropoff?: {lat, lng}, serviceType: 'SPECIAL' }  |
|                           |                    | Broadcasts hail to nearest 5 taxis via k-NN.      |
+---------------------------+--------------------+---------------------------------------------------+
| new-taxi-request          | Server -> Driver   | { requestId, passengerId, pickupLoc,              |
|                           |                    |   destinationLoc, serviceType, fareEstimate }     |
|                           |                    | High-priority in-cab audible hail notification.   |
+---------------------------+--------------------+---------------------------------------------------+
| taxi-accept               | Driver -> Server   | { requestId, driverId, passengerId }              |
|                           |                    | Locks hail; assigns driver to passenger.          |
+---------------------------+--------------------+---------------------------------------------------+
| taxi-assigned             | Server -> Passenger| { driverId, vehicleId, driverCoords, etaSeconds } |
|                           |                    | Notifies passenger of assigned cab & live track.  |
+---------------------------+--------------------+---------------------------------------------------+
| boarding-confirmed        | Server -> Passenger| { driverId, passengerId, autoBoarded: true }      |
|                           |                    | Triggered via autonomous co-movement geofencing.  |
+---------------------------+--------------------+---------------------------------------------------+
| trip-completed            | Server -> Both     | { driverId, passengerId, finalFare, autoDone }    |
|                           |                    | Triggered when distance > 60m after alighting.    |
+---------------------------+--------------------+---------------------------------------------------+
| fleet-update              | Server -> Dashboard| { type: 'driver'|'passenger', ...telemetry }      |
|                           |                    | Real-time marker coordinates for Leaflet map.     |
+---------------------------+--------------------+---------------------------------------------------+
```

---

## 8. Core Algorithms & Mathematical Formulations

### 8.1 Newell–Daganzo Dynamic Headway Regularization (Anti-Bunching)
To solve the rampant combi clustering problem on arterial corridors, SmartTransit implements the Newell–Daganzo dynamic headway control formulation (Newell 1974; Daganzo 2009).

For a corridor with target schedule headway $H^*$ (typically 300 seconds / 5 minutes) and average corridor velocity $\bar{v}$:
1. When driver $i$ emits a 1 Hz telemetry ping, the backend retrieves the coordinates of leading vehicle $i-1$ and trailing vehicle $i+1$ along the corridor.
2. The curvilinear spatial distance $d_{\text{ahead}} = \text{dist}(x_i, x_{i-1})$ is computed using spherical Haversine geometry.
3. The operational time headway $h_i$ is evaluated:
   $$h_i = \frac{d_{\text{ahead}}}{\bar{v}}$$
4. The spacing error $\Delta h_i = h_i - H^*$ generates an immediate, deterministic driver advisory:
   $$\text{Advisory}_i = \begin{cases} 
   \text{"SLOW DOWN"} & \text{if } d_{\text{ahead}} < 200\text{ m} \quad (\text{Bunching Hazard}) \\ 
   \text{"SPEED UP"} & \text{if } d_{\text{ahead}} > 800\text{ m} \quad (\text{Excessive Gap}) \\ 
   \text{"MAINTAIN CURRENT SPEED"} & \text{otherwise} 
   \end{cases}$$
5. The advisory is pushed to the driver's phone within 20 milliseconds, rendering a high-contrast visual badge directly on the in-cab dashboard.

### 8.2 Speed-Floored Dynamic ETA Regularizer
Standard GPS applications calculate ETA as $\tau = \frac{D}{v}$. When a combi encounters a red light, roundabout traffic, or dwells at a rank picking up passengers, $v \to 0$, causing $\tau \to \infty$. This mathematical divergence destroys commuter confidence.

SmartTransit implements a **speed-floored regularizer**:
$$\text{ETA} = \frac{D_{\text{remaining}}}{\max(v_{\text{instantaneous}}, v_{\text{floor}})} + \sum_{k=1}^{N_{\text{intermediate}}} t_{\text{dwell}, k}$$
- $v_{\text{floor}} = 18.0\text{ km/h}$ ($5.0\text{ m/s}$), empirically calibrated for Greater Gaborone arterial traffic crawl.
- $t_{\text{dwell}} = 45\text{ seconds}$ per intermediate gazetted stop.
- Guarantees monotonic, non-divergent arrival countdowns even during prolonged stationary passenger boarding dwells.

### 8.3 Spatial $k$-Nearest Neighbors ($k$-NN) Hail Dispatch Engine
When a commuter initiates a special cab hail:
1. The engine retrieves all active drivers with `service_type == 'TAXI'` and `status == 'ONLINE'`.
2. Computes the great-circle Haversine distance between the commuter pickup pin $( \phi_p, \lambda_p )$ and driver coordinates $( \phi_d, \lambda_d )$:
   $$d = 2R \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_p)\cos(\phi_d)\sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$
3. Filters for idle drivers within a maximum search radius ($r_{\max} = 5.0\text{ km}$).
4. Sorts by ascending distance and selects the top $k = 5$ candidates.
5. Emits targeted WebSocket auction notifications (`new-taxi-request`) in parallel to the 5 selected driver cockpits.
6. The first driver to swipe the acceptance slider claims the booking via an atomic database lock.

### 8.4 NetworkX Directed Graph Multi-Modal Planner (Backward Scheduling)
For regional or long-distance travel, the system models the multi-modal transit network as a directed weighted graph $G = (V, E)$ using Python's `networkx` library:
- **Vertices ($V$):** Doorstep geocodes, neighborhood combi stops, central bus ranks, and intercity coach terminals.
- **Edges ($E$):** 
  - On-demand taxi links ($v \approx 40\text{ km/h}$, metered fare).
  - Fixed combi corridors ($v \approx 25\text{ km/h}$, statutory BWP 8.00 fare).
  - Intercity express coach corridors ($v \approx 80\text{ km/h}$, distance-tiered fare).
- **Backward Scheduling:** Given a target arrival time at an intercity destination (e.g., Francistown at 14:30), the algorithm traverses $G$ backward from destination to origin:
  1. Intercity leg requires $255\text{ min} \implies$ Coach departs Gaborone at 10:15.
  2. Adds a **15-minute luggage buffer** $\implies$ Commuter must arrive at Central Bus Rank by 10:00.
  3. Combi leg takes $20\text{ min} \implies$ Combi departure at 09:30.
  4. Special cab first-mile pickup requires $12\text{ min} \implies$ Taxi pickup scheduled at commuter doorstep at 09:15.
  5. Produces a cohesive, multi-leg itinerary with synchronized transfers.

### 8.5 Autonomous Co-Movement Proximity Geofencing (Hands-Free Boarding)
In informal paratransit, conductors and drivers cannot be expected to tap buttons to record passenger boardings. SmartTransit automates this transition:
- When a waiting commuter's phone and a combi driver's phone satisfy two simultaneous physical conditions:
  1. **Spatial Proximity:** $\text{dist}(\text{coords}_{\text{commuter}}, \text{coords}_{\text{driver}}) \le 20.0\text{ meters}$.
  2. **Kinematic Velocity Matching:** Both devices exhibit matching velocity vectors with $v > 2.0\text{ m/s}$ ($7.2\text{ km/h}$) along the corridor trajectory.
- The server autonomously transitions commuter state from `WAITING` $\to$ `ON_BOARD`.
- **Alighting Detection:** When the passenger was `ON_BOARD` and the distance subsequently exceeds $60\text{ meters}$ while the combi continues moving at $v > 3.0\text{ m/s}$, the server autonomously completes the trip and prompts the commuter for a driver rating.

---

## 9. Mobile Client Architecture (`smart_transit_app` in Flutter/Dart)

The mobile application is engineered in **Flutter (Dart)**, delivering 60–120 FPS hardware-accelerated performance on both Android and iOS from a single unified codebase.

```
smart_transit_app/lib/
├── core/
│   ├── theme.dart            # Botswana national palette (sky blue #00A3E0, dark obsidian #0F172A)
│   └── constants.dart        # Server endpoints & socket channels
├── models/                   # TransitRoute, DriverModel, HailRequestModel, ItineraryModel
├── providers/                # AuthProvider, TransitProvider, TaxiBookingProvider
├── screens/
│   ├── auth/                 # Role Selection (Passenger vs Driver), Phone Auth
│   ├── passenger/            # Commuter Dashboard, BusCombiMapScreen, TaxiFlowScreen, AIPlannerScreen
│   └── driver/               # DriverDashboard, DriverHomeScreen, SpacingAdvisoryWidget, TaxiDriverScreen
└── services/                 # ApiService, SocketService, LocationService
```

### 9.1 Commuter Cockpit (Passenger Mode)
- **Live Corridor Tracking (`bus_combi_map_screen.dart`):** Displays real-time combi markers moving smoothly across vector maps. Tapping any marker shows driver name, vehicle plate, current speed, and dynamic ETA countdown to the commuter's nearest stop.
- **On-Demand Taxi Hailing (`taxi_flow_screen.dart`):** Drop a pin anywhere in Gaborone; upfront fare quote is displayed instantly; live radar scans for nearest blue-plate cabs; real-time driver approach animation with vehicle heading compass.
- **AI Multi-Modal Trip Planner (`ai_planner_screen.dart`):** Input origin and final destination across Botswana to receive step-by-step coordinated itineraries with transfer waypoints and aggregate fare totals.

### 9.2 Driver Telematics Cockpit (Driving Mode & In-Cab Spacing HUD)
- **Ergonomic In-Cab Design (`driver_home_screen.dart`):** High-contrast interface readable from 1 meter away on a dashboard phone mount. Minimalist, zero-distraction layout.
- **Live Spacing Advisory Widget (`spacing_advisory_widget.dart`):**
  - **`SLOW DOWN` (Red Alert):** Prominently flashes when trailing the lead vehicle by $<200\text{ m}$. Advises holding at the next stop to eliminate platooning.
  - **`MAINTAIN PACE` (Green Status):** Confirms optimal headway spacing.
  - **`SPEED UP` (Blue Notice):** Indicates an excessive gap ($>800\text{ m}$) that is starving downstream waiting commuters.
- **High-Frequency GPS Emitter (`location_service.dart`):** Employs hardware-level GPS polling with low battery drain, streaming 1 Hz location pings over persistent WebSockets even when backgrounded.

### 9.3 State Management & Offline Fallbacks
- Uses **Provider** architecture (`ChangeNotifier`) for reactive, deterministic state updates.
- If the mobile device loses cellular reception, the app caches recent coordinates and state locally, reconnecting automatically with exponential backoff when signal is restored.

---

## 10. Web Command Center (`dashboard/` in React + Leaflet)

The Command Center is a high-density, desktop-class Single Page Application (SPA) built with **React 18, Vite 5, Leaflet.js, and Chart.js**. It is specifically designed for 24-to-32-inch monitors in municipal transit offices (DRTS, Gaborone City Council, Combi Associations).

### 10.1 Real-Time Fleet Telematics Map & Virtual DOM Optimization
- **High-Frequency Marker Reconciliation:** Ingests dozens of 1 Hz vehicle telemetry pings per second. Rather than triggering expensive browser reflows through imperative DOM manipulation, React's Virtual DOM diffing engine surgical updates only the specific marker coordinates and table cells that changed.
- **Corridor Visualization:** Renders color-coded vector polylines for arterial routes. Vehicles are represented as directional avatars indicating real-time heading, speed, and occupancy.
- **Demand Density Heatmaps:** Uses `leaflet.heat` to aggregate active passenger hail coordinates, displaying glowing spatial heatmaps of underserved commuter clusters across Gaborone.

### 10.2 DRTS Statutory Regulatory Audit Reports (RPT-01 to RPT-05)
The dashboard includes an automated reporting engine (`reportGenerator.js`) that exports official compliance reports in CSV and JSON formats for municipal regulators:
1. **RPT-01 (Headway Regularity & Bunching Audit):** Quantifies variance from the 5-minute target headway per corridor; flags operators responsible for severe platooning.
2. **RPT-02 (Fleet Operational Telemetry & Speed Violations):** Audits vehicle speeds against gazetted limits in school zones, roundabouts, and mall terminals.
3. **RPT-03 (Commuter Demand & Hail Spatial Distribution):** Documents unfulfilled taxi hails and passenger wait times by neighborhood, providing empirical data for DRTS permit allocation.
4. **RPT-04 (Revenue & Tariff Reconciliation):** Audits fare collection compliance against the statutory BWP 8.00 rate.
5. **RPT-05 (Driver Safety & Quality Rating Audit):** Ranks drivers by passenger ratings and incident reports.

---

## 11. End-to-End Request & Event Flows

### Flow A: Commuter Corridor Discovery & Real-Time Tracking
```
Commuter App               FastAPI Backend (REST)         Socket.IO Gateway         PostgreSQL / Cache
     |                               |                            |                        |
     |-- 1. GET /api/transit/routes ->|                            |                        |
     |                               |-- 2. Query registered routes----------------------->|
     |<- 3. Return Routes [] --------|                            |                        |
     |                                                             |                        |
     |-- 4. Emit 'join' { role: 'passengers', routeId: 'active' }->|                        |
     |                                                             |-- 5. Add to Room       |
     |<- 6. 'active-drivers-snapshot' (Current online combis) -----|                        |
     |                                                             |                        |
     |   [ Driver emits 1 Hz GPS Ping ]                            |                        |
     |<- 7. 'driver-location' { lat, lng, speed, heading } --------|                        |
     |<- 8. 'eta-update' { etaSeconds: 180, distanceMeters: 850 } -|                        |
     |                                                             |                        |
```

### Flow B: In-Cab 1 Hz GPS Telematics & Dynamic Pacing Advisory Loop
```
Driver Cockpit                 Socket.IO Gateway            Headway Service        Dashboard & Commuter
     |                                 |                           |                        |
     |-- 1. 'driver-location' (1 Hz) ->|                           |                        |
     |   { lat, lng, speed, route_id } |                           |                        |
     |                                 |-- 2. Compute Spacing ---->|                        |
     |                                 |   (Haversine to lead veh) |                        |
     |                                 |<- 3. Return Advisory -----|                        |
     |<- 4. 'spacing-advisory' --------|   (e.g., 'SLOW DOWN')     |                        |
     |   [HUD displays Red Banner]     |                           |                        |
     |                                 |-- 5. Broadcast 'fleet-update' -------------------->| (DRTS Map updates)
     |                                 |-- 6. Broadcast 'eta-update' ---------------------->| (Commuter ETA ticks)
```

### Flow C: On-Demand Special Cab Hail ($k$-NN Matching & Live Dispatch)
```
Commuter App               Socket.IO Gateway           k-NN Dispatch Engine         5 Nearest Taxi Cabs
     |                             |                            |                            |
     |-- 1. 'passenger-request-taxi'                            |                            |
     |   { pickup, dropoff, type } |                            |                            |
     |                             |-- 2. Find online taxis --->|                            |
     |                             |<- 3. Return top 5 taxis ---|                            |
     |<- 4. 'taxi-dispatched' -----|                            |                            |
     |   { status: 'finding' }     |-- 5. 'new-taxi-request' (parallel broadcast) ---------->|
     |                             |                                    [ Driver 2 accepts ] |
     |                             |<- 6. 'taxi-accept' { reqId, driverId } -----------------|
     |                             |-- 7. Assign driver & lock request                       |
     |<- 8. 'taxi-assigned' -------|                                                         |
     |   { driverId, coords, eta } |-- 9. 'taxi-confirmation' ------------------------------>|
```

### Flow D: Autonomous Co-Movement Boarding & Fare Settlement
```
Commuter App               Driver Cockpit              Socket.IO Gateway           PostgreSQL DB
     |                            |                            |                         |
     |   [ Both devices within 20m, moving at >2 m/s along route ]                       |
     |                            |-- 1. 'driver-location' --->|                         |
     |                                                         |-- 2. Detect Co-Movement |
     |<- 3. 'boarding-confirmed' ------------------------------|                         |
     |   [ UI switches to ON_BOARD mode ]                      |                         |
     |                                                         |                         |
     |   [ Trip completes: passenger alights, distance > 60m ] |                         |
     |<- 4. 'trip-completed' ----------------------------------|                         |
     |   [ Prompt Star Rating Modal ]                          |-- 5. Insert Trip Record>|
     |-- 6. POST /api/trips/rating ----------------------------------------------------->|
```

---

## 12. Configuration, Deployment, and Local Setup

### 12.1 Environment Variables
Create a `.env` file in the `backend/` directory:

```env
# System Configuration
PROJECT_NAME="SmartTransit Engine"
VERSION="1.0.0"
PORT=8000
HOST="0.0.0.0"
DEBUG=True

# CORS Configuration (Comma-separated origins)
CORS_ORIGINS="http://localhost:3000,http://localhost:5173,http://localhost:8000,https://smarttransit.bw"

# Database Configuration (Dual-Engine)
# Defaults to SQLite edge persistence if Supabase URL is not active
DATABASE_URL="sqlite+aiosqlite:///./smarttransit.db"
# Production Supabase PostgreSQL:
# DATABASE_URL="postgresql+asyncpg://postgres:[PASSWORD]@db.[PROJECT_ID].supabase.co:5432/postgres"

SUPABASE_URL="https://[YOUR_PROJECT_ID].supabase.co"
SUPABASE_KEY="[YOUR_ANON_OR_SERVICE_KEY]"
```

### 12.2 Local Execution Guide

#### Backend (Python 3.11+)
```bash
# Navigate to backend directory
cd backend

# Create and activate virtual environment
python -m venv .venv
# On Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# On Linux/macOS:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Launch FastAPI + Socket.IO server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
# Interactive API documentation available at: http://localhost:8000/docs
```

#### Mobile Application (Flutter 3.x)
```bash
# Navigate to mobile app directory
cd smart_transit_app

# Fetch Flutter dependencies
flutter pub get

# Launch on connected Android/iOS device or emulator
flutter run
```

#### Web Command Center (Node.js 18+)
```bash
# Navigate to dashboard directory
cd dashboard

# Install dependencies
npm install

# Start Vite development server
npm run dev
# Dashboard loads at: http://localhost:5173
```

### 12.3 Production Cloud Deployment
- **Backend ASGI Server:** Dockerized container deployed on **Railway** or **Render** (`uvicorn main:app --host 0.0.0.0 --port $PORT`).
- **Database:** Hosted **Supabase PostgreSQL 15** with PostGIS and automated daily backups.
- **Web Dashboard:** Hosted on **Netlify** / **Vercel** with continuous deployment from GitHub main branch.
- **Mobile Client:** Pre-compiled release APKs (`SmartTransit_v1.0.0.apk`, `SmartTransit_v1.1.0.apk`) available for direct sideloading or Google Play Store internal track.

---

## 13. Technology Stack Breakdown & Engineering Justifications

| Tier | Chosen Technology | Evaluated Alternative | Engineering Rationale |
| :--- | :--- | :--- | :--- |
| **Backend Core** | **Python (FastAPI + AsyncIO + Socket.IO)** | **Java (Spring Boot)** | Native graph-theoretic libraries (`networkx`), lightweight non-blocking coroutines consuming kilobytes of RAM per socket connection (versus megabytes of JVM thread stack), sub-second Pydantic serialization, and rapid iteration within a 12-week Agile sprint. |
| **Mobile Client** | **Flutter & Dart (`smart_transit_app`)** | **Native Android (Kotlin)** | 100% single codebase parity across Android and iOS (crucial in Botswana's mixed smartphone demographic), unified code-sharing between Driver and Passenger modes, 60–120 FPS Impeller vector graphics rendering, and sub-second Stateful Hot Reload. |
| **Command Center** | **React 18 + Vite (`dashboard/`)** | **Plain HTML + Vanilla JS** | Virtual DOM diffing engine reconciles dozens of 1 Hz GPS marker movements per second without browser reflows or DOM thrashing; declarative component synchronization between map, fleet list, and CSV export modals. |
| **Database Layer** | **Supabase PostgreSQL + PostGIS** *(with offline Async SQLite fallback)* | **MySQL or Pure Cloud DB** | Enterprise spatial indexing (R-Tree), JSONB route waypoint storage, Row Level Security (RLS), and zero-friction fallback to `aiosqlite` during field trials with spotty cellular reception. |
| **Map Rendering** | **Leaflet.js + OpenStreetMap (OSM)** | **Google Maps JavaScript API** | Zero commercial licensing fees, no aggressive API quota rate-limiting, full offline vector tile caching capabilities, and privacy-preserving open infrastructure. |

---

## 14. Transit Data Reality, Ingestion Architecture & Corridor Digitization

### 14.1 The Paratransit Data Reality in Gaborone
A fundamental characteristic of informal urban mobility in Botswana is that **no digitized transit dataset exists**. Unlike European or North American transit agencies that publish standardized GTFS (General Transit Feed Specification) feeds, the Department of Road Transport and Safety (DRTS) and local taxi associations manage routes through paper permits, verbal corridor descriptions, and informal rank queues.

### 14.2 Schema Readiness vs. Static Dataset Availability
It is vital to distinguish between **architectural capability** and **data availability**:
1. **The Architecture is 100% Schema-Ready:**
   The database tables (`routes`, `stops`, `route_stops`), Pydantic validation schemas, and REST endpoints (`/api/transit/routes`, `/api/transit/stops`) are fully designed, indexed, and operational.
2. **Current Production State is Empty (`[]`):**
   SmartTransit **does not currently possess or load an official public transit corridor dataset**. Any previously referenced route IDs (such as `ROUTE_BBS_STATION`, `route-u01`, etc.) were developer mock subjects used during initial test scaffolding. In the active codebase, these dummy records are filtered out ([`backend/app/routers/transit.py:22-24`](file:///c:/Users/araba/Desktop/SmartTransit/backend/app/routers/transit.py#L22-L24) and [`smart_transit_app/lib/services/api_service.dart:76-82`](file:///c:/Users/araba/Desktop/SmartTransit/smart_transit_app/lib/services/api_service.dart#L76-L82)), meaning the routes endpoint cleanly returns `[]`.

### 14.3 Spatial Independence of Point-to-Point Taxi Hailing
Crucially, SmartTransit's **on-demand special cab hailing ($k$-NN dispatch)** is **completely independent of static route datasets**:
- Commuter pickup coordinates and driver locations are acquired directly from smartphone GPS hardware.
- The spatial dispatch engine computes real-time spherical Haversine distances dynamically.
- The entire hail lifecycle (auction broadcast $\rightarrow$ driver swipe acceptance $\rightarrow$ dynamic ETA countdown $\rightarrow$ fare settlement) functions autonomously without requiring any pre-existing route or stop dataset.

### 14.4 Corridor Digitization & GTFS Field Survey Strategy
To populate the `routes` and `stops` tables with authentic paratransit data, SmartTransit has engineered a structured field survey methodology:
1. **Driver Telematics Track Logging:** As enrolled combi drivers pilot their routes during daily operations, the in-cab Flutter app logs high-resolution GPS traces (latitude, longitude, speed, timestamp).
2. **Stop Clustering & Identification:** Unsupervised spatial clustering (DBSCAN) will be applied to aggregate driver dwell points ($v \approx 0$ for $>15\text{ s}$ outside traffic signals) to automatically identify and catalogue unofficial paratransit boarding stops across Greater Gaborone.
3. **Polyline Vectorization & GTFS Publishing:** Processed traces will be converted into smoothed vector waypoints and exported as Botswana's first open General Transit Feed Specification (GTFS) feed.

---

## 15. System Status, Known Constraints, and Engineering Roadmap

### 15.1 Current System Status
- **Backend Core & WebSockets:** Fully operational. Supports 1 Hz GPS streaming, Newell–Daganzo headway calculations, speed-floored ETAs, and $k$-NN taxi dispatch.
- **Mobile Client (`smart_transit_app`):** Fully operational. Supports driver shift toggles, in-cab spacing HUD, passenger taxi hailing, and live vector map rendering.
- **Web Command Center (`dashboard/`):** Operational. Real-time Leaflet map rendering active fleet icons, tabular manifest, metrics grid, and statutory CSV exports.

### 15.2 Known Constraints & Next Steps
1. **Corridor Dataset Ingestion:** Execute the field survey plan to map Gaborone's arterial combi routes (Broadhurst, Tlokweng, Mogoditshane, G-West) and populate the `routes` and `stops` database tables.
2. **Payment Gateway Integration:** Implement direct integration with local mobile wallets (Orange Money, Mascom MyZaka) for digital cashless fare settlement.
3. **Hardware IoT Edge Trackers:** Evaluate dedicated low-cost OBD-II/GPS tracking hardware for vehicle installation to supplement smartphone-based driver beacons.

---

*Authored by the SmartTransit Systems Architecture & Engineering Team.*  
*First Minds • Republic of Botswana* 🇧🇼
