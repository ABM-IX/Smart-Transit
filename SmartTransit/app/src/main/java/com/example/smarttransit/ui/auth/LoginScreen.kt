package com.example.smarttransit.ui.auth

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.smarttransit.model.UserRole

import com.google.firebase.auth.FirebaseAuth
import android.widget.Toast
import com.google.firebase.FirebaseApp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(onLoginSuccess: (UserRole) -> Unit) {
    val context = LocalContext.current

    val isFirebaseAvailable = try {
        FirebaseApp.getInstance(); true
    } catch (e: Exception) { false }
    val auth = if (isFirebaseAvailable) FirebaseAuth.getInstance() else null

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var showDriverOptions by remember { mutableStateOf(false) }
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    val infiniteTransition = rememberInfiniteTransition(label = "bg")
    val gradientOffset by infiniteTransition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(10000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ), label = "grad"
    )

    Box(
        modifier = Modifier.fillMaxSize().background(Color(0xFF0A0F1E))
    ) {
        // Background orbs
        Box(Modifier.size(280.dp).offset(x = 200.dp, y = (80 + 40 * gradientOffset).dp).alpha(0.2f).blur(80.dp).clip(CircleShape).background(Color(0xFF3B82F6)))
        Box(Modifier.size(220.dp).offset(x = (-60).dp, y = (500 - 30 * gradientOffset).dp).alpha(0.15f).blur(80.dp).clip(CircleShape).background(Color(0xFF06B6D4)))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(tween(600)) + slideInVertically(initialOffsetY = { it / 5 }, animationSpec = tween(600, easing = EaseOutCubic))
        ) {
            Column(
                modifier = Modifier.fillMaxSize().padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(Modifier.height(60.dp))

                Text(
                    if (showDriverOptions) "Select Driver Type" else "Welcome Back",
                    fontSize = 28.sp, fontWeight = FontWeight.Bold,
                    color = Color.White, letterSpacing = (-0.5).sp
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    if (showDriverOptions) "Choose your vehicle type to continue" else "Sign in to continue your journey",
                    fontSize = 14.sp, color = Color(0xFF9CA3AF)
                )

                Spacer(Modifier.height(40.dp))

                AnimatedContent(
                    targetState = showDriverOptions,
                    transitionSpec = {
                        slideInHorizontally(tween(300)) { if (targetState) it else -it } + fadeIn(tween(300)) togetherWith
                        slideOutHorizontally(tween(300)) { if (targetState) -it else it } + fadeOut(tween(300))
                    },
                    label = "mode"
                ) { isDriverMode ->
                    if (!isDriverMode) {
                        Column(
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            if (!isFirebaseAvailable) {
                                Surface(
                                    shape = RoundedCornerShape(12.dp),
                                    color = Color(0xFF1C1917),
                                    border = ButtonDefaults.outlinedButtonBorder(true).copy(
                                        brush = Brush.linearGradient(listOf(Color(0xFF78350F), Color(0xFF451A03)))
                                    )
                                ) {
                                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Info, null, tint = Color(0xFFFBBF24), modifier = Modifier.size(16.dp))
                                        Spacer(Modifier.width(8.dp))
                                        Text("Demo Mode — Firebase not configured", fontSize = 12.sp, color = Color(0xFFFCD34D))
                                    }
                                }
                            }

                            OutlinedTextField(
                                value = email, onValueChange = { email = it },
                                label = { Text("Email Address") },
                                leadingIcon = { Icon(Icons.Default.Email, null, tint = Color(0xFF6B7280)) },
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(14.dp),
                                singleLine = true,
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = Color(0xFF3B82F6),
                                    unfocusedBorderColor = Color(0xFF374151),
                                    focusedContainerColor = Color(0xFF111827),
                                    unfocusedContainerColor = Color(0xFF111827),
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedLabelColor = Color(0xFF9CA3AF),
                                    unfocusedLabelColor = Color(0xFF6B7280)
                                )
                            )

                            OutlinedTextField(
                                value = password, onValueChange = { password = it },
                                label = { Text("Password") },
                                leadingIcon = { Icon(Icons.Default.Lock, null, tint = Color(0xFF6B7280)) },
                                visualTransformation = PasswordVisualTransformation(),
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(14.dp),
                                singleLine = true,
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = Color(0xFF3B82F6),
                                    unfocusedBorderColor = Color(0xFF374151),
                                    focusedContainerColor = Color(0xFF111827),
                                    unfocusedContainerColor = Color(0xFF111827),
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedLabelColor = Color(0xFF9CA3AF),
                                    unfocusedLabelColor = Color(0xFF6B7280)
                                )
                            )

                            Spacer(Modifier.height(8.dp))

                            if (isLoading) {
                                Box(Modifier.fillMaxWidth().height(56.dp), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(color = Color(0xFF3B82F6), strokeWidth = 3.dp)
                                }
                            } else {
                                Button(
                                    onClick = {
                                        if (email.isEmpty() || password.isEmpty()) {
                                            Toast.makeText(context, "Please enter email and password", Toast.LENGTH_SHORT).show()
                                            return@Button
                                        }
                                        if (auth == null) { onLoginSuccess(UserRole.PASSENGER); return@Button }
                                        isLoading = true
                                        auth.signInWithEmailAndPassword(email, password)
                                            .addOnSuccessListener { isLoading = false; onLoginSuccess(UserRole.PASSENGER) }
                                            .addOnFailureListener { e ->
                                                isLoading = false
                                                Toast.makeText(context, "Login failed: ${e.message}", Toast.LENGTH_LONG).show()
                                            }
                                    },
                                    modifier = Modifier.fillMaxWidth().height(56.dp),
                                    shape = RoundedCornerShape(16.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3B82F6)),
                                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 6.dp)
                                ) {
                                    Icon(Icons.Default.Person, null, modifier = Modifier.size(20.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Sign in as Passenger", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                                }

                                Spacer(Modifier.height(4.dp))

                                OutlinedButton(
                                    onClick = { showDriverOptions = true },
                                    modifier = Modifier.fillMaxWidth().height(56.dp),
                                    shape = RoundedCornerShape(16.dp),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White),
                                    border = ButtonDefaults.outlinedButtonBorder(true).copy(
                                        brush = Brush.linearGradient(listOf(Color(0xFF374151), Color(0xFF4B5563)))
                                    )
                                ) {
                                    Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(20.dp), tint = Color(0xFF9CA3AF))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Sign in as Driver", fontSize = 15.sp, fontWeight = FontWeight.Medium)
                                }
                            }
                        }
                    } else {
                        Column(
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DriverTypeCard(
                                title = "Bus Driver",
                                subtitle = "Intercity & scheduled routes",
                                icon = Icons.Default.DirectionsBus,
                                gradientColors = listOf(Color(0xFF8B5CF6), Color(0xFF6D28D9)),
                                onClick = { onLoginSuccess(UserRole.DRIVER_BUS) }
                            )
                            DriverTypeCard(
                                title = "Combi Driver",
                                subtitle = "Urban & flexible routes",
                                icon = Icons.Default.AirportShuttle,
                                gradientColors = listOf(Color(0xFF06B6D4), Color(0xFF0891B2)),
                                onClick = { onLoginSuccess(UserRole.DRIVER_COMBI) }
                            )
                            DriverTypeCard(
                                title = "Taxi Driver",
                                subtitle = "Private & on-demand rides",
                                icon = Icons.Default.LocalTaxi,
                                gradientColors = listOf(Color(0xFFF59E0B), Color(0xFFD97706)),
                                onClick = { onLoginSuccess(UserRole.DRIVER_TAXI) }
                            )

                            Spacer(Modifier.height(8.dp))
                            TextButton(
                                onClick = { showDriverOptions = false },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color(0xFF9CA3AF), modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Back to login", color = Color(0xFF9CA3AF))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DriverTypeCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    gradientColors: List<Color>,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF111827)),
        border = ButtonDefaults.outlinedButtonBorder(true).copy(
            brush = Brush.linearGradient(listOf(Color(0xFF1F2937), Color(0xFF374151)))
        )
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.size(52.dp),
                color = Color.Transparent
            ) {
                Box(
                    modifier = Modifier.fillMaxSize().background(
                        Brush.linearGradient(gradientColors), shape = RoundedCornerShape(14.dp)
                    ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(icon, null, tint = Color.White, modifier = Modifier.size(28.dp))
                }
            }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White)
                Text(subtitle, fontSize = 13.sp, color = Color(0xFF9CA3AF))
            }
            Icon(Icons.Default.ChevronRight, null, tint = Color(0xFF4B5563), modifier = Modifier.size(24.dp))
        }
    }
}