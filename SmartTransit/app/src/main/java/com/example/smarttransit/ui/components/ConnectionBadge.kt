package com.example.smarttransit.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.smarttransit.network.SocketHandler

@Composable
fun ConnectionBadge(modifier: Modifier = Modifier) {
    val connected = SocketHandler.isConnected
    val bg by animateColorAsState(
        targetValue = if (connected) Color(0xFF064E3B).copy(alpha = 0.9f) else Color(0xFF7F1D1D).copy(alpha = 0.9f),
        animationSpec = tween(400), label = "bg"
    )
    val dotColor by animateColorAsState(
        targetValue = if (connected) Color(0xFF34D399) else Color(0xFFF87171),
        animationSpec = tween(400), label = "dot"
    )
    val fg by animateColorAsState(
        targetValue = if (connected) Color(0xFF6EE7B7) else Color(0xFFFCA5A5),
        animationSpec = tween(400), label = "fg"
    )
    val label = if (connected) "Connected" else "Offline"

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .clip(CircleShape)
                .background(dotColor)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            label,
            color = fg,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.5.sp
        )
    }
}
