package com.draskint.qabal.data.repository

import com.draskint.qabal.domain.error.InvalidCardScheduleException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotACreditCardException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.AccountInput
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CreditCardSettings
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.TransactionType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AccountRepositoryTest : RepositoryTestBase() {

    private val card = CreditCardSettings(creditLimitMinor = 500_000, statementDay = 15, dueDay = 5, minPaymentBp = 500)

    @Test
    fun `crea una cuenta normalizando nombre y moneda`() = runBlocking<Unit> {
        val a = accounts.create(AccountInput("  Banrural  ", AccountType.BANK, " gtq ", 10_000))
        assertEquals("Banrural", a.name)
        assertEquals("GTQ", a.currency)
        assertEquals(now, a.createdAt)
        assertEquals(a, accounts.get(a.id))
        assertNull(accounts.cardSettings(a.id))
    }

    @Test
    fun `valida nombre y moneda`() {
        assertFails<InvalidInputException> { accounts.create(AccountInput("  ", AccountType.CASH, "GTQ")) }
        assertFails<InvalidInputException> { accounts.create(AccountInput("x".repeat(81), AccountType.CASH, "GTQ")) }
        assertFails<InvalidInputException> { accounts.create(AccountInput("Caja", AccountType.CASH, "QUETZAL")) }
    }

    @Test
    fun `una tarjeta exige sus datos y las demas cuentas los prohiben`() = runBlocking<Unit> {
        assertFails<InvalidInputException> { accounts.create(AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ")) }
        assertFails<InvalidInputException> { accounts.create(AccountInput("Caja", AccountType.CASH, "GTQ"), card) }

        val visa = accounts.create(AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ", -50_000), card)
        assertEquals(card, accounts.cardSettings(visa.id))
    }

    @Test
    fun `rechaza datos de tarjeta invalidos y no deja la cuenta a medias`() = runBlocking<Unit> {
        val bad = AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ")
        assertFails<InvalidInputException> { accounts.create(bad, card.copy(creditLimitMinor = 0)) }
        assertFails<InvalidInputException> { accounts.create(bad, card.copy(minPaymentBp = 10_001)) }
        assertFails<InvalidCardScheduleException> { accounts.create(bad, card.copy(statementDay = 30, dueDay = 31)) }
        assertTrue(accounts.list(includeArchived = true).isEmpty())
    }

    @Test
    fun `update cambia nombre, archivo y saldo inicial sin tocar tipo ni moneda`() = runBlocking<Unit> {
        val a = newAccount("Caja", initial = 100)
        accounts.update(a.id, name = " Caja chica ", isArchived = true, initialBalanceMinor = 250)

        val updated = accounts.get(a.id)!!
        assertEquals("Caja chica", updated.name)
        assertTrue(updated.isArchived)
        assertEquals(250L, updated.initialBalanceMinor)
        assertEquals(a.type, updated.type)
        assertEquals(a.currency, updated.currency)
        assertFails<NotFoundException> { accounts.update("nope", name = "x") }
        assertFails<InvalidInputException> { accounts.update(a.id, name = "") }
    }

    @Test
    fun `list oculta las archivadas salvo que se pida`() = runBlocking<Unit> {
        val a = newAccount("A")
        newAccount("B")
        accounts.update(a.id, isArchived = true)

        assertEquals(listOf("B"), accounts.list().map { it.name })
        assertEquals(listOf("A", "B"), accounts.list(includeArchived = true).map { it.name })
    }

    @Test
    fun `updateCardSettings solo aplica a tarjetas`() = runBlocking<Unit> {
        val visa = accounts.create(AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ"), card)
        accounts.updateCardSettings(visa.id, card.copy(creditLimitMinor = 800_000, dueDay = 10))
        assertEquals(800_000L, accounts.cardSettings(visa.id)!!.creditLimitMinor)

        val caja = newAccount("Caja")
        assertFails<NotACreditCardException> { accounts.updateCardSettings(caja.id, card) }
        assertFails<NotFoundException> { accounts.updateCardSettings("nope", card) }
    }

    @Test
    fun `el saldo suma ingresos, resta gastos y mueve las transferencias`() = runBlocking<Unit> {
        val a = newAccount("A", initial = 10_000)
        val b = newAccount("B", currency = "USD")
        fun tx(type: TransactionType, amount: Long, to: String? = null, toAmount: Long? = null) =
            TransactionInput(a.id, type, amount, now, transferAccountId = to, transferAmountMinor = toAmount)

        transactions.create(tx(TransactionType.INCOME, 50_000))
        transactions.create(tx(TransactionType.EXPENSE, 12_000))
        transactions.create(tx(TransactionType.TRANSFER, 7_700, to = b.id, toAmount = 1_000))

        assertEquals(10_000L + 50_000 - 12_000 - 7_700, accounts.balance(a.id).balanceMinor)
        assertEquals(1_000L, accounts.balance(b.id).balanceMinor)
        assertFails<NotFoundException> { accounts.balance("nope") }
    }

    @Test
    fun `una tarjeta con deuda inicial tiene saldo negativo`() = runBlocking<Unit> {
        val visa = accounts.create(AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ", -50_000), card)
        transactions.create(TransactionInput(visa.id, TransactionType.EXPENSE, 20_000, now))
        assertEquals(-70_000L, accounts.balance(visa.id).balanceMinor)
    }

    @Test
    fun `observeBalances emite todas las cuentas con su saldo`() = runBlocking<Unit> {
        val a = newAccount("A", initial = 500)
        newAccount("B")
        transactions.create(TransactionInput(a.id, TransactionType.INCOME, 100, now))

        val balances = accounts.observeBalances().first().associate { it.account.name to it.balanceMinor }
        assertEquals(mapOf("A" to 600L, "B" to 0L), balances)
        assertNotNull(balances["B"])
        assertFalse(balances.isEmpty())
    }
}
