package com.draskint.qabal.core.format

/** Texto de un campo con la posición del cursor (sin selección). */
data class MoneyInputState(val text: String = "", val cursor: Int = text.length)

/**
 * Formatea un monto mientras se escribe: agrupa los miles con coma y usa el punto como decimal
 * (`12,500.00`). No depende de Compose: la capa de UI lo adapta a su tipo de campo.
 *
 * - El teclado puede producir `,` o `.`: el separador que se teclea (uno solo, mientras no haya
 *   decimal) es el decimal, y se muestra siempre como `.`. Las comas que ya están en pantalla son
 *   de miles.
 * - Al pegar texto: `1234,50` (coma con 1 o 2 dígitos) es decimal, `12,500` son miles, `1,234.50`
 *   mezcla bien; el estilo europeo (`1.234,50`) se rechaza (no se aplica el cambio).
 * - Máximo 12 dígitos enteros y 2 decimales.
 * - El cursor se conserva contando los dígitos (y el punto) que había a su izquierda.
 */
object MoneyInputFormatter {

    private val nonDigits = Regex("[^0-9]")
    private val leadingZeros = Regex("""^0+(?=\d)""")
    private val oneOrTwoDigits = Regex("""^\d{1,2}$""")

    private fun digits(s: String) = s.replace(nonDigits, "")

    /** Devuelve el estado a mostrar tras pasar de [old] a [new]; si rechaza el cambio, devuelve [old]. */
    fun format(old: MoneyInputState, new: MoneyInputState): MoneyInputState {
        val o = old.text
        val n = new.text
        val cursor = new.cursor.coerceIn(0, n.length)

        var whole: String
        var decimals: String? // null = sin separador decimal
        var sig: Int // caracteres significativos (dígitos y punto) a la izquierda del cursor

        val typedSeparator = n.length == o.length + 1 &&
            cursor > 0 &&
            (n[cursor - 1] == ',' || n[cursor - 1] == '.') &&
            n.substring(0, cursor - 1) + n.substring(cursor) == o

        if (typedSeparator) {
            if ('.' in o) return old // ya hay decimal
            val left = digits(n.substring(0, cursor - 1))
            whole = left
            decimals = digits(n.substring(cursor))
            sig = left.length + 1
        } else if ('.' in n) {
            val lastDot = n.lastIndexOf('.')
            if (n.lastIndexOf(',') > lastDot) return old // 1.234,50
            val i = n.indexOf('.')
            whole = digits(n.substring(0, i))
            decimals = digits(n.substring(i + 1))
            sig = digits(n.substring(0, cursor)).length + if (cursor > i) 1 else 0
        } else if (',' in n) {
            val ci = n.lastIndexOf(',')
            val after = n.substring(ci + 1)
            val pasted = n.length - o.length > 1 || o.isEmpty()
            val decimalComma = pasted && oneOrTwoDigits.matches(after) && n.indexOf(',') == ci
            if (decimalComma) {
                whole = digits(n.substring(0, ci))
                decimals = after
                sig = whole.length + 1 + decimals.length
            } else {
                whole = digits(n)
                decimals = null
                sig = digits(n.substring(0, cursor)).length
            }
        } else {
            whole = digits(n)
            decimals = null
            sig = cursor
        }

        if (whole.length > MAX_WHOLE_DIGITS) return old
        whole = whole.replaceFirst(leadingZeros, "")
        if (decimals != null) {
            if (decimals.length > 2) decimals = decimals.substring(0, 2)
            if (whole.isEmpty()) {
                whole = "0"
                sig += 1 // el cero que se antepone queda a la izquierda del cursor
            }
        }

        val text = groupThousands(whole) + if (decimals != null) ".$decimals" else ""

        var pos = 0
        var seen = 0
        while (pos < text.length && seen < sig) {
            if (text[pos] != ',') seen++
            pos++
        }
        return MoneyInputState(text, pos)
    }
}

/**
 * Lee el texto de un campo que usa [MoneyInputFormatter] (siempre en forma canónica: comas de miles
 * y punto decimal). Devuelve `null` si está vacío o no es un monto. Un punto final (`12.`) cuenta
 * como entero.
 */
fun parseInputMinor(text: String): Long? {
    var s = text.trim().replace(",", "")
    if (s.endsWith(".")) s = s.dropLast(1)
    if (s.isEmpty()) return null
    return parseMinor(s)
}
