package com.example.smarttransit.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.smarttransit.ui.theme.MidGrey
import com.google.android.gms.maps.model.LatLng
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.XYTileSource
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

private val PositronTileSource = XYTileSource(
    "Positron",
    0,
    19,
    256,
    ".png",
    arrayOf(
        "https://a.basemaps.cartocdn.com/light_all/",
        "https://b.basemaps.cartocdn.com/light_all/",
        "https://c.basemaps.cartocdn.com/light_all/"
    ),
    "(c) CARTO (c) OpenStreetMap contributors"
)

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

    val userMarker = remember(context) { createUserMarkerDrawable(context) }
    val driverMarker = remember(context) { createDriverMarkerDrawable(context) }
    val passengerMarker = remember(context) { createPassengerMarkerDrawable(context) }
    val stopMarker = remember(context) { createStopMarkerDrawable(context) }
    val destinationMarker = remember(context) { createDestinationMarkerDrawable(context) }
    val defaultCenter = remember { LatLng(-24.6282, 25.9231) }
    val currentUserLocation = toLatLng(userLocation)

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                MapView(ctx).apply {
                    setTileSource(PositronTileSource)
                    setMultiTouchControls(true)
                    zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
                    controller.setZoom(15.0)
                    val start = currentUserLocation ?: defaultCenter
                    controller.setCenter(GeoPoint(start.latitude, start.longitude))
                }
            },
            update = { mapView ->
                val center = currentUserLocation ?: defaultCenter
                mapView.controller.setCenter(GeoPoint(center.latitude, center.longitude))
                mapView.overlays.clear()

                if (routePoints.isNotEmpty()) {
                    val line = Polyline().apply {
                        outlinePaint.color = android.graphics.Color.parseColor("#0A0A0A")
                        outlinePaint.strokeWidth = 5f
                        outlinePaint.strokeCap = Paint.Cap.ROUND
                        outlinePaint.strokeJoin = Paint.Join.ROUND
                        setPoints(routePoints.map { GeoPoint(it.latitude, it.longitude) })
                    }
                    mapView.overlays.add(line)
                }

                toLatLng(userLocation)?.let { loc ->
                    mapView.overlays.add(
                        Marker(mapView).apply {
                            position = GeoPoint(loc.latitude, loc.longitude)
                            icon = userMarker
                            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                        }
                    )
                }

                destinationLocation?.let { dest ->
                    mapView.overlays.add(
                        Marker(mapView).apply {
                            position = GeoPoint(dest.latitude, dest.longitude)
                            icon = destinationMarker
                            setTitle("Destination")
                            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                        }
                    )
                }

                drivers.forEach { item ->
                    toLatLng(item)?.let { loc ->
                        val json = item as? JSONObject
                        val title = buildString {
                            append("Driver")
                            json?.optString("driverId")?.takeIf { it.isNotBlank() }?.let { append(" ").append(it) }
                        }
                        val snippet = json?.optString("routeId").orEmpty()
                        mapView.overlays.add(
                            Marker(mapView).apply {
                                position = GeoPoint(loc.latitude, loc.longitude)
                                icon = driverMarker
                                if (title.isNotBlank()) setTitle(title)
                                if (snippet.isNotBlank()) setSnippet("Route: $snippet")
                                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                            }
                        )
                    }
                }

                passengers.forEach { item ->
                    toLatLng(item)?.let { loc ->
                        mapView.overlays.add(
                            Marker(mapView).apply {
                                position = GeoPoint(loc.latitude, loc.longitude)
                                icon = passengerMarker
                                setTitle("Passenger")
                                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                            }
                        )
                    }
                }

                stops.forEach { item ->
                    val loc = when (item) {
                        is JSONObject -> {
                            val lat = item.optDouble("latitude", Double.NaN)
                            val lng = item.optDouble("longitude", Double.NaN)
                            if (lat.isNaN() || lng.isNaN()) null else LatLng(lat, lng)
                        }
                        is LatLng -> item
                        else -> null
                    }
                    if (loc != null) {
                        val name = (item as? JSONObject)?.optString("name").orEmpty()
                        mapView.overlays.add(
                            Marker(mapView).apply {
                                position = GeoPoint(loc.latitude, loc.longitude)
                                icon = stopMarker
                                if (name.isNotBlank()) {
                                    setTitle(name)
                                }
                                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                            }
                        )
                    }
                }

                mapView.invalidate()
            }
        )

        Text(
            text = PositronTileSource.copyrightNotice,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 12.dp, bottom = 8.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MidGrey
        )
    }
}

private fun toLatLng(loc: Any?): LatLng? = when (loc) {
    is LatLng -> loc
    is JSONObject -> {
        val coords = loc.optJSONObject("coords")
        when {
            coords != null -> LatLng(coords.optDouble("lat"), coords.optDouble("lng"))
            loc.has("lat") && loc.has("lng") -> LatLng(loc.optDouble("lat"), loc.optDouble("lng"))
            else -> null
        }
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
            else -> {
                val lat = (loc["lat"] as? Number)?.toDouble()
                val lng = (loc["lng"] as? Number)?.toDouble()
                if (lat != null && lng != null) LatLng(lat, lng) else null
            }
        }
    }
    else -> null
}

private fun createUserMarkerDrawable(context: Context): Drawable {
    val size = dpToPx(context, 20f).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.FILL
    }
    val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    val radius = size / 2f
    canvas.drawCircle(radius, radius, radius, fillPaint)
    canvas.drawCircle(radius, radius, dpToPx(context, 3f), centerPaint)
    return BitmapDrawable(context.resources, bitmap)
}

private fun createPassengerMarkerDrawable(context: Context): Drawable {
    val size = dpToPx(context, 20f).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(context, 2f)
    }
    val radius = (size / 2f) - strokePaint.strokeWidth
    canvas.drawCircle(size / 2f, size / 2f, radius, fillPaint)
    canvas.drawCircle(size / 2f, size / 2f, radius, strokePaint)
    return BitmapDrawable(context.resources, bitmap)
}

private fun createStopMarkerDrawable(context: Context): Drawable {
    val size = dpToPx(context, 12f).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.FILL
    }
    canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
    return BitmapDrawable(context.resources, bitmap)
}

private fun createDestinationMarkerDrawable(context: Context): Drawable {
    val width = dpToPx(context, 20f).toInt()
    val height = dpToPx(context, 28f).toInt()
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.FILL
    }
    val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    val path = Path().apply {
        moveTo(width / 2f, height.toFloat())
        cubicTo(width.toFloat(), height * 0.68f, width.toFloat(), height * 0.28f, width / 2f, 0f)
        cubicTo(0f, height * 0.28f, 0f, height * 0.68f, width / 2f, height.toFloat())
        close()
    }
    canvas.drawPath(path, fillPaint)
    canvas.drawCircle(width / 2f, height * 0.34f, dpToPx(context, 4f), innerPaint)
    return BitmapDrawable(context.resources, bitmap)
}

private fun createDriverMarkerDrawable(context: Context): Drawable {
    val size = dpToPx(context, 24f).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.FILL
    }
    val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    val wheelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.parseColor("#0A0A0A")
        style = Paint.Style.FILL
    }

    val corner = dpToPx(context, 6f)
    canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), corner, corner, backgroundPaint)

    val padding = dpToPx(context, 5f)
    val bodyTop = padding + dpToPx(context, 4f)
    val bodyBottom = size - padding - dpToPx(context, 3f)
    val bodyLeft = padding
    val bodyRight = size - padding

    canvas.drawRoundRect(
        RectF(bodyLeft, bodyTop, bodyRight, bodyBottom),
        dpToPx(context, 3f),
        dpToPx(context, 3f),
        iconPaint
    )
    canvas.drawRoundRect(
        RectF(
            bodyLeft + dpToPx(context, 3f),
            padding + dpToPx(context, 1f),
            bodyRight - dpToPx(context, 3f),
            bodyTop + dpToPx(context, 2f)
        ),
        dpToPx(context, 3f),
        dpToPx(context, 3f),
        iconPaint
    )
    canvas.drawCircle(bodyLeft + dpToPx(context, 3.5f), bodyBottom, dpToPx(context, 2f), wheelPaint)
    canvas.drawCircle(bodyRight - dpToPx(context, 3.5f), bodyBottom, dpToPx(context, 2f), wheelPaint)

    return BitmapDrawable(context.resources, bitmap)
}

private fun dpToPx(context: Context, dp: Float): Float {
    return dp * context.resources.displayMetrics.density
}
