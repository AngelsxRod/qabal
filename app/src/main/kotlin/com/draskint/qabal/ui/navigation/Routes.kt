package com.draskint.qabal.ui.navigation

import kotlinx.serialization.Serializable

/** Destinos de la barra inferior. */
@Serializable data object Home
@Serializable data object Movements
@Serializable data object Accounts
@Serializable data object More

/** Alta de un movimiento: pantalla completa abierta desde el botón central `+`, sin barra inferior. */
@Serializable data object NewMovement
