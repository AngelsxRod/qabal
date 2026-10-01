package com.draskint.qabal.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Paleta monocroma de qabal: blanco y negro con un solo gris de borde. Ingresos y gastos se
 * distinguen por opacidad, no por color (ver [QabalColors.income] y [QabalColors.expense]).
 */
object QabalPalette {
    val White = Color(0xFFFFFFFF)
    val Black = Color(0xFF0A0A0A)
    val BorderLight = Color(0xFFE5E5E5)
    val BorderDark = Color(0xFF1A1A1A)

    /** Texto secundario: 55 % del color de contenido (contraste AA sobre el fondo en ambos temas). */
    const val SecondaryAlpha = 0.55f

    /** Texto deshabilitado o gasto atenuado. */
    const val TertiaryAlpha = 0.38f
}
