package com.draskint.qabal.core.format

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class DatesTest {

    @Test
    fun `formatDate usa mes abreviado en espanol`() {
        assertEquals("21 sep 2026", formatDate(LocalDate.of(2026, 9, 21)))
        assertEquals("5 ene 2026", formatDate(LocalDate.of(2026, 1, 5)))
        assertEquals("31 dic 2025", formatDate(LocalDate.of(2025, 12, 31)))
    }

    @Test
    fun `formatDayMonth omite el anio`() {
        assertEquals("21 oct", formatDayMonth(LocalDate.of(2026, 10, 21)))
    }

    @Test
    fun `formatDayHeader distingue hoy y ayer`() {
        val today = LocalDate.of(2026, 9, 24)
        assertEquals("Hoy", formatDayHeader(today, today))
        assertEquals("Ayer", formatDayHeader(LocalDate.of(2026, 9, 23), today))
    }

    @Test
    fun `otros dias llevan dia de la semana`() {
        val today = LocalDate.of(2026, 9, 24)
        assertEquals("lunes 21 sep 2026", formatDayHeader(LocalDate.of(2026, 9, 21), today))
        assertEquals("domingo 27 sep 2026", formatDayHeader(LocalDate.of(2026, 9, 27), today))
    }

    @Test
    fun `ayer cruza el cambio de mes y de anio`() {
        assertEquals("Ayer", formatDayHeader(LocalDate.of(2026, 8, 31), LocalDate.of(2026, 9, 1)))
        assertEquals("Ayer", formatDayHeader(LocalDate.of(2025, 12, 31), LocalDate.of(2026, 1, 1)))
    }

    @Test
    fun `formatMonth escribe el mes completo con el anio`() {
        assertEquals("Septiembre 2026", formatMonth(LocalDate.of(2026, 9, 24)))
        assertEquals("Enero 2027", formatMonth(LocalDate.of(2027, 1, 1)))
    }
}
