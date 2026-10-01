package com.draskint.qabal.ui.navigation

import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hasRoute
import com.draskint.qabal.ui.icons.QabalIcons
import kotlin.reflect.KClass

/** Pestaña de la barra inferior. */
enum class TopLevel(val route: Any, val routeClass: KClass<*>, val label: String, val icon: ImageVector) {
    HOME(Home, Home::class, "Inicio", QabalIcons.Home),
    MOVEMENTS(Movements, Movements::class, "Movimientos", QabalIcons.Ledger),
    ACCOUNTS(Accounts, Accounts::class, "Cuentas", QabalIcons.Accounts),
    MORE(More, More::class, "Más", QabalIcons.More),
}

/** Pestaña a la que pertenece el destino actual, o null si no es de la barra (p. ej. alta de movimiento). */
fun NavDestination?.topLevel(): TopLevel? = this?.let { dest -> TopLevel.entries.firstOrNull { dest.hasRoute(it.routeClass) } }
