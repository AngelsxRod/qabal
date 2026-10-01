package com.draskint.qabal.ui.theme

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.draskint.qabal.ui.components.AmountText
import com.draskint.qabal.ui.components.AmountTone
import com.draskint.qabal.ui.components.BentoCard
import com.draskint.qabal.ui.components.QabalDivider
import com.draskint.qabal.ui.components.Wordmark
import com.draskint.qabal.ui.icons.QabalIcons

/** Muestrario del sistema de diseño (solo para Android Studio). */
@Composable
fun DesignShowcase() {
    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(Modifier.padding(Spacing.screen), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Wordmark()
            Text("Saldo total", style = MaterialTheme.typography.labelMedium, color = QabalTheme.colors.contentSecondary)
            Text("Q 12,450.00", style = QabalData.Large)
            BentoCard {
                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize().padding(bottom = Spacing.sm)) {
                    Text("Sueldo", style = MaterialTheme.typography.bodyMedium)
                    AmountText("+Q 8,000.00", AmountTone.INCOME)
                }
                QabalDivider()
                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize().padding(top = Spacing.sm)) {
                    Text("Comida", style = MaterialTheme.typography.bodyMedium)
                    AmountText("-Q 150.00", AmountTone.EXPENSE)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Button(onClick = {}) { Text("Guardar") }
                OutlinedButton(onClick = {}) { Text("Cancelar") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                listOf(QabalIcons.Home, QabalIcons.Ledger, QabalIcons.Accounts, QabalIcons.More, QabalIcons.Add).forEach {
                    Icon(it, contentDescription = null, modifier = Modifier.size(24.dp))
                }
            }
        }
    }
}

@Preview(name = "claro", showBackground = true)
@Composable
private fun LightPreview() = QabalTheme(darkTheme = false) { DesignShowcase() }

@Preview(name = "oscuro", showBackground = true)
@Composable
private fun DarkPreview() = QabalTheme(darkTheme = true) { DesignShowcase() }
