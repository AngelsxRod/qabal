package com.draskint.qabal.data.local.converter

import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CategoryKind
import com.draskint.qabal.domain.model.ContactType
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.TransactionType
import java.time.Instant
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConvertersTest {

    private val converters = Converters()

    @Test
    fun `la fecha sin hora se guarda como texto ISO y vuelve igual`() {
        val date = LocalDate.of(2026, 3, 9)

        assertEquals("2026-03-09", converters.fromLocalDate(date))
        assertEquals(date, converters.toLocalDate("2026-03-09"))
    }

    @Test
    fun `el orden del texto de fechas coincide con el orden cronologico`() {
        val earlier = converters.fromLocalDate(LocalDate.of(2026, 1, 31))!!
        val later = converters.fromLocalDate(LocalDate.of(2026, 2, 1))!!

        assert(earlier < later)
    }

    @Test
    fun `el instante se guarda como milisegundos y vuelve igual`() {
        val instant = Instant.parse("2026-10-01T12:30:45.123Z")

        assertEquals(1_790_857_845_123L, converters.fromInstant(instant))
        assertEquals(instant, converters.toInstant(1_790_857_845_123L))
    }

    @Test
    fun `los nulos se conservan en todos los convertidores`() {
        assertNull(converters.fromLocalDate(null))
        assertNull(converters.toLocalDate(null))
        assertNull(converters.fromInstant(null))
        assertNull(converters.toInstant(null))
        assertNull(converters.fromAccountType(null))
        assertNull(converters.toAccountType(null))
        assertNull(converters.fromCategoryKind(null))
        assertNull(converters.toCategoryKind(null))
        assertNull(converters.fromTransactionType(null))
        assertNull(converters.toTransactionType(null))
        assertNull(converters.fromContactType(null))
        assertNull(converters.toContactType(null))
        assertNull(converters.fromDebtDirection(null))
        assertNull(converters.toDebtDirection(null))
        assertNull(converters.fromDebtStatus(null))
        assertNull(converters.toDebtStatus(null))
    }

    @Test
    fun `todos los valores de cada enum sobreviven al viaje de ida y vuelta`() {
        AccountType.entries.forEach {
            assertEquals(it, converters.toAccountType(converters.fromAccountType(it)))
        }
        CategoryKind.entries.forEach {
            assertEquals(it, converters.toCategoryKind(converters.fromCategoryKind(it)))
        }
        TransactionType.entries.forEach {
            assertEquals(it, converters.toTransactionType(converters.fromTransactionType(it)))
        }
        ContactType.entries.forEach {
            assertEquals(it, converters.toContactType(converters.fromContactType(it)))
        }
        DebtDirection.entries.forEach {
            assertEquals(it, converters.toDebtDirection(converters.fromDebtDirection(it)))
        }
        DebtStatus.entries.forEach {
            assertEquals(it, converters.toDebtStatus(converters.fromDebtStatus(it)))
        }
    }

    @Test
    fun `los enums se guardan por nombre`() {
        assertEquals("CREDIT_CARD", converters.fromAccountType(AccountType.CREDIT_CARD))
        assertEquals("OWED_TO_ME", converters.fromDebtDirection(DebtDirection.OWED_TO_ME))
    }
}
