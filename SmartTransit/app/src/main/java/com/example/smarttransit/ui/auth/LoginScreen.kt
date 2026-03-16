package com.example.smarttransit.ui.auth

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.smarttransit.model.UserRole

import com.google.firebase.auth.FirebaseAuth
import android.widget.Toast
import androidx.compose.ui.platform.LocalContext

import com.google.firebase.FirebaseApp

@Composable
fun LoginScreen(onLoginSuccess: (UserRole) -> Unit) {
    val context = LocalContext.current
    
    // Safety check for Firebase initialization
    val isFirebaseAvailable = try {
        FirebaseApp.getInstance()
        true
    } catch (e: Exception) {
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
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        if (!isFirebaseAvailable) {
            Text(
                "MOCK MODE ACTIVE (No google-services.json)",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.error
            )
        }

        Text(
            text = "Login to SmartTransit",
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(modifier = Modifier.height(32.dp))

        if (!showDriverOptions) {
            // Main Login Options
            OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(24.dp))

            if (isLoading) {
                CircularProgressIndicator()
            } else {
                Button(
                    onClick = { 
                        if (email.isEmpty() || password.isEmpty()) {
                            Toast.makeText(context, "Please enter email and password", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        
                        if (auth == null) {
                            // Mock success
                            onLoginSuccess(UserRole.PASSENGER)
                            return@Button
                        }

                        isLoading = true
                        auth.signInWithEmailAndPassword(email, password)
                            .addOnSuccessListener { 
                                isLoading = false
                                onLoginSuccess(UserRole.PASSENGER) 
                            }
                            .addOnFailureListener { e -> 
                                isLoading = false
                                Toast.makeText(context, "Login failed: ${e.message}", Toast.LENGTH_LONG).show()
                            }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                ) {
                    Text("Login as Passenger")
                }

                Spacer(modifier = Modifier.height(16.dp))

                OutlinedButton(
                    onClick = { showDriverOptions = true },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                ) {
                    Text("Login as Driver")
                }
            }
        } else {
            // Driver Type Selection
            Text("Select Driver Type", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = { onLoginSuccess(UserRole.DRIVER_BUS) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Bus Driver")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = { onLoginSuccess(UserRole.DRIVER_COMBI) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Combi Driver")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = { onLoginSuccess(UserRole.DRIVER_TAXI) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Taxi Driver")
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            TextButton(onClick = { showDriverOptions = false }) {
                Text("Back")
            }
        }
    }
}