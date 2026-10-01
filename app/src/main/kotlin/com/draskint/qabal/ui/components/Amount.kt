package com.draskint.qabal.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import com.draskint.qabal.ui.theme.QabalData
import com.draskint.qabal.ui.theme.QabalTheme

/** Tipo de monto para decidir su opacidad: ingresos a 100 %, gastos a 50 %, neutro con el texto normal. */
enum class AmountTone { INCOME, EXPENSE, NEUTRAL }

/** Monto en fuente de datos de ancho fijo; el tono se expresa con opacidad, nunca con verde/rojo. */
@Composable
fun AmountText(
    text: String,
    tone: AmountTone = AmountTone.NEUTRAL,
    modifier: Modifier = Modifier,
    style: TextStyle = QabalData.Medium,
) {
    val colors = QabalTheme.colors
    Text(
        text = text, modifier = modifier, style = style,
        color = when (tone) {
            AmountTone.INCOME, AmountTone.NEUTRAL -> colors.income
            AmountTone.EXPENSE -> colors.expense
        },
    )
}
