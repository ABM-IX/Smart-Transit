package com.example.smarttransit.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.smarttransit.ui.theme.Black
import com.example.smarttransit.ui.theme.LightGrey
import com.example.smarttransit.ui.theme.MidGrey
import com.example.smarttransit.ui.theme.White

@Composable
fun WelcomeScreen(
    onLoginClick: () -> Unit,
    onRegisterClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(White)
            .padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.weight(0.22f))

        SmartTransitWordmark(size = 72.dp, hero = true)

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "SmartTransit",
            style = MaterialTheme.typography.displayLarge.copy(
                fontSize = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.5).sp
            ),
            color = Black
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Gaborone, Botswana",
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 12.sp,
                letterSpacing = 1.sp
            ),
            color = MidGrey
        )

        Spacer(modifier = Modifier.height(20.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            FeatureChip("Bus")
            FeatureChip("Combi")
            FeatureChip("Taxi")
        }

        Spacer(modifier = Modifier.height(28.dp))
        HorizontalDivider(color = LightGrey, thickness = 1.dp)
        Spacer(modifier = Modifier.height(28.dp))

        Button(
            onClick = onLoginClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Black,
                contentColor = White
            ),
            elevation = null
        ) {
            Text(
                text = "Get Started",
                style = MaterialTheme.typography.titleMedium,
                color = White
            )
            Spacer(modifier = Modifier.size(8.dp))
            Text(
                text = "->",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = White
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onRegisterClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(14.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, Black),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = White,
                contentColor = Black
            )
        ) {
            Text(
                text = "Create Account",
                style = MaterialTheme.typography.titleMedium,
                color = Black
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        Text(
            text = "Smart Transit | Public Transport Platform",
            style = MaterialTheme.typography.labelSmall,
            color = MidGrey,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun FeatureChip(label: String) {
    Surface(
        color = White,
        shape = RoundedCornerShape(20.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Black)
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            style = MaterialTheme.typography.labelLarge.copy(fontSize = 12.sp),
            color = Black
        )
    }
}

@Composable
private fun SmartTransitWordmark(size: androidx.compose.ui.unit.Dp, hero: Boolean = false) {
    Box(
        modifier = Modifier.size(size),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "ST",
            style = if (hero) {
                MaterialTheme.typography.displayMedium.copy(
                    fontWeight = FontWeight.ExtraBold,
                    letterSpacing = (-1).sp
                )
            } else {
                MaterialTheme.typography.titleLarge.copy(
                    fontWeight = FontWeight.ExtraBold,
                    letterSpacing = (-0.6).sp
                )
            },
            color = Black
        )
    }
}
