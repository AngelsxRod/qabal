package com.draskint.qabal.domain.card

import com.draskint.qabal.domain.error.InvalidCardScheduleException
import com.draskint.qabal.domain.error.InvalidInputException

/**
 * Valida la combinación de día de corte y día de pago de una tarjeta.
 *
 * Se rechaza si en algún mes (de un año bisiesto y uno no bisiesto) la fecha de pago no queda
 * estrictamente después del corte. En la práctica ocurre con `dueDay > statementDay` y
 * `statementDay >= 28` (ej. corte 30, pago 31 en febrero).
 */
fun validateCardSchedule(statementDay: Int, dueDay: Int) {
    listOf("statementDay" to statementDay, "dueDay" to dueDay).forEach { (name, day) ->
        if (day !in 1..31) throw InvalidInputException("$name debe estar entre 1 y 31 (recibido $day)")
    }
    for (year in listOf(2024, 2025)) {
        for (month in 1..12) {
            val c = cycleClosingOn(year, month, statementDay, dueDay)
            if (!c.dueDate.isAfter(c.closingDate)) {
                throw InvalidCardScheduleException(
                    "Con corte $statementDay y pago $dueDay, en $year-$month el pago " +
                        "(${c.dueDate.dayOfMonth}) cae el mismo día del corte o antes",
                )
            }
        }
    }
}
