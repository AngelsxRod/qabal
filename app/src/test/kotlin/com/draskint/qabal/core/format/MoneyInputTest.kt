package com.draskint.qabal.core.format

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Simula un campo de texto: cada acción edita el texto y pasa por el formateador, como el teclado. */
private class Field {
    var value = MoneyInputState("", 0)
    val text get() = value.text
    val cursor get() = value.cursor

    private fun apply(text: String, cursor: Int) {
        value = MoneyInputFormatter.format(value, MoneyInputState(text, cursor))
    }

    /** Teclea [chars] uno a uno en la posición del cursor. */
    fun type(chars: String) = apply {
        chars.forEach { ch ->
            val t = text
            val c = cursor
            apply(t.substring(0, c) + ch + t.substring(c), c + 1)
        }
    }

    fun backspace() = apply {
        val t = text
        val c = cursor
        if (c > 0) apply(t.substring(0, c - 1) + t.substring(c), c - 1)
    }

    fun moveTo(c: Int) = apply { value = value.copy(cursor = c) }

    /** Pega [chars] reemplazando todo el contenido. */
    fun paste(chars: String) = apply {
        value = MoneyInputState("", 0)
        apply(chars, chars.length)
    }

    private inline fun apply(block: () -> Unit): Field = also { block() }
}

class MoneyInputTest {

    @Test
    fun `agrupa los miles al teclear`() {
        assertEquals("1", Field().type("1").text)
        assertEquals("123", Field().type("123").text)
        assertEquals("1,234", Field().type("1234").text)
        assertEquals("12,500", Field().type("12500").text)
        assertEquals("1,234,567", Field().type("1234567").text)
    }

    @Test
    fun `con decimales`() {
        assertEquals("12,500.5", Field().type("12500.5").text)
        assertEquals("12,500.50", Field().type("12500.50").text)
        assertEquals("12,500.50", Field().type("12500.507").text) // el tercero se descarta
    }

    @Test
    fun `la coma tecleada es el decimal y se muestra como punto`() {
        assertEquals("1,234.5", Field().type("1234,5").text)
        assertEquals("1,234.50", Field().type("1234,50").text)
        assertEquals("12,500.", Field().type("12500,").text)
    }

    @Test
    fun `un segundo separador se ignora`() {
        assertEquals("12.5", Field().type("12.5.").text)
        assertEquals("12.5", Field().type("12,5,").text)
        assertEquals("12.5", Field().type("12.5,").text)
    }

    @Test
    fun `empezar por separador o por cero`() {
        assertEquals("0.5", Field().type(".5").text)
        assertEquals("0.5", Field().type(",5").text)
        assertEquals("0", Field().type("0").text)
        assertEquals("5", Field().type("05").text)
        assertEquals("0.05", Field().type("0.05").text)
    }

    @Test
    fun `rechaza mas de 12 digitos enteros`() {
        assertEquals("123,456,789,012", Field().type("1234567890123").text)
    }

    @Test
    fun `el cursor queda al final al escribir`() {
        val f = Field().type("1234")
        assertEquals(f.text.length, f.cursor)
    }

    @Test
    fun `al aparecer una coma de miles el cursor sigue tras el digito tecleado`() {
        val f = Field().type("123")
        assertEquals(3, f.cursor)
        f.type("4")
        assertEquals("1,234", f.text)
        assertEquals(5, f.cursor)
    }

    @Test
    fun `insertar en medio conserva la posicion relativa`() {
        val f = Field().type("1234")
        f.moveTo(1).type("5")
        assertEquals("15,234", f.text)
        assertEquals(2, f.cursor)
        f.type("6")
        assertEquals("156,234", f.text)
        assertEquals(3, f.cursor)
    }

    @Test
    fun `borrar un digito reagrupa sin mover el cursor de lugar`() {
        val f = Field().type("12345")
        f.backspace()
        assertEquals("1,234", f.text)
        assertEquals(5, f.cursor)
        // Borrar la coma de miles no hace nada: el cursor solo pasa al otro lado.
        f.moveTo(2).backspace()
        assertEquals("1,234", f.text)
        assertEquals(1, f.cursor)
        f.backspace()
        assertEquals("234", f.text)
    }

    @Test
    fun `teclear el separador en medio del entero parte la cifra`() {
        val f = Field().type("1234")
        f.moveTo(1).type(",")
        assertEquals("1.23", f.text)
        assertEquals(2, f.cursor)
    }

    @Test
    fun `borrar el punto decimal une las cifras`() {
        val f = Field().type("12.50")
        f.moveTo(3).backspace()
        assertEquals("1,250", f.text)
    }

    @Test
    fun `pegar formatos validos`() {
        assertEquals("1,234.50", Field().paste("1234.50").text)
        assertEquals("1,234.50", Field().paste("1,234.50").text)
        assertEquals("1,234.50", Field().paste("1234,50").text)
        assertEquals("12,500", Field().paste("12,500").text)
        assertEquals("1,234,567", Field().paste("1,234,567").text)
    }

    @Test
    fun `pegar estilo europeo se rechaza`() {
        assertEquals("", Field().paste("1.234,50").text)
    }

    @Test
    fun `pegar ignora letras y simbolos`() {
        assertEquals("125", Field().paste("Q 12a5").text)
    }

    @Test
    fun `parseInputMinor lee el formato en pantalla`() {
        val cases = mapOf(
            "1,234.50" to 123450L,
            "1,234" to 123400L, // aquí la coma es de miles: el formateador la puso
            "12,500.00" to 1250000L,
            "0.05" to 5L,
            "0.5" to 50L,
            "12." to 1200L,
            "7" to 700L,
        )
        cases.forEach { (text, minor) -> assertEquals("\"$text\"", minor, parseInputMinor(text)) }
    }

    @Test
    fun `parseInputMinor de vacio o invalido es nulo`() {
        assertNull(parseInputMinor(""))
        assertNull(parseInputMinor("  "))
        assertNull(parseInputMinor("."))
    }

    @Test
    fun `lo que produce el formateador se lee igual que lo tecleado`() {
        listOf("1234", "1234,50", "12500.5", "999999", "0,07", "1000000.99").forEach { typed ->
            val shown = Field().type(typed).text
            assertEquals("$typed → $shown", parseMinor(typed.replace(',', '.')), parseInputMinor(shown))
        }
    }
}
