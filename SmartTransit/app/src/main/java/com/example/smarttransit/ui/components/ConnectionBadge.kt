package com.example.smarttransit.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.smarttransit.network.SocketHandler

@Composable
fun ConnectionBadge(modifier: Modifier = Modifier) {
    val connected = SocketHandler.isConnected
    val label = if (connected) "CONNECTED" else "OFFLINE"
    val bg = if (connected) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
    val fg = if (connected) Color(0xFF2E7D32) else Color(0xFFC62828)

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.cardColors(containerColor = bg)
    ) {
        Row(
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
        ) {
            Text(label, color = fg, style = MaterialTheme.typography.labelSmall)
        }
    }
}
