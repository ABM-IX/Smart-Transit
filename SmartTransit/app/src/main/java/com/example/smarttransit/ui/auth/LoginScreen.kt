package com.example.smarttransit.ui.auth

import android.widget.Toast
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LocalTaxi
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Train
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.smarttransit.model.UserRole
import com.example.smarttransit.ui.theme.Black
import com.example.smarttransit.ui.theme.LightGrey
import com.example.smarttransit.ui.theme.MidGrey
import com.example.smarttransit.ui.theme.White
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth

@Composable
fun LoginScreen(onLoginSuccess: (UserRole) -> Unit) {
    val context = LocalContext.current
    val isFirebaseAvailable = try {
        FirebaseApp.getInstance()
        true
    } catch (_: Exception) {
        false
    }
    val auth = if (isFirebaseAvailable) FirebaseAuth.getInstance() else null

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var showDriverOptions by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(White)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 24.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SmartTransitTopLogo()
        }

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = if (showDriverOptions) "Select Driver Type" else "Sign in",
            style = MaterialTheme.typography.displayMedium.copy(
                fontWeight = FontWeight.ExtraBold,
                fontSize = 26.sp
            ),
            color = Black
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = if (showDriverOptions) {
                "Choose the vehicle type you operate."
            } else {
                "Sign in to continue with SmartTransit."
            },
            style = MaterialTheme.typography.bodyLarge,
            color = MidGrey
        )

        Spacer(modifier = Modifier.height(24.dp))

        if (!isFirebaseAvailable) {
            DemoModeBanner()
            Spacer(modifier = Modifier.height(20.dp))
        }

        if (!showDriverOptions) {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email Address") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Email,
                        contentDescription = null,
                        tint = Black
                    )
                },
                colors = fieldColors()
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                visualTransformation = PasswordVisualTransformation(),
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        tint = Black
                    )
                },
                colors = fieldColors()
            )

            Spacer(modifier = Modifier.height(24.dp))

            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Black, strokeWidth = 2.dp)
                }
            } else {
                Button(
                    onClick = {
                        if (email.isBlank() || password.isBlank()) {
                            Toast.makeText(context, "Please enter email and password", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        if (auth == null) {
                            onLoginSuccess(UserRole.PASSENGER)
                            return@Button
                        }
                        isLoading = true
                        auth.signInWithEmailAndPassword(email, password)
                            .addOnSuccessListener {
                                isLoading = false
                                onLoginSuccess(UserRole.PASSENGER)
                            }
                            .addOnFailureListener { error ->
                                isLoading = false
                                Toast.makeText(
                                    context,
                                    "Login failed: ${error.message}",
                                    Toast.LENGTH_LONG
                                ).show()
                            }
                    },
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
                        text = "Sign in as Passenger",
                        style = MaterialTheme.typography.titleMedium,
                        color = White
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                OutlinedButton(
                    onClick = { showDriverOptions = true },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(1.dp, Black),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = White,
                        contentColor = Black
                    )
                ) {
                    Text(
                        text = "Sign in as Driver",
                        style = MaterialTheme.typography.titleMedium,
                        color = Black
                    )
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                DriverTypeCard(
                    title = "Bus",
                    subtitle = "Scheduled intercity service",
                    icon = Icons.Default.DirectionsBus,
                    onClick = { onLoginSuccess(UserRole.DRIVER_BUS) }
                )
                DriverTypeCard(
                    title = "Combi",
                    subtitle = "Urban flexible routes",
                    icon = Icons.Default.Train,
                    onClick = { onLoginSuccess(UserRole.DRIVER_COMBI) }
                )
                DriverTypeCard(
                    title = "Taxi",
                    subtitle = "Private on-demand rides",
                    icon = Icons.Default.LocalTaxi,
                    onClick = { onLoginSuccess(UserRole.DRIVER_TAXI) }
                )

                Spacer(modifier = Modifier.height(8.dp))

                OutlinedButton(
                    onClick = { showDriverOptions = false },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(1.dp, Black),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = White,
                        contentColor = Black
                    )
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = Black
                    )
                    Spacer(modifier = Modifier.size(8.dp))
                    Text(
                        text = "Back to Sign in",
                        style = MaterialTheme.typography.titleMedium,
                        color = Black
                    )
                }
            }
        }
    }
}

@Composable
private fun SmartTransitTopLogo() {
    Box(
        modifier = Modifier.size(40.dp),
        contentAlignment = Alignment.Center
    ) {
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
private fun DemoModeBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, LightGrey, RoundedCornerShape(16.dp))
            .background(White, RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(40.dp)
                .background(Black)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(Color(0xFFD4A017), CircleShape)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column {
            Text(
                text = "Demo Mode",
                style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 0.sp),
                color = Black
            )
            Text(
                text = "Firebase is not configured, so passenger login will continue locally.",
                style = MaterialTheme.typography.bodyMedium,
                color = MidGrey
            )
        }
    }
}

@Composable
private fun DriverTypeCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.98f else 1f,
        label = "driverCardScale"
    )
    val borderColor = if (pressed) Black else LightGrey

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .scale(scale)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            ),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = White),
        border = BorderStroke(1.dp, borderColor),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(22.dp),
                tint = Black
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Black
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium.copy(fontSize = 13.sp),
                    color = MidGrey
                )
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MidGrey
            )
        }
    }
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = White,
    unfocusedContainerColor = White,
    disabledContainerColor = White,
    focusedBorderColor = Black,
    unfocusedBorderColor = LightGrey,
    focusedLabelColor = Black,
    unfocusedLabelColor = MidGrey,
    focusedTextColor = Black,
    unfocusedTextColor = Black,
    focusedLeadingIconColor = Black,
    unfocusedLeadingIconColor = Black,
    cursorColor = Black
)
