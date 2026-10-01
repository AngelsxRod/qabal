package com.draskint.qabal.domain.card

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class StatementStatusTest {

    private val due = LocalDate.of(2026, 11, 5)

    private fun status(paid: Long, today: LocalDate = due.minusDays(10), balance: Long = 10_000, minimum: Long = 1_000) =
        statementStatus(balance, minimum, paid, due, today)

    @Test
    fun `pagado el saldo completo es PAID aunque haya vencido`() {
        assertEquals(StatementStatus.PAID, status(10_000))
        assertEquals(StatementStatus.PAID, status(12_000, today = due.plusDays(30)))
    }

    @Test
    fun `un estado de cuenta en cero ya esta pagado`() {
        assertEquals(StatementStatus.PAID, status(0, balance = 0, minimum = 0))
    }

    @Test
    fun `cubrir el minimo antes o despues del vencimiento es MINIMUM_COVERED`() {
        assertEquals(StatementStatus.MINIMUM_COVERED, status(1_000))
        assertEquals(StatementStatus.MINIMUM_COVERED, status(5_000, today = due.plusDays(1)))
    }

    @Test
    fun `sin cubrir el minimo es PENDING hasta el dia de pago inclusive y luego OVERDUE`() {
        assertEquals(StatementStatus.PENDING, status(999))
        assertEquals(StatementStatus.PENDING, status(0, today = due))
        assertEquals(StatementStatus.OVERDUE, status(999, today = due.plusDays(1)))
    }
}
