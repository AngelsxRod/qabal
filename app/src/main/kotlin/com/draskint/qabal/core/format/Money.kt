package com.draskint.qabal.core.format

/*
 * Formatos y lectura de montos en unidades menores (`Long`). Todas las monedas se tratan con 2
 * decimales.
 */

private val symbols = mapOf(
    "GTQ" to "Q",
    "USD" to "US$",
    "EUR" to "€",
    "MXN" to "MX$",
)

/** Máximo de dígitos enteros aceptados: evita desbordar un `Long` al pasar a unidades menores. */
internal const val MAX_WHOLE_DIGITS = 12

private val thousandsWithDot = Regex("""^\d{1,3}(,\d{3})+(\.\d{1,2})?$""")
private val plainWithDot = Regex("""^\d*(\.\d{1,2})?$""")
private val plainWithComma = Regex("""^\d*(,\d{1,2})?$""")
private val thousandsOnly = Regex("""^\d{1,3}(,\d{3})+$""")
private val onlyDigits = Regex("""^\d+$""")
private val leadingZeros = Regex("""^0+(?=\d)""")
private val whitespace = Regex("""\s""")

/** Símbolo de la moneda; para las desconocidas, el propio código. */
fun currencySymbol(currency: String): String = symbols[currency] ?: currency

internal fun groupThousands(digits: String): String = buildString {
    digits.forEachIndexed { i, c ->
        if (i > 0 && (digits.length - i) % 3 == 0) append(',')
        append(c)
    }
}

private fun split(minor: Long, grouped: Boolean): String {
    val abs = kotlin.math.abs(minor)
    val whole = (abs / 100).toString()
    val cents = (abs % 100).toString().padStart(2, '0')
    return "${if (grouped) groupThousands(whole) else whole}.$cents"
}

/**
 * `123450` con GTQ → `Q1,234.50`; los negativos llevan el signo delante del símbolo (`-Q1,234.50`).
 * Las monedas sin símbolo conocido se separan con un espacio (`CHF 1,234.50`).
 */
fun formatMoney(minor: Long, currency: String): String {
    val symbol = currencySymbol(currency)
    val separator = if (symbol == currency) " " else ""
    return "${if (minor < 0) "-" else ""}$symbol$separator${split(minor, grouped = true)}"
}

/** Igual que [formatMoney] pero forzando el signo (`+Q10.00`); el cero no lleva signo. */
fun formatSignedMoney(minor: Long, currency: String): String =
    if (minor > 0) "+${formatMoney(minor, currency)}" else formatMoney(minor, currency)

/** Número sin símbolo ni miles, con punto decimal: `123450` → `1234.50`. */
fun formatPlain(minor: Long): String = "${if (minor < 0) "-" else ""}${split(minor, grouped = false)}"

/** `123450` → `1,234.50` (agrupado, sin símbolo): valor inicial de un campo de monto al editar. */
fun formatGrouped(minor: Long): String = formatMoney(minor, "").trim()

/**
 * Lee un monto escrito por el usuario y lo devuelve en unidades menores, o `null` si es inválido o
 * ambiguo. Nunca acepta signo (los montos son positivos).
 *
 * - `1234`, `1234.5`, `1234.50` → punto decimal.
 * - `1234,50` → la coma es decimal cuando es el único separador y va seguida de 1 o 2 dígitos.
 * - `1,234.50` y `1,234,567` → la coma separa miles (grupos de 3).
 * - Se rechaza lo ambiguo o mal formado: `1,234` (¿1.234 o 1234?), `1.234` (3 decimales),
 *   `1.234,50`, `1.234.567`, `1,2,3`, `12.`, letras, vacío.
 */
fun parseMinor(input: String): Long? {
    val s = input.trim().replace(whitespace, "")
    if (s.isEmpty() || s == "." || s == ",") return null

    val hasDot = '.' in s
    val hasComma = ',' in s
    val normalized = when {
        hasDot && hasComma -> {
            if (!thousandsWithDot.matches(s)) return null
            s.replace(",", "")
        }
        hasDot -> {
            if (!plainWithDot.matches(s)) return null
            s
        }
        hasComma -> when {
            thousandsOnly.matches(s) -> {
                // `1,234,567` es inequívoco, pero `1,234` no: una sola coma seguida de exactamente
                // 3 dígitos podría ser un decimal mal escrito.
                if (s.split(',').size == 2) return null
                s.replace(",", "")
            }
            plainWithComma.matches(s) -> s.replace(',', '.')
            else -> return null
        }
        else -> {
            if (!onlyDigits.matches(s)) return null
            s
        }
    }

    val parts = normalized.split('.')
    val whole = parts[0].ifEmpty { "0" }
    if (whole.replaceFirst(leadingZeros, "").length > MAX_WHOLE_DIGITS) return null
    val fraction = if (parts.size > 1) parts[1].padEnd(2, '0') else "00"
    return whole.toLong() * 100 + fraction.toLong()
}
