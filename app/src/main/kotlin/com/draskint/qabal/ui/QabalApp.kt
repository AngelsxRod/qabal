package com.draskint.qabal.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.draskint.qabal.ui.components.QabalBottomBar
import com.draskint.qabal.ui.navigation.Accounts
import com.draskint.qabal.ui.navigation.Home
import com.draskint.qabal.ui.navigation.Movements
import com.draskint.qabal.ui.navigation.More
import com.draskint.qabal.ui.navigation.NewMovement
import com.draskint.qabal.ui.navigation.topLevel
import com.draskint.qabal.ui.screens.PlaceholderScreen

/** Raíz de la interfaz: navegación type-safe con barra inferior y botón central `+`. */
@Composable
fun QabalApp() {
    val nav = rememberNavController()
    val destination by nav.currentBackStackEntryAsState()
    val current = destination?.destination.topLevel()

    Scaffold(
        bottomBar = {
            // La barra solo existe en las pestañas; el alta de movimiento ocupa toda la pantalla.
            if (current != null) {
                QabalBottomBar(
                    selected = current,
                    onTab = { tab ->
                        nav.navigate(tab.route) {
                            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onAdd = { nav.navigate(NewMovement) { launchSingleTop = true } },
                )
            }
        },
    ) { padding ->
        NavHost(nav, startDestination = Home, modifier = Modifier.padding(padding)) {
            composable<Home> { PlaceholderScreen("Inicio", "Hito 2: saldo total, deuda de tarjetas y resumen mensual.") }
            composable<Movements> { PlaceholderScreen("Movimientos", "Hito 2: listado, filtros y alta de movimientos.") }
            composable<Accounts> { PlaceholderScreen("Cuentas", "Hitos 2 y 3: cuentas y tarjetas de crédito.") }
            composable<More> { PlaceholderScreen("Más", "Catálogos, deudas y ajustes.") }
            composable<NewMovement> { PlaceholderScreen("Nuevo movimiento", "Hito 2: formulario de alta.") }
        }
    }
}
