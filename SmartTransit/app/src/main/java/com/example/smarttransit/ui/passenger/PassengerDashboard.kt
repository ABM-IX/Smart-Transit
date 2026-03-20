package com.example.smarttransit.ui.passenger

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
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import com.google.android.gms.maps.model.LatLng
import java.net.URL
import java.util.UUID
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

enum class TransportMode { BUS, COMBI, TAXI }

private fun toJson(any: Any?): Any? = when (any) {
    is JSONObject -> any
    is org.json.JSONArray -> any
    is Map<*, *> -> {
        val obj = JSONObject()
        any.forEach { (k, v) -> if (k != null) obj.put(k.toString(), toJson(v)) }
        obj
    }
    is List<*> -> {
        val arr = org.json.JSONArray()
        any.forEach { arr.put(toJson(it)) }
        arr
    }
    else -> any
}

private fun parseJson(arg: Any?): JSONObject? = when (arg) {
    is JSONObject -> arg
    is String -> runCatching { JSONObject(arg) }.getOrNull()
    else -> (toJson(arg) as? JSONObject)
}

private fun occupancyLabel(raw: String): String {
    val clean = raw.trim().lowercase()
    return when {
        clean.isBlank() -> "Unknown"
        clean.contains("empty") -> "Empty"
        clean.contains("almost") -> "Almost Full"
        clean.contains("half") -> "Half Full"
        clean.contains("full") -> "Full"
        else -> raw
    }
}

private fun movementLabel(speedMs: Double): String {
    if (speedMs.isNaN() || speedMs < 0.5) return "Stopped"
    if (speedMs < 3.0) return "Slow"
    return "Moving"
}

private fun distanceMeters(a: LatLng, b: LatLng): Int {
    val r = 6371000.0
    val dLat = Math.toRadians(b.latitude - a.latitude)
    val dLon = Math.toRadians(b.longitude - a.longitude)
    val lat1 = Math.toRadians(a.latitude)
    val lat2 = Math.toRadians(b.latitude)
    val h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    val c = 2 * atan2(sqrt(h), sqrt(1 - h))
    return (r * c).roundToInt()
}

private fun etaMinutes(distanceMeters: Int, speedMs: Double): Int {
    val safeSpeed = if (speedMs.isNaN() || speedMs <= 0.5) 4.0 else speedMs
    val minutes = distanceMeters / safeSpeed / 60.0
    return max(1, minutes.roundToInt())
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PassengerDashboard() {
    var selectedMode by remember { mutableStateOf<TransportMode?>(null) }
    
    if (selectedMode == null) {
        Scaffold(
            containerColor = White,
            topBar = {
                PassengerTopBar(title = "SmartTransit")
            }
        ) { padding ->
            Column(
                Modifier
                    .padding(padding)
                    .fillMaxSize()
                    .background(White)
            ) {
                ModeSelectionScreen(Modifier.fillMaxSize()) { selectedMode = it }
            }
        }
    } else {
        when (selectedMode!!) {
            TransportMode.BUS, TransportMode.COMBI -> BusCombiFlow(selectedMode!!) { selectedMode = null }
            TransportMode.TAXI -> TaxiFlow { selectedMode = null }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusCombiFlow(mode: TransportMode, onBack: () -> Unit) {
    var selectedRoute by remember { mutableStateOf<RouteItem?>(null) }
    
    Scaffold(
        containerColor = White,
        topBar = {
            PassengerTopBar(
                title = if (selectedRoute == null) "Select Route" else selectedRoute!!.name,
                onBack = { if (selectedRoute == null) onBack() else selectedRoute = null }
            )
        }
    ) { padding ->
        if (selectedRoute == null) {
            DestinationsBrowserScreen(mode, Modifier.padding(padding)) { route ->
                selectedRoute = route
            }
        } else {
            BusCombiMapScreen(
                mode = mode,
                route = selectedRoute!!,
                modifier = Modifier.padding(padding),
                onExitToMain = onBack
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("MissingPermission")
@Composable
fun BusCombiMapScreen(mode: TransportMode, route: RouteItem, modifier: Modifier, onExitToMain: () -> Unit) {
    val passengerId = remember { "p-${UUID.randomUUID().toString().take(8)}" }
    var boarded by remember { mutableStateOf(false) }
    var boardedDriverId by remember { mutableStateOf<String?>(null) }
    var showRating by remember { mutableStateOf(false) }
    var complaintText by remember { mutableStateOf("") }
    var showThankYou by remember { mutableStateOf(false) }
    val socket = SocketHandler.currentSocket
    var isConnected by remember { mutableStateOf(SocketHandler.isConnected) }
    val driverLocations = remember { mutableStateMapOf<String, JSONObject>() }
    var userLocation by remember { mutableStateOf<LatLng?>(null) }
    var isHailing by remember { mutableStateOf(false) }
    var hailAcceptedDriverId by remember { mutableStateOf<String?>(null) }
    var etaSeconds by remember { mutableIntStateOf(0) }
    var etaDistanceMeters by remember { mutableIntStateOf(0) }
    val etaByDriver = remember { mutableStateMapOf<String, Pair<Int, Int>>() }
    var lastPassengerPingAt by remember { mutableLongStateOf(0L) }
    var searchTimedOut by remember { mutableStateOf(false) }
    var lastDriverSeenAt by remember { mutableLongStateOf(0L) }
    var routeStops by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var routePolyline by remember { mutableStateOf<List<LatLng>>(emptyList()) }
    val scope = rememberCoroutineScope()
    val retrySearch = {
        searchTimedOut = false
        lastDriverSeenAt = 0L
        hailAcceptedDriverId = null
        if (socket?.connected() == true) {
            socket.emit("join", JSONObject().apply {
                put("role", "passengers")
                put("routeId", route.routeId)
                put("passengerId", passengerId)
            })
            socket.emit("subscribe-route", JSONObject().apply {
                put("role", "passengers")
                put("routeId", route.routeId)
            })
        }
    }

    fun refreshDriverDetails(targetDriverId: String?) {
        if (targetDriverId.isNullOrBlank()) return
        scope.launch(Dispatchers.IO) {
            try {
                val url = URL("${SocketHandler.getCurrentUrl()}/api/state")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.setRequestProperty("bypass-tunnel-reminder", "true")
                conn.connectTimeout = 1500
                conn.readTimeout = 1500
                val body = conn.inputStream.bufferedReader().readText()
                val obj = JSONObject(body)
                val drivers = obj.optJSONArray("drivers") ?: JSONArray()
                var matched: JSONObject? = null
                for (i in 0 until drivers.length()) {
                    val d = drivers.getJSONObject(i)
                    val driverId = d.optString("driverId")
                    if (driverId == targetDriverId) {
                        matched = d
                        break
                    }
                }
                if (matched != null) {
                    withContext(Dispatchers.Main) {
                        val id = matched.optString("driverId")
                        if (id.isNotBlank()) {
                            driverLocations[id] = matched
                            lastDriverSeenAt = System.currentTimeMillis()
                            searchTimedOut = false
                        }
                    }
                }
            } catch (_: Exception) { }
        }
    }
    
    val context = LocalContext.current
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    
    DisposableEffect(Unit) {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000).build()
        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    userLocation = LatLng(location.latitude, location.longitude)
                    if (isConnected && socket?.connected() == true) {
                        val now = System.currentTimeMillis()
                        if (now - lastPassengerPingAt >= 4000) {
                            lastPassengerPingAt = now
                            socket.emit("passenger-location", JSONObject().apply {
                                put("passengerId", passengerId)
                                put("routeId", route.routeId)
                                put("coords", JSONObject().apply {
                                    put("lat", location.latitude)
                                    put("lng", location.longitude)
                                })
                                put("timestamp", now)
                            })
                        }
                    }
                }
            }
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        }
        onDispose { fusedLocationClient.removeLocationUpdates(locationCallback) }
    }

    LaunchedEffect(Unit) { SocketHandler.establishConnection() }

    LaunchedEffect(route.routeId) {
        withContext(Dispatchers.IO) {
            try {
                val url = URL("${SocketHandler.getCurrentUrl()}/api/stops?routeId=${route.routeId}")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.setRequestProperty("bypass-tunnel-reminder", "true")
                conn.connectTimeout = 1500
                conn.readTimeout = 1500
                val body = conn.inputStream.bufferedReader().readText()
                val arr = JSONArray(body)
                val list = (0 until arr.length()).map { i -> arr.getJSONObject(i) }
                withContext(Dispatchers.Main) { 
                    routeStops = list
                    routePolyline = list.mapNotNull { s ->
                        val lat = s.optDouble("latitude", Double.NaN)
                        val lng = s.optDouble("longitude", Double.NaN)
                        if (lat.isNaN() || lng.isNaN()) null else LatLng(lat, lng)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { 
                    routeStops = emptyList()
                    routePolyline = emptyList()
                }
            }
        }
    }

    DisposableEffect(socket, route.routeId) {
        if (socket == null) return@DisposableEffect onDispose { }

        val activity = context as? android.app.Activity
        fun joinRooms() {
            socket.emit("join", JSONObject().apply { 
                put("role", "passengers")
                put("routeId", route.routeId)
                put("passengerId", passengerId) 
            })
            socket.emit("subscribe-route", JSONObject().apply { 
                put("role", "passengers")
                put("routeId", route.routeId) 
            })
        }

        socket.on("connect") {
            activity?.runOnUiThread { isConnected = true }
            joinRooms()
        }
        socket.on("disconnect") {
            activity?.runOnUiThread { isConnected = false }
        }
        if (socket.connected()) {
            isConnected = true
            joinRooms()
        }

        socket.on("driver-location") { args ->
            val data = parseJson(args.firstOrNull())
            val dId = data?.optString("driverId") ?: ""
            val routeId = data?.optString("routeId") ?: ""
            if (dId.isNotEmpty() && data != null) {
                if (routeId.isBlank() || routeId != route.routeId) return@on
                activity?.runOnUiThread {
                    driverLocations[dId] = data
                    lastDriverSeenAt = System.currentTimeMillis()
                    searchTimedOut = false
                }
            }
        }
        socket.on("vehicle-update") { args ->
            val data = parseJson(args.firstOrNull())
            val dId = data?.optString("driverId") ?: ""
            val routeId = data?.optString("routeId") ?: ""
            if (dId.isNotEmpty() && data != null) {
                if (routeId.isBlank() || routeId != route.routeId) return@on
                activity?.runOnUiThread {
                    driverLocations[dId] = data
                    lastDriverSeenAt = System.currentTimeMillis()
                    searchTimedOut = false
                }
            }
        }
        socket.on("eta-update") { args ->
            val data = parseJson(args.firstOrNull())
            activity?.runOnUiThread { 
                etaSeconds = data?.optInt("etaSeconds") ?: 0
                etaDistanceMeters = data?.optInt("distanceMeters") ?: 0
                val dId = data?.optString("driverId") ?: ""
                if (dId.isNotBlank()) {
                    etaByDriver[dId] = Pair(etaSeconds, etaDistanceMeters)
                }
            }
        }
        socket.on("boarding-confirmed") {
            val obj = parseJson(it.firstOrNull())
            activity?.runOnUiThread {
                boarded = true
                boardedDriverId = obj?.optString("driverId")
                Toast.makeText(context, "Boarded ${route.name}!", Toast.LENGTH_SHORT).show()
            }
        }
        socket.on("hail-error") { args ->
            val data = parseJson(args.firstOrNull())
            activity?.runOnUiThread {
                isHailing = false
                hailAcceptedDriverId = null
                val reason = data?.optString("reason") ?: "Hail failed"
                Toast.makeText(context, reason, Toast.LENGTH_SHORT).show()
            }
        }
        socket.on("hail-warning") { args ->
            val data = parseJson(args.firstOrNull())
            activity?.runOnUiThread {
                val reason = data?.optString("reason") ?: "Hail warning"
                Toast.makeText(context, reason, Toast.LENGTH_SHORT).show()
            }
        }
        socket.on("hail-rejected") { args ->
            activity?.runOnUiThread {
                isHailing = false
                hailAcceptedDriverId = null
                Toast.makeText(context, "Hail cancelled or expired", Toast.LENGTH_SHORT).show()
            }
        }
        socket.on("hail-accepted") { args ->
            val data = parseJson(args.firstOrNull())
            activity?.runOnUiThread {
                isHailing = false
                hailAcceptedDriverId = data?.optString("driverId")?.takeIf { it.isNotBlank() }
                lastDriverSeenAt = System.currentTimeMillis()
                searchTimedOut = false
                val label = hailAcceptedDriverId?.let { " by $it" } ?: ""
                Toast.makeText(context, "Hail accepted$label", Toast.LENGTH_SHORT).show()
            }
            refreshDriverDetails(hailAcceptedDriverId)
        }
        socket.on("stop-request-error") { args ->
            val data = parseJson(args.firstOrNull())
            activity?.runOnUiThread {
                val reason = data?.optString("reason") ?: "Stop request rejected"
                Toast.makeText(context, reason, Toast.LENGTH_SHORT).show()
            }
        }
        onDispose {
            socket.off("connect")
            socket.off("disconnect")
            socket.off("driver-location")
            socket.off("vehicle-update")
            socket.off("eta-update")
            socket.off("boarding-confirmed")
            socket.off("hail-error")
            socket.off("hail-warning")
            socket.off("hail-rejected")
            socket.off("hail-accepted")
            socket.off("stop-request-error")
        }
    }

    Scaffold(
        bottomBar = {
            Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface).padding(16.dp)) {
                if (driverLocations.isNotEmpty() && !boarded) {
                    val etaText = if (etaSeconds > 0) "Nearest in ~${etaSeconds / 60} min (${etaDistanceMeters}m)" else "Nearby vehicles found"
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Timer, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(etaText, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.height(8.dp))
                } else if (driverLocations.isEmpty() && isHailing) {
                    Text("Hail sent. Onboard...", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                } else if (driverLocations.isEmpty() && hailAcceptedDriverId != null) {
                    Text("Driver ${hailAcceptedDriverId} accepted. On the way...", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                } else if (driverLocations.isEmpty() && !searchTimedOut) {
                    Text("Searching for available ${mode.name.lowercase()}s...", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                } else if (driverLocations.isEmpty() && searchTimedOut && !isHailing && hailAcceptedDriverId == null) {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("No active vehicles found yet", fontWeight = FontWeight.Bold)
                            Text("Check the route ID and ensure drivers are online.", style = MaterialTheme.typography.bodySmall)
                            Spacer(Modifier.height(8.dp))
                            Button(onClick = retrySearch) { Text("Retry") }
                        }
                    }
                }

                val currentUserLocation = userLocation
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Approaching Vehicles", fontWeight = FontWeight.Bold)
                    if (driverLocations.isEmpty()) {
                        Text("No active vehicles yet", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                    } else {
                        val closest = if (currentUserLocation != null) {
                            driverLocations.values
                                .mapNotNull { d ->
                                    val coords = d.optJSONObject("coords")
                                    if (coords != null) {
                                        val dist = distanceMeters(
                                            LatLng(coords.optDouble("lat"), coords.optDouble("lng")),
                                            currentUserLocation
                                        )
                                        d to dist
                                    } else null
                                }
                                .sortedBy { it.second }
                                .take(3)
                        } else {
                            driverLocations.values.take(3).map { it to -1 }
                        }

                        closest.forEach { (d, distMeters) ->
                            val occupancy = occupancyLabel(d.optString("occupancy", "Unknown"))
                            val routeLabel = d.optString("routeId", route.name)
                            val speedMs = d.optDouble("speed", 0.0)
                            val movement = movementLabel(speedMs)
                            val eta = etaByDriver[d.optString("driverId")]?.first
                            val etaText = if (eta != null && eta > 0) {
                                "${eta / 60} min"
                            } else if (distMeters >= 0) {
                                "${etaMinutes(distMeters, speedMs)} min"
                            } else {
                                "--"
                            }
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Column {
                                    Text("Vehicle ${d.optString("driverId")}", fontWeight = FontWeight.SemiBold)
                                    Text("Route: $routeLabel", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                                    Text("Movement: $movement - ${Math.round(speedMs * 3.6)} km/h", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                                }
                                Column(horizontalAlignment = Alignment.End) {
                                    Text(if (distMeters >= 0) "$distMeters m" else "Distance --", style = MaterialTheme.typography.bodySmall)
                                    Text("ETA $etaText", style = MaterialTheme.typography.bodySmall)
                                    Text(occupancy, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                if (driverLocations.isNotEmpty()) {
                    val driverForDetails = hailAcceptedDriverId?.let { driverLocations[it] } ?: run {
                        if (currentUserLocation == null) {
                            driverLocations.values.firstOrNull()
                        } else {
                            driverLocations.values
                                .mapNotNull { d ->
                                    val coords = d.optJSONObject("coords")
                                    if (coords != null) {
                                        val dist = distanceMeters(
                                            LatLng(coords.optDouble("lat"), coords.optDouble("lng")),
                                            currentUserLocation
                                        )
                                        d to dist
                                    } else null
                                }
                                .minByOrNull { it.second }
                                ?.first
                        }
                    }

                    if (driverForDetails != null) {
                        val driverId = driverForDetails.optString("driverId", "Unknown")
                        val vehicleId = driverForDetails.optString("vehicleId", "Unknown")
                        val occupancy = occupancyLabel(driverForDetails.optString("occupancy", "Unknown"))
                        val speedMps = driverForDetails.optDouble("speed", Double.NaN)
                        val heading = driverForDetails.optDouble("heading", Double.NaN)
                        val serviceType = driverForDetails.optString("serviceType", driverForDetails.optString("driverType", "Unknown"))
                        val routeId = driverForDetails.optString("routeId", "Unknown")
                        val status = driverForDetails.optString("status", "Unknown")
                        val lastUpdate = driverForDetails.optLong("lastUpdate", 0L)

                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text("Vehicle Details", fontWeight = FontWeight.Bold)
                                Text("Driver: $driverId", style = MaterialTheme.typography.bodySmall)
                                Text("Vehicle: $vehicleId", style = MaterialTheme.typography.bodySmall)
                                Text("Occupancy: $occupancy", style = MaterialTheme.typography.bodySmall)
                                Text("Service: ${serviceType.replace("_", " ")}", style = MaterialTheme.typography.bodySmall)
                                Text("Route: $routeId", style = MaterialTheme.typography.bodySmall)
                                Text("Status: $status", style = MaterialTheme.typography.bodySmall)
                                if (!speedMps.isNaN()) {
                                    val kmh = (speedMps * 3.6).toInt()
                                    Text("Speed: ${kmh} km/h", style = MaterialTheme.typography.bodySmall)
                                }
                                if (!heading.isNaN()) {
                                    Text("Heading: ${heading.toInt()} deg", style = MaterialTheme.typography.bodySmall)
                                }
                                if (etaSeconds > 0) {
                                    val mins = etaSeconds / 60
                                    val secs = etaSeconds % 60
                                    val etaText = if (mins > 0) {
                                        "${mins} min ${secs} sec"
                                    } else {
                                        "${secs} sec"
                                    }
                                    val distanceText = if (etaDistanceMeters >= 1000) {
                                        val km = etaDistanceMeters / 1000.0
                                        String.format("%.1f km", km)
                                    } else {
                                        "${etaDistanceMeters} m"
                                    }
                                    Text("ETA: ~$etaText ($distanceText)", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                                }
                                if (lastUpdate > 0L) {
                                    val secondsAgo = ((System.currentTimeMillis() - lastUpdate) / 1000).toInt()
                                    Text("Last update: ${secondsAgo}s ago", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                                }
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }

                    BusCombiActions(mode, boarded, route.routeId, passengerId, userLocation, isHailing, hailAcceptedDriverId != null, { next ->
                    isHailing = next
                    if (next) {
                        searchTimedOut = false
                        lastDriverSeenAt = System.currentTimeMillis()
                        hailAcceptedDriverId = null
                    } else {
                        hailAcceptedDriverId = null
                    }
                }, {
                    if (!boarded) {
                        boarded = true
                        socket?.emit("boarding", JSONObject().apply { put("passengerId", passengerId); put("routeId", route.routeId) })
                    } else {
                        boarded = false
                        if (boardedDriverId != null) showRating = true
                    }
                })
            }
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            SmartTransitMap(
                userLocation = userLocation, 
                drivers = driverLocations.values.toList(),
                stops = routeStops,
                routePoints = routePolyline
            )
            if (boarded && boardedDriverId != null) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    modifier = Modifier.padding(12.dp).align(Alignment.TopCenter)
                ) {
                    Text(
                        "Onboard: ${boardedDriverId}",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            if (showRating && boardedDriverId != null) {
                RatingOverlay(
                    driverId = boardedDriverId!!,
                    passengerId = passengerId,
                    complaintText = complaintText,
                    onComplaintChange = { complaintText = it },
                    onSubmit = {
                        showRating = false
                        showThankYou = true
                    },
                    onDismiss = {
                        showRating = false
                        showThankYou = true
                    }
                )
            }
            if (showThankYou) {
                ThankYouOverlay()
            }
            if (!isConnected) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
        }
    }

    LaunchedEffect(isConnected, route.routeId) {
        searchTimedOut = false
        lastDriverSeenAt = 0L
        hailAcceptedDriverId = null
        if (!isConnected) return@LaunchedEffect
        kotlinx.coroutines.delay(5000)
        if (!isHailing && hailAcceptedDriverId == null && driverLocations.isEmpty() && (System.currentTimeMillis() - lastDriverSeenAt) >= 5000) {
            searchTimedOut = true
        }
    }

    LaunchedEffect(hailAcceptedDriverId) {
        refreshDriverDetails(hailAcceptedDriverId)
    }

    LaunchedEffect(route.routeId) {
        while (true) {
            kotlinx.coroutines.delay(5000)
            try {
                val url = URL("${SocketHandler.getCurrentUrl()}/api/state")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.setRequestProperty("bypass-tunnel-reminder", "true")
                conn.connectTimeout = 1500
                conn.readTimeout = 1500
                val body = conn.inputStream.bufferedReader().readText()
                val obj = JSONObject(body)
                val drivers = obj.optJSONArray("drivers")
                if (drivers != null) {
                    val updates = mutableMapOf<String, JSONObject>()
                    for (i in 0 until drivers.length()) {
                        val d = drivers.getJSONObject(i)
                        val routeId = d.optString("routeId")
                        val serviceType = d.optString("serviceType")
                        if (routeId == route.routeId && serviceType != "TAXI") {
                            val driverId = d.optString("driverId")
                            if (driverId.isNotEmpty()) updates[driverId] = d
                        }
                    }
                    withContext(Dispatchers.Main) {
                        updates.forEach { (id, d) -> driverLocations[id] = d }
                        if (updates.isNotEmpty()) {
                            lastDriverSeenAt = System.currentTimeMillis()
                            searchTimedOut = false
                        }
                    }
                }
            } catch (_: Exception) { }
        }
    }

    LaunchedEffect(showThankYou) {
        if (showThankYou) {
            kotlinx.coroutines.delay(1500)
            showThankYou = false
            boarded = false
            boardedDriverId = null
            onExitToMain()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaxiFlow(onBack: () -> Unit) {
    var selectedTab by remember { mutableIntStateOf(0) }
    
    Scaffold(
        containerColor = White,
        topBar = {
            PassengerTopBar(
                title = when(selectedTab) { 0 -> "Get Taxi"; 1 -> "Trip History"; else -> "Profile" },
                onBack = onBack
            )
        },
        bottomBar = {
            Surface(
                color = White,
                modifier = Modifier.fillMaxWidth().border(BorderStroke(0.5.dp, LightGrey)),
                tonalElevation = 0.dp,
                shadowElevation = 0.dp
            ) {
                NavigationBar(containerColor = White, tonalElevation = 0.dp) {
                    NavigationBarItem(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        icon = { Icon(Icons.Default.LocalTaxi, "") },
                        label = { Text("Get Taxi") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Black,
                            selectedTextColor = Black,
                            unselectedIconColor = MidGrey,
                            unselectedTextColor = MidGrey,
                            indicatorColor = White
                        )
                    )
                    NavigationBarItem(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        icon = { Icon(Icons.Default.History, "") },
                        label = { Text("History") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Black,
                            selectedTextColor = Black,
                            unselectedIconColor = MidGrey,
                            unselectedTextColor = MidGrey,
                            indicatorColor = White
                        )
                    )
                    NavigationBarItem(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        icon = { Icon(Icons.Default.Person, "") },
                        label = { Text("Profile") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Black,
                            selectedTextColor = Black,
                            unselectedIconColor = MidGrey,
                            unselectedTextColor = MidGrey,
                            indicatorColor = White
                        )
                    )
                }
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> TaxiMapScreen(Modifier.padding(padding)) { onBack() }
            1 -> TripHistoryScreen(Modifier.padding(padding))
            2 -> ProfileScreen(Modifier.padding(padding))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("MissingPermission")
@Composable
fun TaxiMapScreen(modifier: Modifier, onExitToMain: () -> Unit) {
    val passengerId = remember { "p-${UUID.randomUUID().toString().take(8)}" }
    val socket = SocketHandler.currentSocket
    val isConnected = SocketHandler.isConnected
    var userLocation by remember { mutableStateOf<LatLng?>(null) }
    var pickupLocation by remember { mutableStateOf<LatLng?>(null) }
    var destinationLocation by remember { mutableStateOf<LatLng?>(null) }
    var isHailing by remember { mutableStateOf(false) }
    var acceptedDriver by remember { mutableStateOf<String?>(null) }
    var acceptedFare by remember { mutableIntStateOf(0) }
    var routePoints by remember { mutableStateOf<List<LatLng>>(emptyList()) }
    var tripEtaSeconds by remember { mutableIntStateOf(0) }
    var tripDistanceMeters by remember { mutableIntStateOf(0) }
    var tripEnded by remember { mutableStateOf(false) }
    val driverLocations = remember { mutableStateMapOf<String, JSONObject>() }
    var lastPassengerPingAt by remember { mutableLongStateOf(0L) }
    var searchTimedOut by remember { mutableStateOf(false) }
    var lastDriverSeenAt by remember { mutableLongStateOf(0L) }
    var showRating by remember { mutableStateOf(false) }
    var ratingDriverId by remember { mutableStateOf<String?>(null) }
    var complaintText by remember { mutableStateOf("") }
    var showThankYou by remember { mutableStateOf(false) }
    val retrySearch = {
        searchTimedOut = false
        lastDriverSeenAt = 0L
        if (socket?.connected() == true) {
            socket.emit("join", JSONObject().apply { put("role", "passengers"); put("routeId", "taxi-service"); put("passengerId", passengerId) })
        }
    }
    
    val context = LocalContext.current
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    
    DisposableEffect(Unit) {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000).build()
        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    val latLng = LatLng(location.latitude, location.longitude)
                    userLocation = latLng
                    if (pickupLocation == null) pickupLocation = latLng
                    if (isConnected && socket?.connected() == true) {
                        val now = System.currentTimeMillis()
                        if (now - lastPassengerPingAt >= 4000) {
                            lastPassengerPingAt = now
                            socket.emit("passenger-location", JSONObject().apply {
                                put("passengerId", passengerId)
                                put("routeId", "taxi-service")
                                put("coords", JSONObject().apply {
                                    put("lat", location.latitude)
                                    put("lng", location.longitude)
                                })
                                put("timestamp", now)
                            })
                        }
                    }
                }
            }
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        }
        onDispose { fusedLocationClient.removeLocationUpdates(locationCallback) }
    }

    LaunchedEffect(Unit) { SocketHandler.establishConnection() }

    DisposableEffect(socket, isConnected) {
        if (socket == null) return@DisposableEffect onDispose { }
        if (isConnected) {
            socket.emit("join", JSONObject().apply { put("role", "passengers"); put("routeId", "taxi-service"); put("passengerId", passengerId) })
            val activity = context as? android.app.Activity
            socket.on("driver-location") { args ->
                val data = parseJson(args.firstOrNull())
                val dId = data?.optString("driverId") ?: ""
                if (dId.isNotEmpty() && data != null) {
                    activity?.runOnUiThread {
                        driverLocations[dId] = data
                        lastDriverSeenAt = System.currentTimeMillis()
                        searchTimedOut = false
                    }
                }
            }
            socket.on("hail-accepted") { args ->
                val data = parseJson(args.firstOrNull())
                activity?.runOnUiThread {
                    acceptedDriver = data?.optString("driverId")
                    acceptedFare = data?.optInt("fareEstimate") ?: 0
                    isHailing = false
                    Toast.makeText(context, "Taxi Accepted! Driver on the way.", Toast.LENGTH_LONG).show()
                }
            }
            socket.on("hail-rejected") {
                activity?.runOnUiThread { isHailing = false; Toast.makeText(context, "No taxis available.", Toast.LENGTH_SHORT).show() }
            }
            socket.on("taxi-trip-ended") { args ->
                val data = parseJson(args.firstOrNull())
                activity?.runOnUiThread {
                    ratingDriverId = data?.optString("driverId")
                    tripEnded = true
                    acceptedDriver = null
                    isHailing = false
                    showRating = true
                }
            }
        }
        onDispose {
            socket.off("driver-location")
            socket.off("hail-accepted")
            socket.off("hail-rejected")
            socket.off("taxi-trip-ended")
        }
    }

    val scaffoldState = rememberBottomSheetScaffoldState()
    BottomSheetScaffold(
        modifier = modifier,
        scaffoldState = scaffoldState,
        sheetPeekHeight = 480.dp,
        sheetContent = {
            Column(
                modifier = Modifier
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 72.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ConnectionBadge()
                TaxiActions(
                    userLocation = userLocation,
                    onPickupSelected = { pickupLocation = it },
                    onDestinationSelected = { destinationLocation = it },
                    onRouteFound = { points, dist, eta ->
                        routePoints = points
                        tripDistanceMeters = dist
                        tripEtaSeconds = eta
                    },
                    isHailing = isHailing,
                    onHailingSet = { next ->
                        isHailing = next
                        if (next) {
                            tripEnded = false
                            showRating = false
                            ratingDriverId = null
                        }
                    },
                    acceptedDriver = acceptedDriver,
                    acceptedFare = acceptedFare,
                    passengerId = passengerId,
                    pickupLocation = pickupLocation,
                    destinationLocation = destinationLocation
                )
                
                if (tripEtaSeconds > 0) {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)) {
                        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Info, null, tint = MaterialTheme.colorScheme.secondary)
                            Spacer(Modifier.width(12.dp))
                            Text("Trip Summary: ${tripDistanceMeters / 1000.0} km - ~ ${tripEtaSeconds / 60} mins", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            SmartTransitMap(
                userLocation = userLocation,
                destinationLocation = destinationLocation,
                drivers = driverLocations.values.toList(),
                routePoints = routePoints
            )
            if (acceptedDriver != null) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    modifier = Modifier.padding(12.dp).align(Alignment.TopCenter)
                ) {
                    Text(
                        "Onboard Taxi: ${acceptedDriver}",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            if (showRating && tripEnded && ratingDriverId != null) {
                RatingOverlay(
                    driverId = ratingDriverId!!,
                    passengerId = passengerId,
                    complaintText = complaintText,
                    onComplaintChange = { complaintText = it },
                    onSubmit = {
                        showRating = false
                        showThankYou = true
                    },
                    onDismiss = {
                        showRating = false
                        showThankYou = true
                    }
                )
            }
            if (showThankYou) {
                ThankYouOverlay()
            }
            if (driverLocations.isEmpty() && searchTimedOut) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.2f)), contentAlignment = Alignment.Center) {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("No taxis active yet", fontWeight = FontWeight.Bold)
                            Text("Make sure drivers are online and on taxi-service.", style = MaterialTheme.typography.bodySmall)
                            Spacer(Modifier.height(8.dp))
                            Button(onClick = retrySearch) { Text("Retry") }
                        }
                    }
                }
            }
            if (!isConnected) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
        }
    }

    LaunchedEffect(isConnected) {
        searchTimedOut = false
        lastDriverSeenAt = 0L
        if (!isConnected) return@LaunchedEffect
        kotlinx.coroutines.delay(5000)
        if (driverLocations.isEmpty() && (System.currentTimeMillis() - lastDriverSeenAt) >= 5000) {
            searchTimedOut = true
        }
    }

    LaunchedEffect(showThankYou) {
        if (showThankYou) {
            kotlinx.coroutines.delay(1500)
            showThankYou = false
            ratingDriverId = null
            tripEnded = false
            onExitToMain()
        }
    }
}

@Composable
fun DestinationsBrowserScreen(mode: TransportMode, modifier: Modifier = Modifier, onRouteSelected: (RouteItem) -> Unit) {
    var searchQuery by remember { mutableStateOf("") }
    var allRoutes by remember { mutableStateOf<List<RouteItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    val serverUrl = SocketHandler.getCurrentUrl()

    LaunchedEffect(Unit) {
        // Show fallback routes immediately so the UI responds fast (<5s),
        // then refresh from the server when available.
        allRoutes = if (mode == TransportMode.BUS) FALLBACK_BUS_ROUTES else FALLBACK_COMBI_ROUTES
        isLoading = false

        withContext(Dispatchers.IO) {
            try {
                val url = URL("${serverUrl}/api/routes")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.setRequestProperty("bypass-tunnel-reminder", "true")
                conn.connectTimeout = 1500
                conn.readTimeout = 1500
                val body = conn.inputStream.bufferedReader().readText()
                val arr = JSONArray(body)
                val list = (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    val routeType = obj.optString("route_type", "BUS").uppercase()
                    RouteItem(
                        obj.optString("route_id"),
                        obj.optString("route_name"),
                        obj.optString("start"),
                        obj.optString("end"),
                        routeType
                    )
                }
                withContext(Dispatchers.Main) { 
                    allRoutes = list
                    isLoading = false 
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    allRoutes = if (mode == TransportMode.BUS) FALLBACK_BUS_ROUTES else FALLBACK_COMBI_ROUTES
                    isLoading = false
                }
            }
        }
    }

    // Filter by mode type, then by search query
    val modeType = if (mode == TransportMode.BUS) "BUS" else "COMBI"
    val filteredRoutes = allRoutes
        .filter { it.type == modeType || it.type.isEmpty() }
        .filter { searchQuery.isBlank() || it.name.contains(searchQuery, ignoreCase = true) || it.end.contains(searchQuery, ignoreCase = true) || it.start.contains(searchQuery, ignoreCase = true) }

    val modeLabel = if (mode == TransportMode.BUS) "Bus" else "Combi"

    Column(modifier = modifier.fillMaxSize().padding(16.dp)) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { searchQuery = it },
            label = { Text("Search destination or route") },
            modifier = Modifier.fillMaxWidth(),
            leadingIcon = { Icon(Icons.Default.Search, null) },
            shape = MaterialTheme.shapes.medium,
            singleLine = true
        )
        Spacer(Modifier.height(16.dp))
        Text(
            if (searchQuery.isBlank()) "Available $modeLabel Routes" else "Matching Results",
            style = MaterialTheme.typography.labelMedium, color = Color.Gray
        )
        Spacer(Modifier.height(8.dp))
        if (isLoading) {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        } else if (filteredRoutes.isEmpty()) {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text("No $modeLabel routes found", color = Color.Gray)
            }
        } else {
            LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(filteredRoutes) { route ->
                    RouteCard(route) { onRouteSelected(route) }
                }
            }
        }
    }
}

@Composable
fun TaxiActions(
    userLocation: LatLng?,
    onPickupSelected: (LatLng) -> Unit,
    onDestinationSelected: (LatLng) -> Unit,
    onRouteFound: (List<LatLng>, Int, Int) -> Unit,
    isHailing: Boolean,
    onHailingSet: (Boolean) -> Unit,
    acceptedDriver: String?,
    acceptedFare: Int,
    passengerId: String,
    pickupLocation: LatLng?,
    destinationLocation: LatLng?
) {
    var pickupText by remember { mutableStateOf("Current Location") }
    var destText by remember { mutableStateOf("") }
    var suggestions by remember { mutableStateOf<List<PlaceSuggestion>>(emptyList()) }
    var suggestionType by remember { mutableStateOf("DEST") } 
    val scope = rememberCoroutineScope()
    var serviceType by remember { mutableStateOf("STANDARD") }

    fun search(query: String, type: String) {
        if (query.length < 3) return
        suggestionType = type
        scope.launch(Dispatchers.IO) {
            try {
                val url = URL("https://nominatim.openstreetmap.org/search?format=json&q=${query.replace(" ", "+")}")
                val res = url.readText()
                val arr = JSONArray(res)
                val list = (0 until Math.min(arr.length(), 5)).map { i ->
                    val obj = arr.getJSONObject(i)
                    PlaceSuggestion(obj.getString("display_name"), LatLng(obj.getDouble("lat"), obj.getDouble("lon")))
                }
                withContext(Dispatchers.Main) { suggestions = list }
            } catch (e: Exception) { }
        }
    }

    LaunchedEffect(pickupLocation, destinationLocation) {
        if (pickupLocation != null && destinationLocation != null) {
            scope.launch(Dispatchers.IO) {
                try {
                    val url = URL("https://router.project-osrm.org/route/v1/driving/${pickupLocation.longitude},${pickupLocation.latitude};${destinationLocation.longitude},${destinationLocation.latitude}?overview=full&geometries=geojson")
                    val res = url.readText()
                    val obj = JSONObject(res)
                    val routesJson = obj.getJSONArray("routes")
                    if (routesJson.length() > 0) {
                        val route = routesJson.getJSONObject(0)
                        val dist = route.getInt("distance")
                        val dur = route.getInt("duration")
                        val geom = route.getJSONObject("geometry").getJSONArray("coordinates")
                        val points = (0 until geom.length()).map { i ->
                            val p = geom.getJSONArray(i)
                            LatLng(p.getDouble(1), p.getDouble(0))
                        }
                        withContext(Dispatchers.Main) { onRouteFound(points, dist, dur) }
                    }
                } catch (e: Exception) { }
            }
        }
    }

    if (acceptedDriver != null) {
        LeftBorderInfoCard(
            accent = AccentGreen,
            title = "Driver on the way",
            body = acceptedDriver,
            supporting = if (acceptedFare > 0) "Estimated fare P$acceptedFare" else null
        )
    } else if (isHailing) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            CircularProgressIndicator(color = Black, strokeWidth = 2.dp)
            Spacer(Modifier.height(8.dp))
            Text("Finding your ride...", style = MaterialTheme.typography.titleMedium, color = Black)
            TextButton(onClick = { 
                SocketHandler.currentSocket?.emit("cancel-hail", JSONObject().apply { put("passengerId", passengerId); put("routeId", "taxi-service") })
                onHailingSet(false) 
            }) { Text("Cancel Hail", color = AccentRed) }
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = pickupText, onValueChange = { pickupText = it; search(it, "PICKUP") },
                label = { Text("Pickup Location") }, modifier = Modifier.fillMaxWidth(),
                leadingIcon = { Icon(Icons.Default.MyLocation, null, tint = Black) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = PassengerFieldColors()
            )
            OutlinedTextField(
                value = destText, onValueChange = { destText = it; search(it, "DEST") },
                label = { Text("Where to?") }, modifier = Modifier.fillMaxWidth(),
                leadingIcon = { Icon(Icons.Default.LocationOn, null, tint = Black) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = PassengerFieldColors()
            )

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                FilterChip(
                    selected = serviceType == "STANDARD",
                    onClick = { serviceType = "STANDARD" },
                    label = { Text("Standard") },
                    border = BorderStroke(1.dp, if (serviceType == "STANDARD") Black else LightGrey),
                    colors = FilterChipDefaults.filterChipColors(
                        containerColor = White,
                        selectedContainerColor = White,
                        labelColor = MidGrey,
                        selectedLabelColor = Black
                    )
                )
                FilterChip(
                    selected = serviceType == "SPECIAL",
                    onClick = { serviceType = "SPECIAL" },
                    label = { Text("Special") },
                    border = BorderStroke(1.dp, if (serviceType == "SPECIAL") Black else LightGrey),
                    colors = FilterChipDefaults.filterChipColors(
                        containerColor = White,
                        selectedContainerColor = White,
                        labelColor = MidGrey,
                        selectedLabelColor = Black
                    )
                )
            }
            
            if (suggestions.isNotEmpty()) {
                Card(modifier = Modifier.fillMaxWidth().heightIn(max = 150.dp), elevation = CardDefaults.cardElevation(2.dp)) {
                    LazyColumn {
                        items(suggestions) { s ->
                            ListItem(
                                headlineContent = { Text(s.name, maxLines = 1, style = MaterialTheme.typography.bodySmall) }, 
                                modifier = Modifier.clickable {
                                    if (suggestionType == "PICKUP") {
                                        pickupText = s.name; onPickupSelected(s.location)
                                    } else {
                                        destText = s.name; onDestinationSelected(s.location)
                                    }
                                    suggestions = emptyList()
                                }
                            )
                            HorizontalDivider()
                        }
                    }
                }
            }

            Button(
                onClick = {
                    if (pickupLocation != null) {
                        onHailingSet(true)
                        SocketHandler.currentSocket?.emit("hail", JSONObject().apply {
                            put("passengerId", passengerId)
                            put("routeId", "taxi-service")
                            put("pickupLoc", JSONObject().apply { put("lat", pickupLocation.latitude); put("lng", pickupLocation.longitude) })
                            destinationLocation?.let { d ->
                                put("destinationLoc", JSONObject().apply { put("lat", d.latitude); put("lng", d.longitude) })
                            }
                            put("serviceType", serviceType)
                        })
                    }
                },
                modifier = Modifier.fillMaxWidth().height(54.dp),
                enabled = pickupLocation != null,
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Black,
                    contentColor = White,
                    disabledContainerColor = Disabled,
                    disabledContentColor = White
                ),
                elevation = null
            ) { Text("Request Taxi Now", style = MaterialTheme.typography.titleMedium) }
        }
    }
}

@Composable
fun ModeSelectionScreen(modifier: Modifier, onModeSelected: (TransportMode) -> Unit) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(White)
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            "Choose your mode",
            style = MaterialTheme.typography.headlineLarge,
            color = Black
        )
        Text(
            "Clean, direct booking across bus, combi, and taxi.",
            style = MaterialTheme.typography.bodyMedium,
            color = MidGrey
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PremiumModeCard(
                title = "Bus",
                subtitle = "Scheduled long-distance trips",
                icon = Icons.Default.DirectionsBus,
                fare = "P8"
            ) { onModeSelected(TransportMode.BUS) }
            PremiumModeCard(
                title = "Combi",
                subtitle = "Flexible urban routes",
                icon = Icons.Default.AirportShuttle,
                fare = "P8"
            ) { onModeSelected(TransportMode.COMBI) }
            PremiumModeCard(
                title = "Taxi",
                subtitle = "Private on-demand rides",
                icon = Icons.Default.LocalTaxi,
                fare = "From P10"
            ) { onModeSelected(TransportMode.TAXI) }
        }
    }
}

@Composable
private fun PremiumModeCard(
    title: String, subtitle: String, icon: ImageVector,
    fare: String, onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(containerColor = White),
        border = BorderStroke(1.dp, LightGrey)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, null, tint = Black, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), color = Black)
                Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MidGrey)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(fare, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold), color = Black)
                Icon(Icons.Default.ChevronRight, null, tint = MidGrey, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
fun RouteCard(route: RouteItem, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(containerColor = White),
        border = BorderStroke(1.dp, LightGrey)
    ) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.LocationOn, null, tint = Black, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(route.name, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), color = Black)
                Text("${route.start} -> ${route.end}", style = MaterialTheme.typography.bodyMedium, color = MidGrey)
            }
            Icon(Icons.Default.ChevronRight, null, tint = MidGrey, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun BusCombiActions(m: TransportMode, boarded: Boolean, rid: String, pid: String, loc: LatLng?, hailing: Boolean, hailAccepted: Boolean, onH: (Boolean) -> Unit, onB: () -> Unit) {
    if (!boarded) {
        Button(
            onClick = {
                if (loc != null) {
                    val ev = if (hailing) "cancel-hail" else "hail"
                    SocketHandler.currentSocket?.emit(ev, JSONObject().apply { 
                        put("passengerId", pid)
                        put("routeId", rid)
                        if (!hailing) put("pickupLoc", JSONObject().apply { put("lat", loc.latitude); put("lng", loc.longitude) })
                    })
                    onH(!hailing)
                }
            }, 
            modifier = Modifier.fillMaxWidth().height(54.dp), 
            colors = ButtonDefaults.buttonColors(
                containerColor = if (hailing) AccentRed else Black,
                contentColor = White
            ),
            shape = RoundedCornerShape(14.dp),
            elevation = null
        ) {
            if (hailing) {
                CircularProgressIndicator(color = White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                Spacer(Modifier.width(8.dp))
                Text("Cancel Hail", style = MaterialTheme.typography.titleMedium, color = White)
            } else {
                Icon(Icons.Default.WavingHand, null, modifier = Modifier.size(20.dp), tint = White)
                Spacer(Modifier.width(8.dp))
                Text("Hail ${m.name}", style = MaterialTheme.typography.titleMedium, color = White)
            }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = onB,
            enabled = hailing || hailAccepted,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(14.dp),
            border = BorderStroke(1.dp, if (hailing || hailAccepted) Black else LightGrey),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = White,
                contentColor = if (hailing || hailAccepted) Black else Disabled,
                disabledContainerColor = White,
                disabledContentColor = Disabled
            )
        ) {
            Text("Onboard", style = MaterialTheme.typography.titleMedium)
        }
    } else {
        Button(
            onClick = { SocketHandler.currentSocket?.emit("stop-request", JSONObject().apply { put("passengerId", pid); put("routeId", rid) }) },
            modifier = Modifier.fillMaxWidth().height(54.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AccentRed, contentColor = White),
            shape = RoundedCornerShape(14.dp),
            elevation = null
        ) {
            Icon(Icons.Default.Stop, null, modifier = Modifier.size(20.dp), tint = White)
            Spacer(Modifier.width(8.dp))
            Text("Request Stop", style = MaterialTheme.typography.titleMedium, color = White)
        }
        Spacer(Modifier.height(4.dp))
        TextButton(onClick = onB, modifier = Modifier.fillMaxWidth()) {
            Text("Exit Vehicle", color = MidGrey)
        }
    }
}

// ============= STAR RATING OVERLAY =============
@Composable
fun RatingOverlay(
    driverId: String, passengerId: String,
    complaintText: String, onComplaintChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit
) {
    var selectedRating by remember { mutableIntStateOf(0) }
    var hoveredRating by remember { mutableIntStateOf(0) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)),
            contentAlignment = Alignment.Center
        ) {
            Card(
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier
                    .padding(24.dp)
                    .fillMaxWidth()
                    .heightIn(max = 520.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Column(
                    modifier = Modifier
                        .padding(24.dp)
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier.size(64.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.Person, null, modifier = Modifier.size(36.dp), tint = MaterialTheme.colorScheme.primary)
                    }

                    Text("How was your ride?", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    Text("Driver: $driverId", fontSize = 13.sp, color = Color.Gray)

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(vertical = 8.dp)
                    ) {
                        (1..5).forEach { score ->
                            val active = score <= (if (hoveredRating > 0) hoveredRating else selectedRating)
                            IconButton(
                                onClick = { selectedRating = score },
                                modifier = Modifier.size(44.dp)
                            ) {
                                Icon(
                                    if (active) Icons.Default.Star else Icons.Default.StarOutline,
                                    contentDescription = "$score stars",
                                    tint = if (active) Color(0xFFFBBF24) else Color.Gray,
                                    modifier = Modifier.size(36.dp)
                                )
                            }
                        }
                    }

                    val label = when (selectedRating) {
                        1 -> "Poor"; 2 -> "Fair"; 3 -> "Good"; 4 -> "Great"; 5 -> "Excellent!"; else -> ""
                    }
                    if (label.isNotEmpty()) {
                        Text(label, fontWeight = FontWeight.Medium, color = Color(0xFFFBBF24), fontSize = 14.sp)
                    }

                    OutlinedTextField(
                        value = complaintText,
                        onValueChange = onComplaintChange,
                        label = { Text("Feedback (optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        minLines = 2, maxLines = 3
                    )

                    Button(
                        onClick = {
                            if (selectedRating > 0) {
                                SocketHandler.currentSocket?.emit(
                                    "driver-rating",
                                    JSONObject().apply { put("driverId", driverId); put("rating", selectedRating) }
                                )
                            }
                            if (complaintText.isNotBlank()) {
                                SocketHandler.currentSocket?.emit(
                                    "driver-complaint",
                                    JSONObject().apply {
                                        put("driverId", driverId)
                                        put("passengerId", passengerId)
                                        put("message", complaintText.trim())
                                    }
                                )
                                onComplaintChange("")
                            }
                            onSubmit()
                        },
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(14.dp),
                        enabled = selectedRating > 0
                    ) {
                        Text("Submit Rating", fontWeight = FontWeight.SemiBold)
                    }

                    TextButton(onClick = onDismiss) {
                        Text("Skip", color = Color.Gray)
                    }
                }
            }
        }
    }
}

@Composable
fun ThankYouOverlay() {
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)),
        contentAlignment = Alignment.Center
    ) {
        Card(
            shape = RoundedCornerShape(22.dp),
            modifier = Modifier.padding(32.dp).fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.CheckCircle, null, tint = AccentGreen, modifier = Modifier.size(48.dp))
                Text("Thank you!", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("We appreciate your feedback.", fontSize = 13.sp, color = Color.Gray)
            }
        }
    }
}

// ============= TRIP HISTORY SCREEN =============
@Composable
fun TripHistoryScreen(modifier: Modifier = Modifier) {
    val mockTrips = remember {
        listOf(
            Triple("Bus Rank ? Francistown", "Today 14:30", "P8.00"),
            Triple("BAC ? Main Mall", "Today 08:15", "P8.00"),
            Triple("Taxi to Riverwalk", "Yesterday 18:45", "P15.00"),
            Triple("UB ? Bus Rank", "Yesterday 07:20", "P8.00"),
            Triple("Taxi to Airport", "Mar 17 06:00", "P45.00")
        )
    }

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Trip History", fontWeight = FontWeight.Bold, fontSize = 22.sp)
        Text("Your recent rides", fontSize = 13.sp, color = Color.Gray)
        Spacer(Modifier.height(4.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(mockTrips) { (route, time, fare) ->
                Card(
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier.size(44.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (route.startsWith("Taxi")) Color(0xFFFEF3C7)
                                    else MaterialTheme.colorScheme.primaryContainer
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                if (route.startsWith("Taxi")) Icons.Default.LocalTaxi else Icons.Default.DirectionsBus,
                                null,
                                tint = if (route.startsWith("Taxi")) Color(0xFFD97706) else MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(route, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                            Text(time, fontSize = 12.sp, color = Color.Gray)
                        }
                        Text(fare, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun ProfileScreen(modifier: Modifier) {
    var url by remember { mutableStateOf(SocketHandler.getCurrentUrl()) }
    val context = LocalContext.current

    Column(
        modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Profile header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(60.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(listOf(Color(0xFF3B82F6), Color(0xFF06B6D4)))
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Person, null, tint = Color.White, modifier = Modifier.size(32.dp))
            }
            Spacer(Modifier.width(16.dp))
            Column {
                Text("Passenger", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text(
                    if (SocketHandler.isConnected) "? Connected" else "? Offline",
                    fontSize = 13.sp,
                    color = if (SocketHandler.isConnected) Color(0xFF10B981) else Color.Gray
                )
            }
        }

        HorizontalDivider(color = Color.Gray.copy(alpha = 0.2f))

        Text("Server Connection", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)

        OutlinedTextField(
            value = url,
            onValueChange = { url = it },
            label = { Text("Server URL") },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("e.g. http://10.0.2.2:3000") },
            shape = RoundedCornerShape(14.dp),
            singleLine = true
        )

        Button(
            onClick = {
                SocketHandler.init(context, url.trim())
                Toast.makeText(context, "Reconnecting...", Toast.LENGTH_SHORT).show()
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.Refresh, null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text("Save & Reconnect", fontWeight = FontWeight.SemiBold)
        }

        Card(
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
            )
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Connection Tips", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                Text("• Emulator ? http://10.0.2.2:3000", fontSize = 12.sp, color = Color.Gray)
                Text("• Real device ? Use PC's IP address", fontSize = 12.sp, color = Color.Gray)
                Text("• Remote ? Use localtunnel URL", fontSize = 12.sp, color = Color.Gray)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PassengerTopBar(title: String, onBack: (() -> Unit)? = null) {
    Surface(
        color = White,
        modifier = Modifier
            .fillMaxWidth()
            .border(BorderStroke(0.5.dp, LightGrey)),
        shadowElevation = 0.dp,
        tonalElevation = 0.dp
    ) {
        CenterAlignedTopAppBar(
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = White,
                titleContentColor = Black
            ),
            navigationIcon = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (onBack != null) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Black)
                        }
                    }
                    SmartTransitLogoMark(40.dp)
                }
            },
            title = {
                Text(
                    title,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = Black
                )
            },
            actions = {
                ConnectionBadge(modifier = Modifier.padding(end = 16.dp))
            }
        )
    }
}

@Composable
private fun SmartTransitLogoMark(size: androidx.compose.ui.unit.Dp) {
    Box(modifier = Modifier.size(size), contentAlignment = Alignment.Center) {
        Text(
            text = "ST",
            style = MaterialTheme.typography.titleLarge.copy(
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.8).sp
            ),
            color = Black
        )
    }
}

@Composable
private fun PassengerFieldColors() = OutlinedTextFieldDefaults.colors(
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

@Composable
private fun LeftBorderInfoCard(
    accent: Color,
    title: String,
    body: String,
    supporting: String? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(BorderStroke(1.dp, LightGrey), RoundedCornerShape(16.dp))
            .background(White, RoundedCornerShape(16.dp))
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(78.dp)
                .background(accent, RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(title, style = MaterialTheme.typography.bodyMedium, color = Black)
            Text(
                body,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = Black
            )
            supporting?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MidGrey) }
        }
    }
}

data class RouteItem(val routeId: String, val name: String, val start: String, val end: String, val type: String = "BUS")
data class PlaceSuggestion(val name: String, val location: LatLng)

val FALLBACK_BUS_ROUTES = listOf(
    RouteItem("bus-francistown", "Gaborone ? Francistown", "Gaborone Bus Rank", "Francistown", "BUS"),
    RouteItem("bus-lobatse", "Gaborone ? Lobatse", "Gaborone Bus Rank", "Lobatse", "BUS"),
    RouteItem("bus-molepolole", "Gaborone ? Molepolole", "Gaborone Bus Rank", "Molepolole", "BUS"),
    RouteItem("bus-mahalapye", "Gaborone ? Mahalapye", "Gaborone Bus Rank", "Mahalapye", "BUS"),
    RouteItem("bus-palapye", "Gaborone ? Palapye", "Gaborone Bus Rank", "Palapye", "BUS"),
    RouteItem("bus-kanye", "Gaborone ? Kanye", "Gaborone Bus Rank", "Kanye", "BUS"),
    RouteItem("bus-maun", "Gaborone ? Maun", "Gaborone Bus Rank", "Maun", "BUS"),
    RouteItem("bus-kopong", "Gaborone ? Kopong", "Gaborone Bus Rank", "Kopong", "BUS")
)

val FALLBACK_COMBI_ROUTES = listOf(
    RouteItem("route-u01", "Route U1 – BAC to Bus Rank", "BAC", "Bus Rank", "COMBI"),
    RouteItem("route-u02", "Route U2 – UB to Main Mall", "UB", "Main Mall", "COMBI"),
    RouteItem("route-u03", "Route U3 – Botho to Bus Rank", "Botho University", "Bus Rank", "COMBI"),
    RouteItem("route-u04", "Route U4 – Gamecity to Bus Rank", "Gamecity", "Bus Rank", "COMBI"),
    RouteItem("route-u05", "Route U5 – Mogoditshane to Main Mall", "Mogoditshane", "Main Mall", "COMBI"),
    RouteItem("route-u06", "Route U6 – Gaborone West to Gamecity", "Gaborone West", "Gamecity", "COMBI")
)

val FALLBACK_ROUTES = FALLBACK_BUS_ROUTES + FALLBACK_COMBI_ROUTES
