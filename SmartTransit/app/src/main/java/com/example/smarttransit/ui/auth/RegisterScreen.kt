package com.example.smarttransit.ui.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegisterScreen(onRegisterSuccess: (UserRole) -> Unit) {
    val context = LocalContext.current
    
    // Safety check for Firebase
    val isFirebaseAvailable = try {
        FirebaseApp.getInstance()
        true
    } catch (e: Exception) {
        false
    }
    
    val auth = if (isFirebaseAvailable) FirebaseAuth.getInstance() else null
    
    var step by remember { mutableIntStateOf(1) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var selectedRole by remember { mutableStateOf<UserRole?>(null) }
    var driverType by remember { mutableStateOf<UserRole?>(null) }
    var isLoading by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        if (!isFirebaseAvailable) {
            Text(
                "MOCK MODE ACTIVE (No google-services.json)",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }
        
        Text(
            text = if (step == 1) "Create Account" else "Driver Details",
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(modifier = Modifier.height(24.dp))

        if (step == 1) {
            OutlinedTextField(value = fullName, onValueChange = { fullName = it }, label = { Text("Full Name") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") }, modifier = Modifier.fillMaxWidth())
            
            Spacer(modifier = Modifier.height(24.dp))
            Text("Register As:", style = MaterialTheme.typography.titleMedium)
            
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                FilterChip(
                    selected = selectedRole == UserRole.PASSENGER,
                    onClick = { selectedRole = UserRole.PASSENGER },
                    label = { Text("Passenger") }
                )
                FilterChip(
                    selected = selectedRole != null && selectedRole != UserRole.PASSENGER,
                    onClick = { selectedRole = UserRole.DRIVER_BUS }, 
                    label = { Text("Driver") }
                )
            }

            Spacer(modifier = Modifier.height(32.dp))
            if (isLoading) {
                CircularProgressIndicator()
            } else {
                Button(
                    onClick = {
                        if (email.isEmpty() || password.isEmpty()) {
                            Toast.makeText(context, "Please fill all fields", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        if (auth == null) {
                            if (selectedRole == UserRole.PASSENGER) {
                                onRegisterSuccess(UserRole.PASSENGER)
                            } else {
                                step = 2
                            }
                            return@Button
                        }

                        if (selectedRole == UserRole.PASSENGER) {
                            isLoading = true
                            auth.createUserWithEmailAndPassword(email, password)
                                .addOnSuccessListener { 
                                    isLoading = false
                                    onRegisterSuccess(UserRole.PASSENGER) 
                                }
                                .addOnFailureListener { e -> 
                                    isLoading = false
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                }
                        } else if (selectedRole != null) {
                            step = 2
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = selectedRole != null
                ) {
                    Text(if (selectedRole == UserRole.PASSENGER) "Register" else "Next")
                }
            }
        } else {
            // Step 2: Driver Specific Info
            Text("Select Driver Type:", style = MaterialTheme.typography.titleSmall)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = driverType == UserRole.DRIVER_BUS, onClick = { driverType = UserRole.DRIVER_BUS })
                    Text("Bus Driver")
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = driverType == UserRole.DRIVER_COMBI, onClick = { driverType = UserRole.DRIVER_COMBI })
                    Text("Combi Driver")
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = driverType == UserRole.DRIVER_TAXI, onClick = { driverType = UserRole.DRIVER_TAXI })
                    Text("Taxi Driver")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            OutlinedTextField(value = "", onValueChange = {}, label = { Text("License Number") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(value = "", onValueChange = {}, label = { Text("Vehicle Registration") }, modifier = Modifier.fillMaxWidth())

            Spacer(modifier = Modifier.height(32.dp))
            if (isLoading) {
                CircularProgressIndicator()
            } else {
                Button(
                    onClick = { 
                        if (auth == null) {
                            driverType?.let { onRegisterSuccess(it) }
                            return@Button
                        }
                        
                        isLoading = true
                        auth.createUserWithEmailAndPassword(email, password)
                            .addOnSuccessListener { 
                                isLoading = false
                                driverType?.let { onRegisterSuccess(it) } 
                            }
                            .addOnFailureListener { e -> 
                                isLoading = false
                                Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                            }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = driverType != null
                ) {
                    Text("Submit for Approval")
                }
            }
            TextButton(onClick = { step = 1 }) {
                Text("Back")
            }
        }
    }
}