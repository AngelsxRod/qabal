package com.draskint.qabal.domain.card

import com.draskint.qabal.domain.error.InvalidCardScheduleException
import com.draskint.qabal.domain.error.InvalidInputException
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CardCycleTest {

    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)

    @Test
    fun `el pago cae el mes siguiente si el dia de pago no es posterior al corte`() {
        val c = cycleClosingOn(2026, 9, statementDay = 21, dueDay = 15)
        assertEquals(CardCycle(d(2026, 8, 22), d(2026, 9, 21), d(2026, 10, 15)), c)
    }

    @Test
    fun `el pago cae el mismo mes si el dia de pago es posterior al corte`() {
        val c = cycleClosingOn(2026, 9, statementDay = 5, dueDay = 25)
        assertEquals(CardCycle(d(2026, 8, 6), d(2026, 9, 5), d(2026, 9, 25)), c)
    }

    @Test
    fun `los dias largos se recortan al fin de mes y el ciclo cruza el anio`() {
        val feb = cycleClosingOn(2026, 2, statementDay = 31, dueDay = 10)
        assertEquals(d(2026, 2, 28), feb.closingDate)
        assertEquals(d(2026, 2, 1), feb.periodStart)
        val jan = cycleClosingOn(2027, 1, statementDay = 15, dueDay = 5)
        assertEquals(d(2026, 12, 16), jan.periodStart)
        assertEquals(d(2027, 2, 5), jan.dueDate)
    }

    @Test
    fun `una compra el dia de corte todavia entra a ese corte`() {
        assertEquals(d(2026, 9, 15), cycleForPurchase(d(2026, 9, 15), 15, 5).closingDate)
        assertEquals(d(2026, 10, 15), cycleForPurchase(d(2026, 9, 16), 15, 5).closingDate)
        assertEquals(d(2027, 1, 15), cycleForPurchase(d(2026, 12, 20), 15, 5).closingDate)
    }

    @Test
    fun `los dias fuera de 1 a 31 se rechazan`() {
        assertThrows(IllegalArgumentException::class.java) { cycleClosingOn(2026, 1, 0, 5) }
        assertThrows(IllegalArgumentException::class.java) { cycleForPurchase(d(2026, 1, 1), 15, 32) }
    }

    @Test
    fun `validateCardSchedule acepta combinaciones comunes`() {
        validateCardSchedule(15, 5)
        validateCardSchedule(5, 25)
        validateCardSchedule(31, 10)
        validateCardSchedule(28, 28)
    }

    @Test
    fun `validateCardSchedule rechaza las que hacen coincidir corte y pago`() {
        assertThrows(InvalidCardScheduleException::class.java) { validateCardSchedule(30, 31) }
        assertThrows(InvalidInputException::class.java) { validateCardSchedule(0, 5) }
        assertThrows(InvalidInputException::class.java) { validateCardSchedule(15, 32) }
    }
}
