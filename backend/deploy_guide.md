# SmartTransit Cloud Deployment & Supabase Guide

This guide explains how to host the SmartTransit Backend & Database so that the Flutter mobile app and Dispatch Dashboard can be accessed by **any device, from anywhere, at any time**.

---

## 1. Supabase PostgreSQL Database Setup

1. Open your **Supabase Dashboard**: [https://supabase.com/dashboard/project/xpphmiajwjkcxtxitcex](https://supabase.com/dashboard/project/xpphmiajwjkcxtxitcex)
2. Navigate to **SQL Editor** -> **New Query**.
3. Copy and paste the contents of `backend/schema_supabase.sql` (or `supabase/migrations/20260822000000_smarttransit_schema.sql`).
4. Click **Run**.
   - This creates all tables: `routes`, `stops`, `route_stops`, `trips`, `hails`, `driver_locations`, `users`.
   - Enables Row Level Security (RLS) policies allowing public read & mobile ride requests.
   - Enables Supabase Realtime for live vehicle tracking.
   - Populates Botswana transit routes (Molepolole, Gaborone, Intercity) and stops.

---

## 2. 1-Click Free Cloud Backend Hosting (Render.com)

1. Go to [Render.com](https://render.com) and sign in with GitHub.
2. Click **New +** -> **Web Service**.
3. Connect your GitHub repository: `https://github.com/ABM-IX/Smart-Transit`.
4. Configure the settings:
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Add Environment Variables:
   - `SUPABASE_URL`: `https://xpphmiajwjkcxtxitcex.supabase.co`
   - `SUPABASE_KEY`: `sb_publishable_7cqahorS_JAw4601eqpQkA_xPgA3YZL`
   - `DATABASE_URL`: `postgresql+asyncpg://postgres:SmartTransit%4026@db.xpphmiajwjkcxtxitcex.supabase.co:5432/postgres`
6. Click **Create Web Service**.
7. Once deployed, Render provides a public HTTPS URL: **`https://smart-transit-uhyf.onrender.com`**.

---

## 3. Instant Public Access via Cloudflare Tunnel / Ngrok (Alternative)

If you are running the backend on your PC and want immediate public access from any phone on 4G/5G:
```bash
# Using Cloudflare Tunnel (Free & No account needed):
cloudflared tunnel --url http://localhost:8000
```
or
```bash
# Using ngrok:
ngrok http 8000
```
This gives you a public HTTPS URL (e.g. `https://smarttransit.trycloudflare.com`) accessible from any device in the world.

---

## 4. Connecting the Flutter Mobile App & Dashboard

1. **Flutter Mobile App**:
   - The app is pre-configured to connect directly to **`https://smart-transit-uhyf.onrender.com`**!
   - Built-in **Direct Supabase Cloud Fallback**: Even if the custom backend server is sleeping, routes and stops load directly from Supabase Cloud!
   - You can also tap the **Server Config** button on the Welcome screen to enter any custom server URL.
2. **Dispatch Dashboard**:
   - Pre-configured to **`https://smart-transit-uhyf.onrender.com`**.
   - You can also enter a custom URL in the sidebar input and click **Link**.

