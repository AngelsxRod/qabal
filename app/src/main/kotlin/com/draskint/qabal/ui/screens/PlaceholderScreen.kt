package com.draskint.qabal.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.draskint.qabal.ui.components.BentoCard
import com.draskint.qabal.ui.theme.QabalTheme
import com.draskint.qabal.ui.theme.Spacing

/** Pantalla provisional de un destino cuyo contenido llega en un hito posterior. */
@Composable
fun PlaceholderScreen(title: String, hito: String, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(Spacing.screen),
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        Text(title, style = MaterialTheme.typography.displaySmall)
        BentoCard {
            Text("Próximamente", style = MaterialTheme.typography.titleMedium)
            Text(hito, style = MaterialTheme.typography.bodyMedium, color = QabalTheme.colors.contentSecondary)
        }
    }
}
