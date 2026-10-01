package com.draskint.qabal.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** Colores semánticos de qabal que Material 3 no modela. */
@Immutable
class QabalColors(
    /** Fondo de la pantalla. */
    val background: Color,
    /** Texto y trazos principales. */
    val content: Color,
    /** Bordes y separadores. */
    val border: Color,
) {
    /** Texto secundario (etiquetas, fechas). */
    val contentSecondary: Color get() = content.copy(alpha = QabalPalette.SecondaryAlpha)

    /** Ingresos: contenido pleno. */
    val income: Color get() = content

    /** Gastos: 50 % de opacidad frente a los ingresos. */
    val expense: Color get() = content.copy(alpha = 0.5f)

    companion object {
        val Light = QabalColors(background = QabalPalette.White, content = QabalPalette.Black, border = QabalPalette.BorderLight)
        val Dark = QabalColors(background = QabalPalette.Black, content = QabalPalette.White, border = QabalPalette.BorderDark)
    }
}

val LocalQabalColors = staticCompositionLocalOf { QabalColors.Light }
