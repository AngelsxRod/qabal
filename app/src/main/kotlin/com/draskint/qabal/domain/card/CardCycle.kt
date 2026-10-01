package com.draskint.qabal.domain.card

import java.time.LocalDate
import java.time.YearMonth

/**
 * Ciclo de facturación de una tarjeta. `closingDate` y `periodStart` son inclusivas.
 */
data class CardCycle(val periodStart: LocalDate, val closingDate: LocalDate, val dueDate: LocalDate)

/**
 * Ciclo al que pertenece una compra hecha en [purchaseDate] (fecha local). Una compra el día de
 * corte todavía entra a ese corte.
 */
fun cycleForPurchase(purchaseDate: LocalDate, statementDay: Int, dueDay: Int): CardCycle {
    checkDay(statementDay, "statementDay")
    checkDay(dueDay, "dueDay")
    val closingThisMonth = dayIn(purchaseDate.year, purchaseDate.monthValue, statementDay)
    val month = if (purchaseDate.isAfter(closingThisMonth)) purchaseDate.monthValue + 1 else purchaseDate.monthValue
    val target = YearMonth.of(purchaseDate.year, 1).plusMonths((month - 1).toLong())
    return cycleClosingOn(target.year, target.monthValue, statementDay, dueDay)
}

/**
 * Ciclo cuyo corte cae en el mes [month] del año [year].
 *
 * La fecha de pago es la primera ocurrencia de [dueDay] posterior al corte: mes siguiente si
 * `dueDay <= statementDay` (corte 21, pago 15) y el mismo mes si `dueDay > statementDay` (corte 5,
 * pago 25).
 */
fun cycleClosingOn(year: Int, month: Int, statementDay: Int, dueDay: Int): CardCycle {
    checkDay(statementDay, "statementDay")
    checkDay(dueDay, "dueDay")
    val closing = dayIn(year, month, statementDay)
    val previousClosing = dayIn(year, month - 1, statementDay)
    val dueMonth = if (dueDay > statementDay) month else month + 1
    return CardCycle(
        periodStart = previousClosing.plusDays(1),
        closingDate = closing,
        dueDate = dayIn(year, dueMonth, dueDay),
    )
}

/**
 * Día [day] del mes indicado (el mes puede desbordar: 0 = diciembre del año anterior, 13 = enero
 * del siguiente). Si el mes es más corto, el último día.
 */
private fun dayIn(year: Int, month: Int, day: Int): LocalDate {
    val ym = YearMonth.of(year, 1).plusMonths((month - 1).toLong())
    return ym.atDay(minOf(day, ym.lengthOfMonth()))
}

private fun checkDay(day: Int, name: String) =
    require(day in 1..31) { "$name debe estar entre 1 y 31 (recibido $day)" }
