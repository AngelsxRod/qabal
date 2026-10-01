package com.draskint.qabal.core.format

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MoneyTest {

    @Test
    fun `formatMoney agrupa miles y siempre lleva 2 decimales`() {
        assertEquals("Q1,234.50", formatMoney(123450, "GTQ"))
        assertEquals("Q0.00", formatMoney(0, "GTQ"))
        assertEquals("Q0.05", formatMoney(5, "GTQ"))
        assertEquals("Q1.00", formatMoney(100, "GTQ"))
        assertEquals("Q1,000,000.00", formatMoney(100000000, "GTQ"))
        assertEquals("Q999.99", formatMoney(99999, "GTQ"))
    }

    @Test
    fun `el signo va delante del simbolo`() {
        assertEquals("-Q1,234.50", formatMoney(-123450, "GTQ"))
        assertEquals("-Q0.01", formatMoney(-1, "GTQ"))
    }

    @Test
    fun `usa el simbolo de la moneda o el codigo separado`() {
        assertEquals("US$10.50", formatMoney(1050, "USD"))
        assertEquals("€10.50", formatMoney(1050, "EUR"))
        assertEquals("CHF 10.50", formatMoney(1050, "CHF"))
    }

    @Test
    fun `formatSignedMoney marca los positivos`() {
        assertEquals("+Q10.00", formatSignedMoney(1000, "GTQ"))
        assertEquals("-Q10.00", formatSignedMoney(-1000, "GTQ"))
        assertEquals("Q0.00", formatSignedMoney(0, "GTQ"))
    }

    @Test
    fun `formatPlain no lleva miles ni simbolo`() {
        assertEquals("1234.50", formatPlain(123450))
        assertEquals("1000000.00", formatPlain(100000000))
        assertEquals("0.07", formatPlain(7))
        assertEquals("0.00", formatPlain(0))
        assertEquals("-2.50", formatPlain(-250))
    }

    @Test
    fun `formatPlain es reversible con parseMinor`() {
        listOf(0L, 1, 99, 100, 123450, 99999999999).forEach { assertEquals(it, parseMinor(formatPlain(it))) }
    }

    @Test
    fun `formatGrouped agrupa sin simbolo`() {
        assertEquals("1,234.50", formatGrouped(123450))
        assertEquals("0.00", formatGrouped(0))
        assertEquals("12,500.00", formatGrouped(1250000))
    }

    @Test
    fun `parseMinor acepta formatos validos`() {
        val cases = mapOf(
            "0" to 0L, "5" to 500L, "1234" to 123400L, "1234.5" to 123450L, "1234.50" to 123450L,
            "0.05" to 5L, ".5" to 50L, "007" to 700L,
            // La coma es decimal cuando es el único separador y hay 1 o 2 dígitos.
            "1234,50" to 123450L, "1234,5" to 123450L, "0,05" to 5L, ",5" to 50L,
            // Con ambos separadores, la coma son miles y el punto el decimal.
            "1,234.50" to 123450L, "1,234.5" to 123450L, "12,345.67" to 1234567L,
            "1,234,567" to 123456700L, "1,234,567.89" to 123456789L,
            // Los espacios se ignoran.
            " 12.50 " to 1250L, "1 234.50" to 123450L,
        )
        cases.forEach { (input, expected) -> assertEquals("\"$input\"", expected, parseMinor(input)) }
    }

    @Test
    fun `parseMinor rechaza lo ambiguo o invalido`() {
        val invalid = listOf(
            "", "   ", ".", ",", "abc", "12a", "-5", "+5", "1e3",
            // Coma seguida de 3 dígitos: ¿decimal o miles?
            "1,234", "12,345",
            // Más de 2 decimales.
            "1.234", "1.2345", "1234,567", "1234,5678",
            // Separador al final o dobles.
            "12.", "12,", "1..5", "1,,5",
            // Estilo europeo y otros mixtos.
            "1.234,50", "1.234.567", "1.234.567,89",
            // Agrupación de miles mal formada.
            "1,23,456.00", "1234,567.00", "12,3.45", "1,2,3",
            // Demasiado grande.
            "1234567890123",
        )
        invalid.forEach { assertNull("\"$it\"", parseMinor(it)) }
    }
}
