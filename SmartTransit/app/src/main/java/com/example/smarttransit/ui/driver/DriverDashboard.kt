package com.example.smarttransit.ui.driver

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.smarttransit.model.UserRole
import com.example.smarttransit.network.SocketHandler
import com.example.smarttransit.ui.components.ConnectionBadge
import com.example.smarttransit.ui.components.SmartTransitMap
import com.example.smarttransit.ui.theme.AccentGreen
import com.example.smarttransit.ui.theme.AccentRed
import com.example.smarttransit.ui.theme.Black
import com.example.smarttransit.ui.theme.Disabled
import com.example.smarttransit.ui.theme.LightGrey
import com.example.smarttransit.ui.theme.MidGrey
import com.example.smarttransit.ui.theme.OffWhite
import com.example.smarttransit.ui.theme.White
import com.google.android.gms.location.*
import io.socket.client.Socket
import org.json.JSONObject
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.URL
import java.util.UUID
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

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
    val otherDrivers = remember { mutableStateMapOf<String, JSONObject>() }
    
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

    fun playStopAlert() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(context, uri)
            ringtone?.play()
        } catch (_: Exception) { }
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                manager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(400)
                }
            }
        } catch (_: Exception) { }
    }
    
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

    LaunchedEffect(routeId) {
        if (isOnline && routeId.isNotEmpty() && socket?.connected() == true) {
            socket.emit("driver-online", JSONObject().apply {
                put("driverId", driverId)
                put("routeId", routeId)
                put("status", "ONLINE")
                put("serviceType", if (currentRole == UserRole.DRIVER_TAXI) "TAXI" else "COMBI")
                put("driverType", currentRole.name)
            })
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
                    val loc = data?.optJSONObject("coords")
                    if (pId.isNotEmpty() && loc != null) {
                        passengerLocations[pId] = LatLng(loc.optDouble("lat"), loc.optDouble("lng"))
                    }
                }
            }

            socket.on("driver-location") { args ->
                if (args != null && args.isNotEmpty()) {
                    val data = if (args[0] is String) JSONObject(args[0] as String) else args[0] as? JSONObject
                    val dId = data?.optString("driverId") ?: ""
                    if (dId.isNotEmpty() && dId != driverId && data != null) {
                        otherDrivers[dId] = data
                    }
                }
            }

            socket.on("stop-request") { args ->
                if (args != null && args.isNotEmpty()) {
                    stopRequestCount++
                    (context as? android.app.Activity)?.runOnUiThread {
                        playStopAlert()
                        Toast.makeText(context, "🛑 STOP REQUEST RECEIVED!", Toast.LENGTH_LONG).show()
                    }
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
            socket.off("driver-location")
            socket.off("stop-request")
            socket.off("spacing-advisory")
        }
    }

    Scaffold(
        topBar = {
            DriverTopBar(
                title = when(currentRole) {
                    UserRole.DRIVER_BUS -> "Bus Driver"
                    UserRole.DRIVER_COMBI -> "Combi Driver"
                    UserRole.DRIVER_TAXI -> "Taxi Driver"
                    else -> "Driver"
                },
                isOnline = isOnline,
                gpsOk = userLocation != null,
                onToggleOnline = { isOnline = it }
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = White,
                modifier = Modifier.border(BorderStroke(0.5.dp, LightGrey))
            ) {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Dashboard, null) },
                    label = { Text("Service") },
                    colors = driverNavItemColors()
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Person, null) },
                    label = { Text("Profile") },
                    colors = driverNavItemColors()
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            if (selectedTab == 1) {
                DriverProfileScreen()
            } else {
                if (routeId.isEmpty() && currentRole != UserRole.DRIVER_TAXI) {
                    RouteSetupScreen(currentRole) { routeId = it }
                } else {
                    if (!isOnline) {
                        OfflineScreen()
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
                            drivers = otherDrivers.values.toList(),
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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(White)
            .padding(horizontal = 24.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text("Driver Profile", style = MaterialTheme.typography.headlineMedium, color = Black)

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = White),
            border = BorderStroke(1.dp, LightGrey),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Server URL", style = MaterialTheme.typography.labelSmall, color = MidGrey)

                if (isEditing) {
                    OutlinedTextField(
                        value = serverUrl,
                        onValueChange = { serverUrl = it },
                        label = { Text("Server URL") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = driverFieldColors()
                    )
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.End)) {
                        OutlinedButton(
                            onClick = { isEditing = false; serverUrl = SocketHandler.getCurrentUrl() },
                            shape = RoundedCornerShape(14.dp),
                            border = BorderStroke(1.dp, Black),
                            colors = ButtonDefaults.outlinedButtonColors(containerColor = White, contentColor = Black)
                        ) { Text("Cancel") }
                        Button(
                            onClick = {
                                SocketHandler.init(context, serverUrl)
                                SocketHandler.establishConnection()
                                isEditing = false
                                Toast.makeText(context, "Reconnecting to $serverUrl", Toast.LENGTH_SHORT).show()
                            },
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Black, contentColor = White),
                            elevation = null
                        ) { Text("Save") }
                    }
                } else {
                    Text(serverUrl, style = MaterialTheme.typography.bodyMedium, color = Black)
                    Button(
                        onClick = { isEditing = true },
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Black, contentColor = White),
                        elevation = null
                    ) { Text("Edit Server URL") }
                }
                Text(
                    "Note: For local development, use http://192.168.0.182:3000",
                    style = MaterialTheme.typography.labelSmall,
                    color = MidGrey
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

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(White)
            .padding(horizontal = 24.dp, vertical = 20.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(
                "Select Route",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Black
            )
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(if (isBus) "Search destination" else "Search route") },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = Black) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = driverFieldColors()
            )

            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Black, strokeWidth = 2.dp)
                }
            } else if (filtered.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("No ${if (isBus) "bus destinations" else "combi routes"} found", color = MidGrey)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(filtered) { r ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onRouteSet(r.routeId)
                                    Toast.makeText(context, "Selected: ${r.name}", Toast.LENGTH_SHORT).show()
                                },
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = White),
                            border = BorderStroke(1.dp, LightGrey),
                            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                        ) {
                            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(r.name, fontWeight = FontWeight.Bold, color = Black)
                                Text("${r.start} → ${r.end}", style = MaterialTheme.typography.bodyMedium, color = MidGrey)
                                Text("ID ${r.routeId}", style = MaterialTheme.typography.labelSmall, color = MidGrey)
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
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(White),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(Icons.Default.CloudOff, null, modifier = Modifier.size(64.dp), tint = Black)
            Text("You're offline", style = MaterialTheme.typography.titleMedium, color = Black)
            Text("Check your connection", style = MaterialTheme.typography.bodyMedium, color = MidGrey)
        }
    }
}

@Composable
fun DriverInterface(
    role: UserRole, sessionStarted: Boolean, onToggleSession: () -> Unit,
    hails: List<JSONObject>, onClearHails: () -> Unit,
    spacingAdvisory: JSONObject?, userLocation: LatLng?,
    drivers: List<JSONObject>, passengers: List<LatLng>, routeId: String,
    occupancy: String, onUpdateOccupancy: (String) -> Unit,
    stopRequestCount: Int, onClearStopRequests: () -> Unit,
    isConnected: Boolean, driverId: String, onRemoveHail: (String) -> Unit,
    onTripMetricsUpdate: (Int, Int) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize().background(White)) {
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            val hailPoints = hails.mapNotNull { 
                it.optJSONObject("pickupLoc")?.let { loc -> LatLng(loc.optDouble("lat"), loc.optDouble("lng")) }
            }
            val allPoints = passengers + hailPoints
            
            SmartTransitMap(
                userLocation = userLocation,
                drivers = drivers,
                passengers = allPoints
            )

            if (role == UserRole.DRIVER_COMBI && spacingAdvisory != null) {
                val status = spacingAdvisory.optString("status", "--")
                val chipColor = if (status.contains("slow", true) || status.contains("speed", true) || status.contains("warn", true)) AccentRed else AccentGreen
                Surface(
                    color = White,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(16.dp),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, chipColor),
                    shadowElevation = 2.dp
                ) {
                    Text(
                        "Spacing: $status",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        color = chipColor,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            if (stopRequestCount > 0) {
                Surface(
                    color = AccentRed,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 16.dp),
                    shape = RoundedCornerShape(16.dp),
                    shadowElevation = 4.dp
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Stop, null, tint = White)
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "Stop request received ($stopRequestCount)",
                            color = White,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(Modifier.width(12.dp))
                        TextButton(onClick = onClearStopRequests) {
                            Text("Acknowledge", color = White)
                        }
                    }
                }
            }

            val etaText = userLocation?.let { loc ->
                val nearest = passengers.minByOrNull { p -> distanceMeters(loc, p) }
                if (nearest != null) {
                    val dist = distanceMeters(loc, nearest)
                    val etaMin = if (dist > 0) ((dist / 1000.0) / 18.0 * 60.0).toInt() else 0
                    "Nearest pax: ${dist}m - ETA ${etaMin}m"
                } else null
            }
            if (etaText != null) {
                Surface(
                    color = White,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(16.dp),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, Black),
                    shadowElevation = 2.dp
                ) {
                    Text(
                        etaText,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = Black
                    )
                }
            }
            
            if (!isConnected) {
                Surface(
                    color = White,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(16.dp),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, AccentRed),
                    shadowElevation = 2.dp
                ) {
                    Text(
                        "Connection Lost. Reconnecting...",
                        color = AccentRed,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        style = MaterialTheme.typography.labelSmall,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
        }

        Surface(
            color = White,
            tonalElevation = 0.dp,
            shadowElevation = 0.dp,
            modifier = Modifier
                .fillMaxWidth()
                .border(BorderStroke(0.5.dp, LightGrey))
        ) {
                Column(
                    modifier = Modifier
                        .padding(horizontal = 24.dp, vertical = 16.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    if (routeId.isNotBlank()) {
                        Card(
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = OffWhite),
                            border = BorderStroke(1.dp, LightGrey)
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Icon(Icons.Default.Lock, null, tint = Black, modifier = Modifier.size(18.dp))
                                Column {
                                    Text("Route Locked", fontWeight = FontWeight.Bold, color = Black, fontSize = 13.sp)
                                    Text(routeId, color = MidGrey, fontSize = 12.sp)
                                }
                            }
                        }
                    }
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
        Text(locationLabel, fontWeight = FontWeight.Bold, color = Black)
        Button(
            onClick = onToggleSession, 
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Black, contentColor = White),
            elevation = null
        ) { 
            Text(if (role == UserRole.DRIVER_BUS) "Start Location Session" else "Start Route Session", fontSize = MaterialTheme.typography.titleMedium.fontSize) 
        }
    } else {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text("ACTIVE SERVICE", color = MidGrey, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                val locationLabel = if (role == UserRole.DRIVER_BUS) "Location: $routeId" else "Route: $routeId"
                Text(locationLabel, style = MaterialTheme.typography.titleMedium, color = Black)
            }
            OutlinedButton(
                onClick = onToggleSession,
                shape = RoundedCornerShape(14.dp),
                border = BorderStroke(1.dp, Black),
                colors = ButtonDefaults.outlinedButtonColors(containerColor = White, contentColor = Black)
            ) { Text("End Shift") }
        }
        
        if (stopRequestCount > 0) {
            Card(
                colors = CardDefaults.cardColors(containerColor = White),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, LightGrey),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(48.dp)
                            .background(AccentRed, RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("STOP REQUESTS", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelSmall, color = AccentRed)
                        Text("$stopRequestCount", fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.headlineMedium, color = AccentRed)
                    }
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = onClearStopRequests) { Icon(Icons.Default.Close, null) }
                }
            }
        }

        if (hails.isNotEmpty()) {
            Card(
                colors = CardDefaults.cardColors(containerColor = White),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, LightGrey),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(48.dp)
                            .background(Black, RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                    )
                    Spacer(Modifier.width(12.dp))
                    Text("${hails.size} Active Hails", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium, color = Black)
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
        
        Column(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
            Text("OCCUPANCY STATUS", style = MaterialTheme.typography.labelSmall, color = MidGrey)
            Text(occupancy, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.ExtraBold, color = Black)
            Spacer(Modifier.height(10.dp))
            val levels = listOf("Empty", "Half Full", "Almost Full", "Full")
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                items(levels) { level ->
                    FilterChip(
                        selected = occupancy.equals(level, ignoreCase = true),
                        onClick = { onUpdateOccupancy(level) },
                        label = { Text(level) },
                        border = BorderStroke(1.dp, if (occupancy.equals(level, ignoreCase = true)) Black else LightGrey),
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = White,
                            selectedContainerColor = White,
                            labelColor = MidGrey,
                            selectedLabelColor = Black
                        )
                    )
                }
            }
        }
    }
}

fun reverseGeocode(lat: Double, lng: Double, onResult: (String) -> Unit) {
    kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.IO) {
        try {
            val url = java.net.URL("https://nominatim.openstreetmap.org/reverse-format=json&lat=$lat&lon=$lng&zoom=16&addressdetails=1")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.setRequestProperty("User-Agent", "SmartTransit/1.0")
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            val body = conn.inputStream.bufferedReader().readText()
            val obj = org.json.JSONObject(body)
            val address = obj.optJSONObject("address")
            val label = when {
                address?.has("road") == true && address.has("suburb") ->
                    "${address.optString("road")}, ${address.optString("suburb")}"
                address?.has("road") == true ->
                    "${address.optString("road")}, ${address.optString("city", address.optString("town", ""))}"
                else -> obj.optString("display_name", "").split(",").take(2).joinToString(", ")
            }
            withContext(kotlinx.coroutines.Dispatchers.Main) { onResult(label.trim().trimEnd(',')) }
        } catch (_: Exception) {
            withContext(kotlinx.coroutines.Dispatchers.Main) {
                onResult("${String.format("%.4f", lat)}, ${String.format("%.4f", lng)}")
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
    var pickupAddress by remember { mutableStateOf("Locating…") }
    var destinationAddress by remember { mutableStateOf("Locating…") }

    val latestHailForGeo = hails.lastOrNull()
    LaunchedEffect(latestHailForGeo?.optString("passengerId")) {
        pickupAddress = "Locating…"
        destinationAddress = "Locating…"
        latestHailForGeo?.optJSONObject("pickupLoc")?.let { loc ->
            reverseGeocode(loc.optDouble("lat"), loc.optDouble("lng")) { pickupAddress = it }
        }
        latestHailForGeo?.optJSONObject("destinationLoc")?.let { loc ->
            reverseGeocode(loc.optDouble("lat"), loc.optDouble("lng")) { destinationAddress = it }
        }
    }

    if (tripsCompleted > 0 || activeTaxiTripId != null) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = White),
            border = BorderStroke(1.dp, LightGrey),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Row(modifier = Modifier.padding(14.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text("TODAY'S EARNINGS", style = MaterialTheme.typography.labelSmall, color = MidGrey, letterSpacing = 1.sp)
                    Text("P$totalEarnings", fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, color = Black)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("TRIPS", style = MaterialTheme.typography.labelSmall, color = MidGrey, letterSpacing = 1.sp)
                    Text("$tripsCompleted", fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, color = Black)
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
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = White),
            border = BorderStroke(1.dp, LightGrey),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(44.dp)
                            .background(AccentGreen, RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("New Ride Request", fontWeight = FontWeight.Bold, color = Black, fontSize = 16.sp)
                        Text(serviceType, color = MidGrey, fontSize = 13.sp)
                    }
                    if (fareEstimate > 0) {
                        Surface(shape = RoundedCornerShape(20.dp), color = Black) {
                            Text(
                                "P$fareEstimate",
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                                fontWeight = FontWeight.Bold,
                                color = White,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
                HorizontalDivider(color = LightGrey)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (pickup != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(10.dp).background(Black, CircleShape))
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text("PICKUP", fontSize = 10.sp, color = MidGrey, letterSpacing = 0.8.sp)
                                Text(pickupAddress, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Black)
                            }
                        }
                    }
                    if (destination != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.LocationOn, null, tint = Black, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text("DROP-OFF", fontSize = 10.sp, color = MidGrey, letterSpacing = 0.8.sp)
                                Text(destinationAddress, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Black)
                            }
                        }
                    }

                    HorizontalDivider(color = LightGrey)

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
                            colors = ButtonDefaults.buttonColors(containerColor = Black, contentColor = White),
                            elevation = null
                        ) {
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
                            shape = RoundedCornerShape(14.dp),
                            border = BorderStroke(1.dp, Black),
                            colors = ButtonDefaults.outlinedButtonColors(containerColor = White, contentColor = Black)
                        ) {
                            Text("Decline")
                        }
                    }
                }
            }
        }
    } else if (activeTaxiTripId != null) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = White),
            border = BorderStroke(1.dp, LightGrey),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(40.dp)
                            .background(AccentGreen, RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                    )
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("Trip in Progress", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Black)
                        Text("Meter running", fontSize = 12.sp, color = MidGrey)
                    }
                }

                OutlinedTextField(
                    value = passengerCount.toString(),
                    onValueChange = { passengerCount = it.toIntOrNull() ?: 1 },
                    label = { Text("Passengers") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true,
                    colors = driverFieldColors()
                )
                OutlinedTextField(
                    value = revenue.toString(),
                    onValueChange = { revenue = it.toIntOrNull() ?: 0 },
                    label = { Text("Fare (Pula)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true,
                    colors = driverFieldColors()
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
                    colors = ButtonDefaults.buttonColors(containerColor = AccentRed, contentColor = White),
                    shape = RoundedCornerShape(14.dp),
                    elevation = null
                ) {
                    Text("Complete Trip", fontWeight = FontWeight.Bold)
                }
            }
        }
    } else {
        Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.LocalTaxi, null, tint = MidGrey, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(8.dp))
                Text("Waiting for ride requests...", color = Black, fontSize = 14.sp)
                Text("Keep your app open", color = MidGrey, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun SpacingAdvisory(advisory: JSONObject?) {
    if (advisory == null) {
        Card(
            colors = CardDefaults.cardColors(containerColor = White),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, LightGrey),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("SPACING ADVISORY", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MidGrey)
                Text("Waiting for spacing data…", style = MaterialTheme.typography.bodySmall, color = MidGrey)
            }
        }
        return
    }
    val ahead = advisory?.optString("ahead") ?: "0m"
    val behind = advisory?.optString("behind") ?: "0m"
    val status = advisory?.optString("status") ?: "--"
    Card(
        colors = CardDefaults.cardColors(containerColor = White),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, LightGrey),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("SPACING ADVISORY", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MidGrey)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Ahead: $ahead", style = MaterialTheme.typography.bodySmall, color = Black, fontWeight = FontWeight.Bold)
                Text("Behind: $behind", style = MaterialTheme.typography.bodySmall, color = Black, fontWeight = FontWeight.Bold)
            }
            val statusColor = if (status.contains("warn", true) || status.contains("behind", true) || status.contains("slow", true) || status.contains("speed", true)) AccentRed else AccentGreen
            Text("STATUS: $status", color = statusColor, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

private fun distanceMeters(a: LatLng, b: LatLng): Int {
    val r = 6371e3
    val lat1 = a.latitude * Math.PI / 180
    val lat2 = b.latitude * Math.PI / 180
    val dLat = (b.latitude - a.latitude) * Math.PI / 180
    val dLng = (b.longitude - a.longitude) * Math.PI / 180
    val calc = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
    return (r * 2 * atan2(sqrt(calc), sqrt(1 - calc))).toInt()
}

@Composable
fun AlertBadge(text: String, containerColor: Color) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = White,
        border = BorderStroke(1.dp, if (containerColor == MaterialTheme.colorScheme.errorContainer) AccentRed else Black)
    ) {
        Text(
            text,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            color = if (containerColor == MaterialTheme.colorScheme.errorContainer) AccentRed else Black
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DriverTopBar(
    title: String,
    isOnline: Boolean,
    gpsOk: Boolean,
    onToggleOnline: (Boolean) -> Unit
) {
    val pillColor by animateColorAsState(if (isOnline) Black else LightGrey, label = "onlinePill")
    val textColor by animateColorAsState(if (isOnline) White else Black, label = "onlineText")
    Surface(
        color = White,
        modifier = Modifier
            .fillMaxWidth()
            .border(BorderStroke(0.5.dp, LightGrey)),
        shadowElevation = 0.dp,
        tonalElevation = 0.dp
    ) {
        CenterAlignedTopAppBar(
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = White, titleContentColor = Black),
            navigationIcon = {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 8.dp)) {
                    Box(modifier = Modifier.size(40.dp), contentAlignment = Alignment.Center) {
                        Text(
                            "ST",
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.8).sp),
                            color = Black
                        )
                    }
                }
            },
            title = {
                Text(title, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = Black)
            },
            actions = {
                Surface(
                    color = if (gpsOk) AccentGreen else LightGrey,
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Text(
                        if (gpsOk) "GPS: OK" else "GPS: Waiting",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        color = if (gpsOk) White else Black,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                Spacer(Modifier.width(8.dp))
                Surface(
                    color = pillColor,
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.clickable { onToggleOnline(!isOnline) }
                ) {
                    Text(
                        if (isOnline) "Online" else "Offline",
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                        color = textColor,
                        style = MaterialTheme.typography.labelLarge
                    )
                }
                Spacer(Modifier.width(10.dp))
                ConnectionBadge(Modifier.padding(end = 16.dp))
            }
        )
    }
}

@Composable
private fun driverNavItemColors() = NavigationBarItemDefaults.colors(
    selectedIconColor = Black,
    selectedTextColor = Black,
    unselectedIconColor = MidGrey,
    unselectedTextColor = MidGrey,
    indicatorColor = White
)

@Composable
private fun driverFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = White,
    unfocusedContainerColor = White,
    disabledContainerColor = White,
    focusedBorderColor = Black,
    unfocusedBorderColor = LightGrey,
    focusedTextColor = Black,
    unfocusedTextColor = Black,
    focusedLabelColor = Black,
    unfocusedLabelColor = MidGrey,
    cursorColor = Black,
    focusedLeadingIconColor = Black,
    unfocusedLeadingIconColor = Black
)
