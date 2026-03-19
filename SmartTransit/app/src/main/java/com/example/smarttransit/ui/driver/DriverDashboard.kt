package com.example.smarttransit.ui.driver

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.smarttransit.model.UserRole
import com.example.smarttransit.network.SocketHandler
import com.example.smarttransit.ui.components.ConnectionBadge
import com.example.smarttransit.ui.components.SmartTransitMap
import com.google.android.gms.location.*
import io.socket.client.Socket
import org.json.JSONObject
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.URL
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DriverDashboard(initialRole: UserRole) {
    var currentRole by remember { mutableStateOf(initialRole) }
    var selectedTab by remember { mutableIntStateOf(0) }
    var isOnline by remember { mutableStateOf(false) }
    var sessionStarted by remember { mutableStateOf(false) }
    
    val driverId = remember { "d-${UUID.randomUUID().toString().take(8)}" }
    
    val socket = SocketHandler.currentSocket
    val isConnected = SocketHandler.isConnected
    
    val activeHails = remember { mutableStateMapOf<String, JSONObject>() }
    
    var spacingAdvisory by remember { mutableStateOf<JSONObject?>(null) }
    var userLocation by remember { mutableStateOf<LatLng?>(null) }
    var routeId by remember { mutableStateOf(if (currentRole == UserRole.DRIVER_TAXI) "taxi-service" else "") }
    val passengerLocations = remember { mutableStateMapOf<String, LatLng>() }
    var occupancy by remember { mutableStateOf("Empty") }
    var stopRequestCount by remember { mutableIntStateOf(0) }
    var activeTripId by remember { mutableStateOf<String?>(null) }
    var tripPassengerCount by remember { mutableIntStateOf(0) }
    var tripRevenue by remember { mutableIntStateOf(0) }

    val context = LocalContext.current
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    
    val startLocationUpdates = {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000).build()
        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    userLocation = LatLng(location.latitude, location.longitude)
                    if (isOnline && routeId.isNotEmpty() && socket?.connected() == true) {
                        val data = JSONObject().apply {
                            put("driverId", driverId)
                            put("driverType", currentRole.name)
                            put("routeId", routeId)
                            put("coords", JSONObject().apply {
                                put("lat", location.latitude)
                                put("lng", location.longitude)
                            })
                            put("speed", location.speed.toDouble())
                            put("heading", location.bearing.toDouble())
                            put("timestamp", System.currentTimeMillis())
                            put("occupancy", occupancy)
                            put("serviceType", if (currentRole == UserRole.DRIVER_TAXI) "TAXI" else "COMBI")
                        }
                        socket.emit("driver-location", data)
                    }
                }
            }
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        }
    }

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        if (permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true) {
            startLocationUpdates()
        }
    }

    LaunchedEffect(Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        } else {
            startLocationUpdates()
        }
        SocketHandler.establishConnection()
    }

    LaunchedEffect(isOnline) {
        if (socket?.connected() == true) {
            if (isOnline) {
                socket.emit("driver-online", JSONObject().apply {
                    put("driverId", driverId)
                    put("routeId", if (routeId.isEmpty()) "default-route" else routeId)
                    put("status", "ONLINE")
                    put("serviceType", if (currentRole == UserRole.DRIVER_TAXI) "TAXI" else "COMBI")
                    put("driverType", currentRole.name)
                })
            } else {
                socket.emit("driver-offline", JSONObject().apply {
                    put("driverId", driverId)
                })
            }
        }
    }

    fun joinRoom() {
        if (isOnline && routeId.isNotEmpty() && socket?.connected() == true) {
            val joinData = JSONObject().apply {
                put("role", "drivers")
                put("routeId", routeId)
                put("driverId", driverId)
                put("driverType", currentRole.name)
            }
            socket.emit("join", joinData)
            socket.emit("subscribe-route", JSONObject().apply {
                put("role", "drivers")
                put("routeId", routeId)
            })
        }
    }

    DisposableEffect(socket, isOnline, routeId, isConnected) {
        if (socket == null) return@DisposableEffect onDispose { }

        if (isConnected && isOnline && routeId.isNotEmpty()) {
            joinRoom()
            
            socket.on("new-hail") { args ->
                if (args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val pId = data?.optString("passengerId") ?: ""
                    if (pId.isNotEmpty() && data != null) {
                        activeHails[pId] = data
                        (context as? android.app.Activity)?.runOnUiThread {
                            val msg = data.optString("message", "New Request Received!")
                            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            
            socket.on("hail") { args ->
                if (args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val pId = data?.optString("passengerId") ?: ""
                    if (pId.isNotEmpty() && data != null) activeHails[pId] = data
                }
            }

            socket.on("hail-cancelled") { args ->
                if (args != null && args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val pId = data?.optString("passengerId") ?: ""
                    if (pId.isNotEmpty()) {
                        activeHails.remove(pId)
                        (context as? android.app.Activity)?.runOnUiThread {
                            Toast.makeText(context, "Request Cancelled", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }

            socket.on("passenger-boarded") { args ->
                if (args != null && args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val pId = data?.optString("passengerId") ?: ""
                    if (pId.isNotEmpty()) activeHails.remove(pId)
                }
            }

            socket.on("passenger-location") { args ->
                if (args != null && args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val pId = data?.optString("passengerId") ?: ""
                    val coords = data?.optJSONObject("coords")
                    if (pId.isNotEmpty() && coords != null) {
                        passengerLocations[pId] = LatLng(coords.optDouble("lat"), coords.optDouble("lng"))
                    }
                }
            }

            socket.on("stop-request") { 
                stopRequestCount++ 
                (context as? android.app.Activity)?.runOnUiThread {
                    Toast.makeText(context, "Stop request received", Toast.LENGTH_LONG).show()
                }
            }

            socket.on("new-stop-request") {
                stopRequestCount++
                (context as? android.app.Activity)?.runOnUiThread {
                    Toast.makeText(context, "New Stop Request!", Toast.LENGTH_LONG).show()
                }
            }

            socket.on("spacing-advisory") { args ->
                if (args != null && args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    spacingAdvisory = data
                }
            }
        }
        
        onDispose {
            socket.off("new-hail")
            socket.off("hail")
            socket.off("hail-cancelled")
            socket.off("passenger-boarded")
            socket.off("passenger-location")
            socket.off("stop-request")
            socket.off("new-stop-request")
            socket.off("spacing-advisory")
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Column {
                        Text(currentRole.name.replace("_", " "), style = MaterialTheme.typography.titleMedium)
                        Text(
                            if (isConnected) "Connected" else "Disconnected", 
                            style = MaterialTheme.typography.labelSmall,
                            color = if (isConnected) Color.Green else Color.Red
                        )
                    }
                },
                actions = {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(end = 8.dp)) {
                        Text(if (isOnline) "Online" else "Offline", style = MaterialTheme.typography.bodySmall)
                        Switch(checked = isOnline, onCheckedChange = { isOnline = it }, modifier = Modifier.scale(0.8f))
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = selectedTab == 0, onClick = { selectedTab = 0 }, icon = { Icon(Icons.Default.Map, "") }, label = { Text("Map") })
                NavigationBarItem(selected = selectedTab == 1, onClick = { selectedTab = 1 }, icon = { Icon(Icons.Default.Route, "") }, label = { Text("Route") })
                NavigationBarItem(selected = selectedTab == 2, onClick = { selectedTab = 2 }, icon = { Icon(Icons.Default.Notifications, "") }, label = { Text("Alerts") })
                NavigationBarItem(selected = selectedTab == 3, onClick = { selectedTab = 3 }, icon = { Icon(Icons.Default.Person, "") }, label = { Text("Profile") })
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            ConnectionBadge()
            when (selectedTab) {
                3 -> DriverProfileScreen()
                else -> {
                    if (!isOnline) {
                        OfflineScreen()
                    } else if (routeId.isEmpty()) {
                        RouteSetupScreen(currentRole) { routeId = it }
                    } else {
                        DriverInterface(
                            currentRole, sessionStarted,
                            onToggleSession = { 
                                sessionStarted = !sessionStarted
                                if (sessionStarted) {
                                    val tripId = "trip-${UUID.randomUUID().toString().take(8)}"
                                    activeTripId = tripId
                                    socket?.emit("trip-start", JSONObject().apply {
                                        put("tripId", tripId)
                                        put("driverId", driverId)
                                        put("routeId", routeId)
                                        put("passengerCount", tripPassengerCount)
                                        put("revenue", tripRevenue)
                                    })
                                } else {
                                    activeTripId?.let { tripId ->
                                        socket?.emit("trip-end", JSONObject().apply {
                                            put("tripId", tripId)
                                            put("passengerCount", tripPassengerCount)
                                            put("revenue", tripRevenue)
                                        })
                                    }
                                    activeTripId = null
                                }
                            },
                            hails = activeHails.values.toList(),
                            onClearHails = { activeHails.clear() },
                            spacingAdvisory = spacingAdvisory,
                            userLocation = userLocation,
                            passengers = passengerLocations.values.toList(),
                            routeId = routeId,
                            occupancy = occupancy,
                            onUpdateOccupancy = { occupancy = it },
                            stopRequestCount = stopRequestCount,
                            onClearStopRequests = { stopRequestCount = 0 },
                            isConnected = isConnected,
                            driverId = driverId,
                            onRemoveHail = { activeHails.remove(it) },
                            onTripMetricsUpdate = { count, revenue ->
                                tripPassengerCount = count
                                tripRevenue = revenue
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun DriverProfileScreen() {
    val context = LocalContext.current
    var serverUrl by remember { mutableStateOf(SocketHandler.getCurrentUrl()) }
    var isEditing by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Driver Settings", style = MaterialTheme.typography.headlineSmall)

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Connection Settings", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)

                if (isEditing) {
                    OutlinedTextField(
                        value = serverUrl,
                        onValueChange = { serverUrl = it },
                        label = { Text("Server URL") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        TextButton(onClick = { isEditing = false; serverUrl = SocketHandler.getCurrentUrl() }) { Text("Cancel") }
                        Button(onClick = {
                            SocketHandler.init(context, serverUrl)
                            SocketHandler.establishConnection()
                            isEditing = false
                            Toast.makeText(context, "Reconnecting to $serverUrl", Toast.LENGTH_SHORT).show()
                        }) { Text("Save") }
                    }
                } else {
                    Text("Server: $serverUrl", style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = { isEditing = true }) { Text("Edit Server URL") }
                }
                Text(
                    "Note: For local development, use http://192.168.0.182:3000",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.secondary
                )
            }
        }
    }
}

@Composable
fun RouteSetupScreen(role: UserRole, onRouteSet: (String) -> Unit) {
    val isBus = role == UserRole.DRIVER_BUS
    val modeType = if (isBus) "BUS" else "COMBI"
    val context = LocalContext.current
    val serverUrl = SocketHandler.getCurrentUrl()

    data class RouteItem(val routeId: String, val name: String, val start: String, val end: String, val type: String)

    val fallbackBus = listOf(
        RouteItem("bus-francistown", "Gaborone → Francistown", "Gaborone Bus Rank", "Francistown", "BUS"),
        RouteItem("bus-lobatse", "Gaborone → Lobatse", "Gaborone Bus Rank", "Lobatse", "BUS"),
        RouteItem("bus-molepolole", "Gaborone → Molepolole", "Gaborone Bus Rank", "Molepolole", "BUS"),
        RouteItem("bus-mahalapye", "Gaborone → Mahalapye", "Gaborone Bus Rank", "Mahalapye", "BUS"),
        RouteItem("bus-palapye", "Gaborone → Palapye", "Gaborone Bus Rank", "Palapye", "BUS"),
        RouteItem("bus-kanye", "Gaborone → Kanye", "Gaborone Bus Rank", "Kanye", "BUS"),
        RouteItem("bus-maun", "Gaborone → Maun", "Gaborone Bus Rank", "Maun", "BUS"),
        RouteItem("bus-kopong", "Gaborone → Kopong", "Gaborone Bus Rank", "Kopong", "BUS")
    )
    val fallbackCombi = listOf(
        RouteItem("route-u01", "Route U1 – BAC to Bus Rank", "BAC", "Bus Rank", "COMBI"),
        RouteItem("route-u02", "Route U2 – UB to Main Mall", "UB", "Main Mall", "COMBI"),
        RouteItem("route-u03", "Route U3 – Botho to Bus Rank", "Botho University", "Bus Rank", "COMBI"),
        RouteItem("route-u04", "Route U4 – Gamecity to Bus Rank", "Gamecity", "Bus Rank", "COMBI")
    )

    var searchQuery by remember { mutableStateOf("") }
    var allRoutes by remember { mutableStateOf<List<RouteItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(serverUrl, modeType) {
        isLoading = true
        val loaded = withContext(Dispatchers.IO) {
            try {
                val url = URL("${serverUrl}/api/routes")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.setRequestProperty("bypass-tunnel-reminder", "true")
                conn.connectTimeout = 2000
                conn.readTimeout = 2000
                val body = conn.inputStream.bufferedReader().readText()
                val arr = JSONArray(body)
                (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    RouteItem(
                        obj.optString("route_id"),
                        obj.optString("route_name"),
                        obj.optString("start"),
                        obj.optString("end"),
                        obj.optString("route_type", "BUS").uppercase()
                    )
                }
            } catch (e: Exception) {
                if (modeType == "BUS") fallbackBus else fallbackCombi
            }
        }
        allRoutes = loaded
        isLoading = false
    }

    val filtered = allRoutes
        .filter { it.type == modeType || it.type.isBlank() }
        .filter {
            searchQuery.isBlank() ||
                it.name.contains(searchQuery, ignoreCase = true) ||
                it.start.contains(searchQuery, ignoreCase = true) ||
                it.end.contains(searchQuery, ignoreCase = true)
        }

    Box(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                if (isBus) "Select Bus Destination" else "Select Combi Route",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(if (isBus) "Search destination" else "Search route") },
                leadingIcon = { Icon(Icons.Default.Search, null) },
                singleLine = true
            )

            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (filtered.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("No ${if (isBus) "bus destinations" else "combi routes"} found", color = Color.Gray)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(filtered) { r ->
                        Card(
                            modifier = Modifier.fillMaxWidth().clickable {
                                onRouteSet(r.routeId)
                                Toast.makeText(context, "Selected: ${r.name}", Toast.LENGTH_SHORT).show()
                            }
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(r.name, fontWeight = FontWeight.Bold)
                                Text("From: ${r.start}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                                Text("To: ${r.end}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                                Text("ID: ${r.routeId}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun OfflineScreen() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.CloudOff, null, modifier = Modifier.size(64.dp), tint = Color.Gray)
            Text("You are currently offline", style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
fun DriverInterface(
    role: UserRole, sessionStarted: Boolean, onToggleSession: () -> Unit,
    hails: List<JSONObject>, onClearHails: () -> Unit,
    spacingAdvisory: JSONObject?, userLocation: LatLng?,
    passengers: List<LatLng>, routeId: String,
    occupancy: String, onUpdateOccupancy: (String) -> Unit,
    stopRequestCount: Int, onClearStopRequests: () -> Unit,
    isConnected: Boolean, driverId: String, onRemoveHail: (String) -> Unit,
    onTripMetricsUpdate: (Int, Int) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            val hailPoints = hails.mapNotNull { 
                it.optJSONObject("pickupLoc")?.let { loc -> LatLng(loc.optDouble("lat"), loc.optDouble("lng")) }
            }
            val allPoints = passengers + hailPoints
            
            SmartTransitMap(userLocation = userLocation, passengers = allPoints)
            
            if (!isConnected) {
                Surface(
                    color = Color.Red.copy(alpha = 0.7f),
                    modifier = Modifier.align(Alignment.TopCenter).fillMaxWidth()
                ) {
                    Text(
                        "Connection Lost. Reconnecting...",
                        color = Color.White,
                        modifier = Modifier.padding(4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
        }

        Surface(tonalElevation = 8.dp, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (role == UserRole.DRIVER_TAXI) {
                    TaxiDriverActions(hails, driverId, routeId, onRemoveHail, onTripMetricsUpdate)
                } else {
                    BusCombiDriverActions(
                        role, sessionStarted, onToggleSession,
                        hails, onClearHails, spacingAdvisory, routeId,
                        occupancy, onUpdateOccupancy, stopRequestCount, onClearStopRequests
                    )
                }
            }
        }
    }
}

@Composable
fun BusCombiDriverActions(
    role: UserRole, sessionStarted: Boolean, onToggleSession: () -> Unit, 
    hails: List<JSONObject>, onClearHails: () -> Unit,
    spacingAdvisory: JSONObject?, routeId: String,
    occupancy: String, onUpdateOccupancy: (String) -> Unit,
    stopRequestCount: Int, onClearStopRequests: () -> Unit
) {
    if (!sessionStarted) {
        val locationLabel = if (role == UserRole.DRIVER_BUS) "Location: $routeId" else "Route: $routeId"
        Text(locationLabel, fontWeight = FontWeight.Bold)
        Button(
            onClick = onToggleSession, 
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = MaterialTheme.shapes.large
        ) { 
            Text(if (role == UserRole.DRIVER_BUS) "Start Location Session" else "Start Route Session", fontSize = MaterialTheme.typography.titleMedium.fontSize) 
        }
    } else {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text("Active Service", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                val locationLabel = if (role == UserRole.DRIVER_BUS) "Location: $routeId" else "Route: $routeId"
                Text(locationLabel, style = MaterialTheme.typography.titleMedium)
            }
            FilledTonalButton(onClick = onToggleSession, colors = ButtonDefaults.filledTonalButtonColors(containerColor = MaterialTheme.colorScheme.errorContainer, contentColor = MaterialTheme.colorScheme.onErrorContainer)) { Text("End Shift") }
        }
        
        if (stopRequestCount > 0) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                shape = MaterialTheme.shapes.medium,
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.NotificationsActive, null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(32.dp))
                    Spacer(Modifier.width(12.dp))
                    Text("$stopRequestCount STOP REQUESTS", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = onClearStopRequests) { Icon(Icons.Default.Close, null) }
                }
            }
        }

        if (hails.isNotEmpty()) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                shape = MaterialTheme.shapes.medium
            ) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.WavingHand, null, modifier = Modifier.size(32.dp))
                    Spacer(Modifier.width(12.dp))
                    Text("${hails.size} Active Hails", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = onClearHails) { Text("Clear") }
                }
            }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AlertBadge("${hails.size} Hails", MaterialTheme.colorScheme.tertiaryContainer)
            AlertBadge("$stopRequestCount Stop Requests", MaterialTheme.colorScheme.errorContainer)
        }
        if (role == UserRole.DRIVER_COMBI) SpacingAdvisory(spacingAdvisory)
        
        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
        
        // Passsenger Count Tally Component
        var passengerCount by remember(occupancy) { mutableIntStateOf(occupancy.toIntOrNull() ?: 0) }
        
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("Passenger Tally", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("$passengerCount Boarded", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            }
            Row {
                FilledIconButton(
                    onClick = { if (passengerCount > 0) { passengerCount--; onUpdateOccupancy(passengerCount.toString()) } },
                    modifier = Modifier.size(56.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                ) {
                    Icon(Icons.Default.Remove, "Remove Passenger", modifier = Modifier.size(32.dp))
                }
                Spacer(Modifier.width(16.dp))
                FilledIconButton(
                    onClick = { passengerCount++; onUpdateOccupancy(passengerCount.toString()) },
                    modifier = Modifier.size(56.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Icon(Icons.Default.Add, "Add Passenger", modifier = Modifier.size(32.dp))
                }
            }
        }
    }
}

@Composable
fun TaxiDriverActions(
    hails: List<JSONObject>,
    driverId: String,
    routeId: String,
    onRemoveHail: (String) -> Unit,
    onTripMetricsUpdate: (Int, Int) -> Unit
) {
    var activeTaxiTripId by remember { mutableStateOf<String?>(null) }
    var passengerCount by remember { mutableIntStateOf(1) }
    var revenue by remember { mutableIntStateOf(0) }
    var totalEarnings by remember { mutableIntStateOf(0) }
    var tripsCompleted by remember { mutableIntStateOf(0) }

    // Earnings summary
    if (tripsCompleted > 0 || activeTaxiTripId != null) {
        Card(
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Row(modifier = Modifier.padding(14.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text("Today's Earnings", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    Text("P$totalEarnings", fontWeight = FontWeight.Bold, fontSize = 24.sp)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("Trips", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    Text("$tripsCompleted", fontWeight = FontWeight.Bold, fontSize = 24.sp)
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }

    if (hails.isNotEmpty()) {
        val latestHail = hails.last()
        val passengerId = latestHail.optString("passengerId")
        val serviceType = latestHail.optString("serviceType", "STANDARD")
        val requestId = latestHail.optString("requestId")
        val fareEstimate = latestHail.optInt("fareEstimate", 0)
        val pickup = latestHail.optJSONObject("pickupLoc")
        val destination = latestHail.optJSONObject("destinationLoc")

        Card(
            shape = RoundedCornerShape(18.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
        ) {
            Column {
                // Header
                Box(
                    modifier = Modifier.fillMaxWidth()
                        .background(
                            Brush.linearGradient(
                                listOf(Color(0xFFF59E0B), Color(0xFFEF4444))
                            )
                        )
                        .padding(16.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier.size(48.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.PersonPin, null, tint = Color.White, modifier = Modifier.size(28.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("New Ride Request!", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                            Text(serviceType, color = Color.White.copy(alpha = 0.8f), fontSize = 13.sp)
                        }
                        Spacer(Modifier.weight(1f))
                        if (fareEstimate > 0) {
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = Color.White.copy(alpha = 0.2f)
                            ) {
                                Text(
                                    "P$fareEstimate",
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                    fontWeight = FontWeight.Bold, color = Color.White, fontSize = 18.sp
                                )
                            }
                        }
                    }
                }

                // Details
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (pickup != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier.size(32.dp).clip(CircleShape).background(Color(0xFF10B981).copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.TripOrigin, null, tint = Color(0xFF10B981), modifier = Modifier.size(16.dp))
                            }
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text("Pickup", fontSize = 11.sp, color = Color.Gray)
                                Text("${pickup.optDouble("lat", 0.0).let { String.format("%.4f", it) }}, ${pickup.optDouble("lng", 0.0).let { String.format("%.4f", it) }}", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            }
                        }
                    }
                    if (destination != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier.size(32.dp).clip(CircleShape).background(Color(0xFFEF4444).copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.LocationOn, null, tint = Color(0xFFEF4444), modifier = Modifier.size(16.dp))
                            }
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text("Destination", fontSize = 11.sp, color = Color.Gray)
                                Text("${destination.optDouble("lat", 0.0).let { String.format("%.4f", it) }}, ${destination.optDouble("lng", 0.0).let { String.format("%.4f", it) }}", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            }
                        }
                    }

                    HorizontalDivider(color = Color.Gray.copy(alpha = 0.15f))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = {
                                val data = JSONObject().apply {
                                    put("passengerId", passengerId)
                                    put("driverId", driverId)
                                    put("routeId", routeId)
                                    if (requestId.isNotEmpty()) put("requestId", requestId)
                                }
                                SocketHandler.currentSocket?.emit("accept-hail", data)
                                val tripId = "trip-${UUID.randomUUID().toString().take(8)}"
                                activeTaxiTripId = tripId
                                revenue = if (fareEstimate > 0) fareEstimate else 0
                                SocketHandler.currentSocket?.emit("trip-start", JSONObject().apply {
                                    put("tripId", tripId)
                                    put("driverId", driverId)
                                    put("routeId", routeId)
                                    put("type", "TAXI")
                                    put("passengerCount", passengerCount)
                                    put("revenue", if (fareEstimate > 0) fareEstimate else revenue)
                                })
                                onRemoveHail(passengerId)
                            },
                            modifier = Modifier.weight(1f).height(52.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                        ) {
                            Icon(Icons.Default.Check, null, modifier = Modifier.size(20.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Accept", fontWeight = FontWeight.Bold)
                        }

                        OutlinedButton(
                            onClick = {
                                SocketHandler.currentSocket?.emit("reject-hail", JSONObject().apply {
                                    put("passengerId", passengerId)
                                    put("driverId", driverId)
                                    put("routeId", routeId)
                                    if (requestId.isNotEmpty()) put("requestId", requestId)
                                })
                                onRemoveHail(passengerId)
                            },
                            modifier = Modifier.weight(1f).height(52.dp),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            Icon(Icons.Default.Close, null, modifier = Modifier.size(20.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Decline")
                        }
                    }
                }
            }
        }
    } else if (activeTaxiTripId != null) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.tertiary.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.LocalTaxi, null, tint = MaterialTheme.colorScheme.tertiary, modifier = Modifier.size(22.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("Trip in Progress", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text("Meter is running", fontSize = 12.sp, color = Color.Gray)
                    }
                }

                OutlinedTextField(
                    value = passengerCount.toString(),
                    onValueChange = { passengerCount = it.toIntOrNull() ?: 1 },
                    label = { Text("Passengers") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = revenue.toString(),
                    onValueChange = { revenue = it.toIntOrNull() ?: 0 },
                    label = { Text("Fare (Pula)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
                Button(
                    onClick = {
                        totalEarnings += revenue
                        tripsCompleted++
                        onTripMetricsUpdate(passengerCount, revenue)
                        SocketHandler.currentSocket?.emit("trip-end", JSONObject().apply {
                            put("tripId", activeTaxiTripId)
                            put("passengerCount", passengerCount)
                            put("revenue", revenue)
                        })
                        activeTaxiTripId = null
                    },
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444)),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(Icons.Default.Stop, null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Complete Trip", fontWeight = FontWeight.Bold)
                }
            }
        }
    } else {
        Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.LocalTaxi, null, tint = Color.Gray.copy(alpha = 0.5f), modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(8.dp))
                Text("Waiting for ride requests...", color = Color.Gray, fontSize = 14.sp)
                Text("Keep your app open", color = Color.Gray.copy(alpha = 0.5f), fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun SpacingAdvisory(advisory: JSONObject?) {
    val ahead = advisory?.optString("ahead") ?: "0m"
    val behind = advisory?.optString("behind") ?: "0m"
    val status = advisory?.optString("status") ?: "--"
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("SPACING ADVISORY", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Ahead: $ahead", style = MaterialTheme.typography.bodySmall)
                Text("Behind: $behind", style = MaterialTheme.typography.bodySmall)
            }
            Text("STATUS: $status", color = Color.Red, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
fun AlertBadge(text: String, containerColor: Color) {
    Surface(shape = MaterialTheme.shapes.small, color = containerColor) {
        Text(text, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium)
    }
}
