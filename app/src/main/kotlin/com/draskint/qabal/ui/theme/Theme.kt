package com.draskint.qabal.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver

/**
 * Esquema monocromo: los botones llenos usan el color de contenido; las superficies y los
 * contenedores se distinguen por el borde, no por tonos. Sin rojo: el error se comunica con texto.
 */
private fun scheme(c: QabalColors, dark: Boolean): ColorScheme {
    val tint = c.content.copy(alpha = 0.04f).compositeOver(c.background)
    val base = if (dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = c.content, onPrimary = c.background,
        primaryContainer = c.border, onPrimaryContainer = c.content,
        inversePrimary = c.content,
        secondary = c.content, onSecondary = c.background,
        secondaryContainer = c.border, onSecondaryContainer = c.content,
        tertiary = c.content, onTertiary = c.background,
        tertiaryContainer = c.border, onTertiaryContainer = c.content,
        background = c.background, onBackground = c.content,
        surface = c.background, onSurface = c.content,
        surfaceVariant = c.border, onSurfaceVariant = c.contentSecondary,
        surfaceTint = c.content,
        inverseSurface = c.content, inverseOnSurface = c.background,
        error = c.content, onError = c.background,
        errorContainer = c.border, onErrorContainer = c.content,
        outline = c.border, outlineVariant = c.border,
        scrim = Color.Black,
        surfaceBright = c.background, surfaceDim = c.background, surfaceContainerLowest = c.background,
        surfaceContainerLow = tint, surfaceContainer = tint,
        surfaceContainerHigh = c.border, surfaceContainerHighest = c.border,
    )
}

object QabalTheme {
    val colors: QabalColors
        @Composable get() = LocalQabalColors.current
}

@Composable
fun QabalTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) QabalColors.Dark else QabalColors.Light
    CompositionLocalProvider(LocalQabalColors provides colors) {
        MaterialTheme(
            colorScheme = scheme(colors, darkTheme),
            typography = QabalTypography,
            shapes = QabalShapes,
            content = content,
        )
    }
}
