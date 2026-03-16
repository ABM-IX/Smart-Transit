package com.example.smarttransit.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.example.smarttransit.model.UserRole
import com.example.smarttransit.ui.auth.LoginScreen
import com.example.smarttransit.ui.auth.RegisterScreen
import com.example.smarttransit.ui.auth.WelcomeScreen
import com.example.smarttransit.ui.passenger.PassengerDashboard
import com.example.smarttransit.ui.driver.DriverDashboard

sealed class Screen(val route: String) {
    object Welcome : Screen("welcome")
    object Login : Screen("login")
    object Register : Screen("register")
    object PassengerDashboard : Screen("passenger_dashboard")
    object DriverDashboard : Screen("driver_dashboard")
}

@Composable
fun NavGraph(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = Screen.Welcome.route
    ) {
        composable(Screen.Welcome.route) {
            WelcomeScreen(
                onLoginClick = { navController.navigate(Screen.Login.route) },
                onRegisterClick = { navController.navigate(Screen.Register.route) }
            )
        }
        composable(Screen.Login.route) {
            LoginScreen(onLoginSuccess = { role ->
                navigateToDashboard(navController, role)
            })
        }
        composable(Screen.Register.route) {
            RegisterScreen(onRegisterSuccess = { role ->
                navigateToDashboard(navController, role)
            })
        }
        composable(Screen.PassengerDashboard.route) {
            PassengerDashboard()
        }
        composable(Screen.DriverDashboard.route + "/{role}") { backStackEntry ->
            val roleName = backStackEntry.arguments?.getString("role")
            val role = roleName?.let { UserRole.valueOf(it) } ?: UserRole.DRIVER_BUS
            DriverDashboard(role)
        }
    }
}

private fun navigateToDashboard(navController: NavHostController, role: UserRole) {
    val route = when (role) {
        UserRole.PASSENGER -> Screen.PassengerDashboard.route
        else -> Screen.DriverDashboard.route + "/${role.name}"
    }
    navController.navigate(route) {
        popUpTo(Screen.Welcome.route) { inclusive = true }
    }
}