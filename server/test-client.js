const { io } = require("socket.io-client");

const socket = io("http://localhost:3000");

socket.on("connect", () => {
    console.log("Connected to server:", socket.id);

    // Join as a driver
    socket.emit("join", "drivers");

    // Simulate location update
    setInterval(() => {
        const data = {
            driverId: "bus-001",
            coords: { lat: -15.3875, lng: 28.3228 },
            occupancy: "low"
        };
        console.log("Sending location update:", data);
        socket.emit("location-update", data);
    }, 5000);
});

socket.on("new-hail", (data) => {
    console.log("Received new hail request!", data);
});

// Periodically check the API for all drivers
setInterval(async () => {
    try {
        const response = await fetch("http://localhost:3000/api/drivers");
        const drivers = await response.json();
        console.log("Current active drivers (API):", drivers);
    } catch (err) {
        console.error("Error fetching drivers from API:", err.message);
    }
}, 10000);

socket.on("disconnect", () => {
    console.log("Disconnected from server");
});
