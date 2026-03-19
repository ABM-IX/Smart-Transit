package com.example.smarttransit.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
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
import com.example.smarttransit.ui.theme.AccentGreen
import com.example.smarttransit.ui.theme.AccentRed
import com.example.smarttransit.ui.theme.White

@Composable
fun ConnectionBadge(modifier: Modifier = Modifier) {
    val connected = SocketHandler.isConnected
    val borderColor by animateColorAsState(
        targetValue = if (connected) AccentGreen else AccentRed,
        animationSpec = tween(400),
        label = "border"
    )
    val dotColor by animateColorAsState(
        targetValue = if (connected) AccentGreen else AccentRed,
        animationSpec = tween(400),
        label = "dot"
    )
    val fg by animateColorAsState(
        targetValue = if (connected) AccentGreen else AccentRed,
        animationSpec = tween(400),
        label = "fg"
    )
    val label = if (connected) "Connected" else "Offline"

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(White)
            .border(width = 1.dp, color = borderColor, shape = RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
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
