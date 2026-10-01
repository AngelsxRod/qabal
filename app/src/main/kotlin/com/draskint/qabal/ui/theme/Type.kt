package com.draskint.qabal.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.draskint.qabal.R

val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
    Font(R.font.inter_bold, FontWeight.Bold),
)

/** Cifras y datos pequeños: ancho fijo para alinear montos en columna. */
val DataFont: FontFamily = FontFamily.Monospace

private fun inter(size: Int, line: Int, weight: FontWeight, tracking: Float = 0f) = TextStyle(
    fontFamily = Inter, fontWeight = weight, fontSize = size.sp, lineHeight = line.sp, letterSpacing = tracking.em,
)

/** Títulos grandes y pesados, con tracking ajustado; cuerpo en Regular. */
val QabalTypography = Typography(
    displayLarge = inter(52, 56, FontWeight.Bold, -0.03f),
    displayMedium = inter(40, 44, FontWeight.Bold, -0.03f),
    displaySmall = inter(32, 36, FontWeight.Bold, -0.02f),
    headlineLarge = inter(28, 34, FontWeight.Bold, -0.02f),
    headlineMedium = inter(24, 30, FontWeight.SemiBold, -0.02f),
    headlineSmall = inter(20, 26, FontWeight.SemiBold, -0.01f),
    titleLarge = inter(18, 24, FontWeight.SemiBold, -0.01f),
    titleMedium = inter(16, 22, FontWeight.SemiBold),
    titleSmall = inter(14, 20, FontWeight.Medium),
    bodyLarge = inter(16, 24, FontWeight.Normal),
    bodyMedium = inter(14, 20, FontWeight.Normal),
    bodySmall = inter(12, 16, FontWeight.Normal),
    labelLarge = inter(14, 20, FontWeight.Medium),
    labelMedium = inter(12, 16, FontWeight.Medium, 0.02f),
    labelSmall = inter(11, 16, FontWeight.Medium, 0.04f),
)

/** Estilos de datos (montos, fechas, cifras de tablas) en la fuente de ancho fijo. */
object QabalData {
    val Large = TextStyle(fontFamily = DataFont, fontWeight = FontWeight.Medium, fontSize = 28.sp, lineHeight = 34.sp, letterSpacing = (-0.02f).em)
    val Medium = TextStyle(fontFamily = DataFont, fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 22.sp)
    val Small = TextStyle(fontFamily = DataFont, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 16.sp)
}
