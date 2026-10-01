package com.draskint.qabal.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.draskint.qabal.ui.theme.QabalTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class QabalAppTest {

    @get:Rule
    val compose = createComposeRule()

    private fun start() = compose.setContent { QabalTheme { QabalApp() } }

    @Test
    fun `arranca en Inicio con la barra inferior completa`() {
        start()
        compose.onNodeWithText("Próximamente").assertIsDisplayed()
        // "Inicio" aparece dos veces: el título de la pantalla y la pestaña.
        listOf("Inicio", "Movimientos", "Cuentas", "Más").forEach { compose.onAllNodesWithText(it).onFirst().assertIsDisplayed() }
        compose.onNodeWithContentDescription("Nuevo movimiento").assertIsDisplayed()
    }

    @Test
    fun `cada pestana muestra su pantalla`() {
        start()
        compose.onNodeWithText("Movimientos").performClick()
        compose.onNodeWithText("Hito 2: listado, filtros y alta de movimientos.").assertIsDisplayed()
        compose.onNodeWithText("Cuentas").performClick()
        compose.onNodeWithText("Hitos 2 y 3: cuentas y tarjetas de crédito.").assertIsDisplayed()
        compose.onNodeWithText("Más").performClick()
        compose.onNodeWithText("Catálogos, deudas y ajustes.").assertIsDisplayed()
    }

    @Test
    fun `el boton central abre el alta de movimiento sin barra inferior`() {
        start()
        compose.onNodeWithContentDescription("Nuevo movimiento").performClick()
        compose.onNodeWithText("Hito 2: formulario de alta.").assertIsDisplayed()
        assertTrue(compose.onAllNodes(hasContentDescription("Nuevo movimiento")).fetchSemanticsNodes().isEmpty())
        assertTrue(compose.onAllNodes(hasText("Cuentas")).fetchSemanticsNodes().isEmpty())
    }
}
