package com.draskint.qabal.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.CardDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import com.draskint.qabal.ui.theme.BorderWidth
import com.draskint.qabal.ui.theme.QabalTheme
import com.draskint.qabal.ui.theme.Spacing

/** Módulo del bento grid: borde definido, sin sombra ni elevación. */
@Composable
fun BentoCard(
    modifier: Modifier = Modifier,
    padding: Dp = Spacing.md,
    content: @Composable ColumnScope.() -> Unit,
) {
    OutlinedCard(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.background),
        border = BorderStroke(BorderWidth, QabalTheme.colors.border),
        elevation = CardDefaults.outlinedCardElevation(),
    ) {
        Column(Modifier.fillMaxWidth().padding(padding), content = content)
    }
}

/** Línea separadora del color de borde. */
@Composable
fun QabalDivider(modifier: Modifier = Modifier) =
    HorizontalDivider(modifier, thickness = BorderWidth, color = QabalTheme.colors.border)
