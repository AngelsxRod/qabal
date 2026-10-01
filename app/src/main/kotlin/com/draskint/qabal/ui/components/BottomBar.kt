package com.draskint.qabal.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.draskint.qabal.ui.icons.QabalIcons
import com.draskint.qabal.ui.navigation.TopLevel
import com.draskint.qabal.ui.theme.QabalTheme
import com.draskint.qabal.ui.theme.Spacing

/**
 * Barra inferior: dos pestañas, el botón central `+` y dos pestañas más. Línea superior de borde,
 * sin elevación; la pestaña activa va a opacidad plena y las demás a la secundaria.
 */
@Composable
fun QabalBottomBar(selected: TopLevel?, onTab: (TopLevel) -> Unit, onAdd: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.background(MaterialTheme.colorScheme.background).navigationBarsPadding()) {
        QabalDivider()
        Row(Modifier.fillMaxWidth().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
            Tab(TopLevel.HOME, selected, onTab)
            Tab(TopLevel.MOVEMENTS, selected, onTab)
            AddButton(onAdd)
            Tab(TopLevel.ACCOUNTS, selected, onTab)
            Tab(TopLevel.MORE, selected, onTab)
        }
    }
}

@Composable
private fun RowScope.Tab(tab: TopLevel, selected: TopLevel?, onTab: (TopLevel) -> Unit) {
    val isSelected = tab == selected
    val color = if (isSelected) QabalTheme.colors.content else QabalTheme.colors.contentSecondary
    Column(
        Modifier.weight(1f).height(64.dp)
            .clickable(role = Role.Tab) { onTab(tab) }
            .semantics { this.selected = isSelected },
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(tab.icon, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
        Text(tab.label, style = MaterialTheme.typography.labelSmall, color = color, maxLines = 1, modifier = Modifier.padding(top = Spacing.xxs))
    }
}

@Composable
private fun RowScope.AddButton(onAdd: () -> Unit) {
    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
        Box(
            Modifier.size(48.dp)
                .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(6.dp))
                .clickable(role = Role.Button, onClick = onAdd)
                .semantics { contentDescription = "Nuevo movimiento" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(QabalIcons.Add, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(24.dp))
        }
    }
}
