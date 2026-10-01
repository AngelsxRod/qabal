package com.draskint.qabal.core.format

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/* Formatos de fecha en español, sin depender del locale del dispositivo. */

private val months = listOf("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")

private val monthNames = listOf(
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
)

private val weekdays = listOf("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")

/** `2026-09-21` → `21 sep 2026`. */
fun formatDate(d: LocalDate): String = "${d.dayOfMonth} ${months[d.monthValue - 1]} ${d.year}"

/** `2026-10-21` → `21 oct`. */
fun formatDayMonth(d: LocalDate): String = "${d.dayOfMonth} ${months[d.monthValue - 1]}"

/** `2026-09-21` → `Septiembre 2026`. */
fun formatMonth(d: LocalDate): String = "${monthNames[d.monthValue - 1]} ${d.year}"

/** Encabezado de un grupo de movimientos: `Hoy`, `Ayer` o `lunes 21 sep 2026`. */
fun formatDayHeader(d: LocalDate, today: LocalDate): String = when (ChronoUnit.DAYS.between(d, today)) {
    0L -> "Hoy"
    1L -> "Ayer"
    else -> "${weekdays[d.dayOfWeek.value - 1]} ${formatDate(d)}"
}
