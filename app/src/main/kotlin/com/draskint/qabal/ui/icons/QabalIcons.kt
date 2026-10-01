package com.draskint.qabal.ui.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * Iconos propios de qabal: trazo lineal de 1.5 dp, esquinas rectas y sin relleno, sobre una
 * cuadrícula de 24. Se tiñen con `tint`, así que el trazo es negro aquí.
 */
object QabalIcons {

    private fun icon(name: String, block: PathBuilder.() -> Unit): ImageVector =
        ImageVector.Builder(name = "qabal.$name", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f)
            .path(
                stroke = SolidColor(Color.Black), strokeLineWidth = 1.5f,
                strokeLineCap = StrokeCap.Square, strokeLineJoin = StrokeJoin.Miter, pathBuilder = block,
            ).build()

    /** Inicio: cuadrícula bento de cuatro módulos. */
    val Home: ImageVector = icon("home") {
        moveTo(4f, 4f); horizontalLineTo(11f); verticalLineTo(13f); horizontalLineTo(4f); close()
        moveTo(13f, 4f); horizontalLineTo(20f); verticalLineTo(9f); horizontalLineTo(13f); close()
        moveTo(13f, 11f); horizontalLineTo(20f); verticalLineTo(20f); horizontalLineTo(13f); close()
        moveTo(4f, 15f); horizontalLineTo(11f); verticalLineTo(20f); horizontalLineTo(4f); close()
    }

    /** Movimientos: tres líneas de libro mayor con un punto al inicio. */
    val Ledger: ImageVector = icon("ledger") {
        moveTo(4f, 6f); horizontalLineTo(5f)
        moveTo(8f, 6f); horizontalLineTo(20f)
        moveTo(4f, 12f); horizontalLineTo(5f)
        moveTo(8f, 12f); horizontalLineTo(20f)
        moveTo(4f, 18f); horizontalLineTo(5f)
        moveTo(8f, 18f); horizontalLineTo(20f)
    }

    /** Cuentas: barras apiladas de ancho decreciente. */
    val Accounts: ImageVector = icon("accounts") {
        moveTo(4f, 5f); horizontalLineTo(20f); verticalLineTo(9f); horizontalLineTo(4f); close()
        moveTo(4f, 11f); horizontalLineTo(16f); verticalLineTo(15f); horizontalLineTo(4f); close()
        moveTo(4f, 17f); horizontalLineTo(12f); verticalLineTo(21f); horizontalLineTo(4f); close()
    }

    /** Más: tres cuadrados alineados. */
    val More: ImageVector = icon("more") {
        moveTo(4f, 10.5f); horizontalLineTo(7f); verticalLineTo(13.5f); horizontalLineTo(4f); close()
        moveTo(10.5f, 10.5f); horizontalLineTo(13.5f); verticalLineTo(13.5f); horizontalLineTo(10.5f); close()
        moveTo(17f, 10.5f); horizontalLineTo(20f); verticalLineTo(13.5f); horizontalLineTo(17f); close()
    }

    /** Agregar: cruz. */
    val Add: ImageVector = icon("add") {
        moveTo(12f, 4f); verticalLineTo(20f)
        moveTo(4f, 12f); horizontalLineTo(20f)
    }
}
