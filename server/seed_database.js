const admin = require('firebase-admin');
const serviceAccount = require('./smarttransit-5453c-firebase-adminsdk-fbsvc-324f41bc8a.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const mockRoutes = [
  {
    route_id: "route-004",
    route_name: "Route 4: Tlokweng → Rail Park Station",
    start: "Tlokweng",
    end: "Rail Park Station",
    description: "Passes along UB, Main Mall, ends at Rail Park."
  },
  {
    route_id: "route-006",
    route_name: "Route 6: Tlokweng → Gamecity",
    start: "Tlokweng",
    end: "Gamecity",
    description: "Passes along BAC, Riverwalk, BISET, ends at Gamecity."
  },
  {
    route_id: "route-008",
    route_name: "Route 8: Block 8 → Main Mall",
    start: "Block 8",
    end: "Main Mall",
    description: "Classic corridor, ends at Main Mall."
  },
  {
    route_id: "route-010",
    route_name: "Route 10: Tlokweng → Bus Rank",
    start: "Tlokweng",
    end: "Bus Rank",
    description: "Direct route into the central Bus Rank."
  },
  {
    route_id: "route-u01",
    route_name: "Route U1: BAC → Bus Rank",
    start: "BAC",
    end: "Bus Rank",
    description: "University route connecting BAC to the Bus Rank."
  },
  {
    route_id: "route-u02",
    route_name: "Route U2: UB → Main Mall",
    start: "UB",
    end: "Main Mall",
    description: "University route connecting UB to Main Mall."
  },
  {
    route_id: "route-u03",
    route_name: "Route U3: Botho University → Bus Rank",
    start: "Botho University",
    end: "Bus Rank",
    description: "University route connecting Botho U to the Bus Rank."
  },
  {
    route_id: "route-u04",
    route_name: "Route U4: Gamecity → Bus Rank",
    start: "Gamecity",
    end: "Bus Rank",
    description: "Connects Gamecity shopping hub to the Bus Rank."
  }
];

// Mock stops for Route 4 just as an example
const mockStops = [
  {
    stop_id: "stop-4-1",
    route_id: "route-004",
    name: "Tlokweng Border Post",
    latitude: -24.6738,
    longitude: 26.0354
  },
  {
    stop_id: "stop-4-2",
    route_id: "route-004",
    name: "UB Gate",
    latitude: -24.6590,
    longitude: 25.9325
  },
  {
    stop_id: "stop-4-3",
    route_id: "route-004",
    name: "Main Mall",
    latitude: -24.6543,
    longitude: 25.9189
  },
  {
    stop_id: "stop-4-4",
    route_id: "route-004",
    name: "Rail Park Station",
    latitude: -24.6465,
    longitude: 25.9032
  }
];

async function seedData() {
  console.log('Starting seed process...');
  const batch = db.batch();

  // Seed routes
  for (const route of mockRoutes) {
    const routeRef = db.collection('routes').doc(route.route_id);
    batch.set(routeRef, route);
  }

  // Seed stops
  for (const stop of mockStops) {
    const stopRef = db.collection('stops').doc(stop.stop_id);
    batch.set(stopRef, stop);
  }

  try {
    await batch.commit();
    console.log('Successfully seeded mock routes and stops to Firestore.');
  } catch (error) {
    console.error('Error seeding data:', error);
  } finally {
    process.exit(0);
  }
}

seedData();
