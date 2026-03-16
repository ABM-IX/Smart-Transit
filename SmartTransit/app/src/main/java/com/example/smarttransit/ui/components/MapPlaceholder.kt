package com.example.smarttransit.ui.components

import android.content.Context
import android.graphics.Color
import android.util.Log
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import com.google.android.gms.maps.model.LatLng

@Composable
fun SmartTransitMap(
    modifier: Modifier = Modifier,
    userLocation: Any? = null,
    destinationLocation: LatLng? = null,
    drivers: List<Any> = emptyList(),
    passengers: List<Any> = emptyList(),
    stops: List<Any> = emptyList(),
    routePoints: List<LatLng> = emptyList()
) {
    val context = LocalContext.current

    // Configure osmdroid once
    LaunchedEffect(Unit) {
        try {
            Configuration.getInstance().load(
                context,
                context.getSharedPreferences("osmdroid", Context.MODE_PRIVATE)
            )
            Configuration.getInstance().userAgentValue = context.packageName
        } catch (e: Exception) {
            Log.e("SmartTransitMap", "OSMDroid config failed", e)
        }
    }

    fun toLatLng(loc: Any?): LatLng? = when (loc) {
        is LatLng -> loc
        is JSONObject -> {
            val coords = loc.optJSONObject("coords") ?: (loc.opt("coords") as? Map<*, *>)?.let { m ->
                val obj = JSONObject()
                m.forEach { (k, v) -> if (k != null) obj.put(k.toString(), v) }
                obj
            }
            coords?.let { LatLng(it.optDouble("lat"), it.optDouble("lng")) }
        }
        is Map<*, *> -> {
            val coords = loc["coords"]
            when (coords) {
                is Map<*, *> -> {
                    val lat = (coords["lat"] as? Number)?.toDouble()
                    val lng = (coords["lng"] as? Number)?.toDouble()
                    if (lat != null && lng != null) LatLng(lat, lng) else null
                }
                is JSONObject -> LatLng(coords.optDouble("lat"), coords.optDouble("lng"))
                else -> null
            }
        }
        else -> null
    }

    val userLatLng = toLatLng(userLocation)
    val defaultCenter = LatLng(-24.6282, 25.9231) // Gaborone

    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            MapView(ctx).apply {
                setTileSource(TileSourceFactory.MAPNIK)
                setMultiTouchControls(true)
                controller.setZoom(15.0)
                val start = userLatLng ?: defaultCenter
                controller.setCenter(GeoPoint(start.latitude, start.longitude))
            }
        },
        update = { mapView ->
            // Center camera on user when location changes
            val center = userLatLng ?: defaultCenter
            mapView.controller.setCenter(GeoPoint(center.latitude, center.longitude))

            // Clear and redraw overlays
            mapView.overlays.clear()

            // Route polyline
            if (routePoints.isNotEmpty()) {
                val line = Polyline().apply {
                    outlinePaint.color = Color.parseColor("#4285F4")
                    outlinePaint.strokeWidth = 8f
                    setPoints(routePoints.map { GeoPoint(it.latitude, it.longitude) })
                }
                mapView.overlays.add(line)
            }

            // User marker
            toLatLng(userLocation)?.let { loc ->
                val marker = Marker(mapView).apply {
                    position = GeoPoint(loc.latitude, loc.longitude)
                    setTitle("You")
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                }
                mapView.overlays.add(marker)
            }

            // Destination marker
            destinationLocation?.let { dest ->
                val m = Marker(mapView).apply {
                    position = GeoPoint(dest.latitude, dest.longitude)
                    setTitle("Destination")
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                }
                mapView.overlays.add(m)
            }

            // Driver markers
            drivers.forEach { item ->
                toLatLng(item)?.let { loc ->
                    val json = item as? JSONObject
                    val driverId = json?.optString("driverId").orEmpty()
                    val driverType = json?.optString("driverType").orEmpty()
                    val routeId = json?.optString("routeId").orEmpty()
                    val title = buildString {
                        append("Driver")
                        if (driverType.isNotBlank()) append(" • ").append(driverType)
                        if (driverId.isNotBlank()) append(" • ").append(driverId)
                    }
                    val sub = buildString {
                        if (routeId.isNotBlank()) append("Route: ").append(routeId)
                    }
                    val m = Marker(mapView).apply {
                        position = GeoPoint(loc.latitude, loc.longitude)
                        setTitle(title)
                        if (sub.isNotBlank()) setSnippet(sub)
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(m)
                }
            }

            // Passenger markers
            passengers.forEach { item ->
                toLatLng(item)?.let { loc ->
                    val m = Marker(mapView).apply {
                        position = GeoPoint(loc.latitude, loc.longitude)
                        setTitle("Passenger")
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(m)
                }
            }

            // Stop markers
            stops.forEach { item ->
                val loc = when (item) {
                    is JSONObject -> LatLng(item.optDouble("latitude"), item.optDouble("longitude"))
                    is LatLng -> item
                    else -> null
                }
                if (loc != null) {
                    val name = (item as? JSONObject)?.optString("name").orEmpty()
                    val m = Marker(mapView).apply {
                        position = GeoPoint(loc.latitude, loc.longitude)
                        setTitle(if (name.isNotBlank()) "Stop: $name" else "Stop")
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(m)
                }
            }

            mapView.invalidate()
        }
    )
}
