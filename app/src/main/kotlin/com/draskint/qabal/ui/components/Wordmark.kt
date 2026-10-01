package com.draskint.qabal.ui.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/** Logotipo: solo el wordmark `qabal`, siempre en minúsculas. */
@Composable
fun Wordmark(modifier: Modifier = Modifier, size: TextUnit = 24.sp, color: Color = MaterialTheme.colorScheme.onBackground) {
    Text(
        text = "qabal", modifier = modifier, color = color,
        style = MaterialTheme.typography.headlineSmall.copy(
            fontSize = size, lineHeight = size * 1.2f, fontWeight = FontWeight.SemiBold, letterSpacing = (-0.04f).em,
        ),
    )
}
