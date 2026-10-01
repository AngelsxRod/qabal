package com.draskint.qabal.data.local

import android.database.sqlite.SQLiteConstraintException
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.TransactionType
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test

class IntegrityTriggersTest : DatabaseTestBase() {

    @Before
    fun seedAccounts() = runBlocking {
        db.accountDao().insert(account("a"))
        db.accountDao().insert(account("b", currency = "USD"))
        db.accountDao().insert(account("card", type = AccountType.CREDIT_CARD))
        db.contactDao().insert(contact("c"))
        db.debtDao().insert(debt("d", "c"))
    }

    private fun assertRejected(block: suspend () -> Unit) {
        assertThrows(SQLiteConstraintException::class.java) { runBlocking { block() } }
    }

    @Test
    fun `acepta un gasto valido`() = runBlocking {
        db.transactionDao().insert(tx("t", "a"))
        assertNotNull(db.transactionDao().getById("t"))
    }

    @Test
    fun `rechaza montos no positivos`() {
        assertRejected { db.transactionDao().insert(tx("t", "a", amount = 0)) }
        assertRejected { db.transactionDao().insert(tx("t", "a", amount = -5)) }
    }

    @Test
    fun `la transferencia exige cuenta destino distinta`() {
        assertRejected { db.transactionDao().insert(tx("t", "a", TransactionType.TRANSFER)) }
        assertRejected { db.transactionDao().insert(tx("t", "a", transferAccountId = "b")) }
        assertRejected {
            db.transactionDao().insert(tx("t", "a", TransactionType.TRANSFER, transferAccountId = "a"))
        }
    }

    @Test
    fun `acepta una transferencia con monto destino en otra moneda`() = runBlocking {
        db.transactionDao().insert(
            tx("t", "a", TransactionType.TRANSFER, 7_700, transferAccountId = "b", transferAmount = 1_000),
        )
        assertEquals(1_000L, db.transactionDao().observeIncomingTransfers("b").first())
    }

    @Test
    fun `el monto destino solo aplica a transferencias y debe ser positivo`() {
        assertRejected { db.transactionDao().insert(tx("t", "a", transferAmount = 100)) }
        assertRejected {
            db.transactionDao().insert(
                tx("t", "a", TransactionType.TRANSFER, transferAccountId = "b", transferAmount = 0),
            )
        }
    }

    @Test
    fun `solo una transferencia paga un estado de cuenta`() = runBlocking {
        db.creditCardDao().insertStatement(statement("s"))
        assertRejected { db.transactionDao().insert(tx("t", "a", statementId = "s")) }
        db.transactionDao().insert(
            tx("t2", "a", TransactionType.TRANSFER, transferAccountId = "card", statementId = "s"),
        )
    }

    @Test
    fun `un movimiento de deuda no puede ser transferencia`() = runBlocking {
        assertRejected {
            db.transactionDao().insert(
                tx("t", "a", TransactionType.TRANSFER, transferAccountId = "b", debtId = "d"),
            )
        }
        db.transactionDao().insert(tx("t2", "a", debtId = "d"))
    }

    @Test
    fun `las reglas tambien se aplican al actualizar`() = runBlocking {
        db.transactionDao().insert(tx("t", "a"))
        val original = db.transactionDao().getById("t")!!
        assertRejected { db.transactionDao().update(original.copy(amountMinor = 0)) }
        assertRejected { db.transactionDao().update(original.copy(type = TransactionType.TRANSFER)) }
        assertEquals(1_000L, db.transactionDao().getById("t")!!.amountMinor)
    }

    @Test
    fun `rechaza deudas con principal no positivo`() {
        assertRejected { db.debtDao().insert(debt("d2", "c", principal = 0)) }
    }

    @Test
    fun `valida los datos de la tarjeta`() {
        assertRejected { db.creditCardDao().insertDetails(card(limit = 0)) }
        assertRejected { db.creditCardDao().insertDetails(card(statementDay = 0)) }
        assertRejected { db.creditCardDao().insertDetails(card(dueDay = 32)) }
        assertRejected { db.creditCardDao().insertDetails(card(minPaymentBp = 10_001)) }
        runBlocking { db.creditCardDao().insertDetails(card(minPaymentBp = 500)) }
    }

    @Test
    fun `valida los montos del estado de cuenta`() {
        assertRejected { db.creditCardDao().insertStatement(statement("s", balance = -1, minimum = 0)) }
        assertRejected { db.creditCardDao().insertStatement(statement("s", balance = 100, minimum = 101)) }
    }

    @Test
    fun `no permite dos estados con la misma fecha de corte`() {
        runBlocking { db.creditCardDao().insertStatement(statement("s1")) }
        assertRejected { db.creditCardDao().insertStatement(statement("s2")) }
    }

    private fun card(
        limit: Long = 500_000,
        statementDay: Int = 15,
        dueDay: Int = 5,
        minPaymentBp: Int? = null,
    ) = CreditCardDetailsEntity("card", limit, statementDay, dueDay, minPaymentBp, now, now)

    private fun statement(id: String, balance: Long = 100_000, minimum: Long = 5_000) =
        CreditCardStatementEntity(
            id = id, accountId = "card", periodStart = LocalDate.of(2026, 9, 16),
            closingDate = LocalDate.of(2026, 10, 15), dueDate = LocalDate.of(2026, 11, 5),
            statementBalanceMinor = balance, minimumPaymentMinor = minimum, createdAt = now, updatedAt = now,
        )
}
