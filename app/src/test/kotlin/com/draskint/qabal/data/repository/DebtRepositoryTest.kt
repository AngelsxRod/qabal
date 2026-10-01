package com.draskint.qabal.data.repository

import com.draskint.qabal.domain.error.DebtClosedException
import com.draskint.qabal.domain.error.DebtNotFullyPaidException
import com.draskint.qabal.domain.error.InvalidAmountException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.ContactInput
import com.draskint.qabal.domain.model.DebtBalance
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtInput
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.TransactionFilter
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.TransactionType
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class DebtRepositoryTest : RepositoryTestBase() {

    private lateinit var debts: DebtRepository
    private lateinit var contactId: String
    private val start = LocalDate.of(2026, 9, 1)

    @Before
    fun createDebtRepository() {
        debts = DebtRepository(db, transactions, clock, ids)
        contactId = runBlocking { ContactRepository(db, clock, ids).create(ContactInput("Ana")).id }
    }

    private fun input(
        direction: DebtDirection = DebtDirection.OWED_TO_ME,
        principal: Long = 10_000,
        currency: String = "GTQ",
        dueDate: LocalDate? = null,
    ) = DebtInput(contactId, direction, principal, currency, " Préstamo ", start, dueDate)

    private fun payment(accountId: String, debtId: String, type: TransactionType, amount: Long) =
        TransactionInput(accountId, type, amount, now, debtId = debtId)

    @Test
    fun `crea una deuda historica normalizando campos`() = runBlocking<Unit> {
        val d = debts.create(input(currency = "gtq"))
        assertEquals("Préstamo", d.description)
        assertEquals("GTQ", d.currency)
        assertEquals(DebtStatus.OPEN, d.status)
        assertEquals(d, debts.get(d.id))
        assertTrue(transactions.list().isEmpty())
        assertEquals(DebtBalance(d, 0).pendingMinor, debts.balance(d.id).pendingMinor)
    }

    @Test
    fun `valida monto, descripcion, fechas y contacto`() {
        assertFails<InvalidAmountException> { debts.create(input(principal = 0)) }
        assertFails<InvalidInputException> { debts.create(input().copy(description = " ")) }
        assertFails<InvalidInputException> { debts.create(input(currency = "Q")) }
        assertFails<InvalidInputException> { debts.create(input(dueDate = start.minusDays(1))) }
        assertFails<NotFoundException> { debts.create(input().copy(contactId = "nope")) }
    }

    @Test
    fun `con cuenta de origen crea el movimiento inverso al abono`() = runBlocking<Unit> {
        val acc = newAccount()
        val lent = debts.create(input(DebtDirection.OWED_TO_ME, 5_000), originAccountId = acc.id)
        val borrowed = debts.create(input(DebtDirection.I_OWE, 7_000), originAccountId = acc.id)

        val origin = transactions.list(TransactionFilter(debtId = lent.id)).single()
        assertEquals(TransactionType.EXPENSE, origin.type)
        assertEquals(5_000, origin.amountMinor)
        assertNull(origin.categoryId)
        assertEquals(contactId, origin.contactId)
        assertEquals(TransactionType.INCOME, transactions.list(TransactionFilter(debtId = borrowed.id)).single().type)
        // El origen no cuenta como abono.
        assertEquals(0, debts.balance(lent.id).paidMinor)
        assertEquals(2_000L, accounts.balance(acc.id).balanceMinor)
    }

    @Test
    fun `una cuenta de origen invalida no deja la deuda a medias`() = runBlocking<Unit> {
        assertFails<NotFoundException> { debts.create(input(), originAccountId = "nope") }
        assertTrue(debts.list(includeArchived = true).isEmpty())
    }

    @Test
    fun `solo los abonos restan del saldo segun la direccion`() = runBlocking<Unit> {
        val acc = newAccount()
        val owedToMe = debts.create(input(DebtDirection.OWED_TO_ME, 10_000), originAccountId = acc.id)
        transactions.create(payment(acc.id, owedToMe.id, TransactionType.INCOME, 3_000))
        transactions.create(payment(acc.id, owedToMe.id, TransactionType.INCOME, 2_000))
        val b = debts.balance(owedToMe.id)
        assertEquals(5_000, b.paidMinor)
        assertEquals(5_000, b.pendingMinor)
        assertFalse(b.isFullyPaid)

        val iOwe = debts.create(input(DebtDirection.I_OWE, 4_000))
        transactions.create(payment(acc.id, iOwe.id, TransactionType.EXPENSE, 4_000))
        assertTrue(debts.balance(iOwe.id).isFullyPaid)
    }

    @Test
    fun `saldar exige que no quede pendiente y se puede reabrir`() = runBlocking<Unit> {
        val acc = newAccount()
        val d = debts.create(input(DebtDirection.I_OWE, 4_000))
        assertFails<DebtNotFullyPaidException> { debts.settle(d.id) }

        transactions.create(payment(acc.id, d.id, TransactionType.EXPENSE, 4_000))
        debts.settle(d.id)
        assertEquals(DebtStatus.SETTLED, debts.get(d.id)!!.status)
        assertFails<DebtClosedException> { transactions.create(payment(acc.id, d.id, TransactionType.EXPENSE, 1)) }

        debts.reopen(d.id)
        assertEquals(DebtStatus.OPEN, debts.get(d.id)!!.status)
        transactions.create(payment(acc.id, d.id, TransactionType.EXPENSE, 1))
        assertFails<NotFoundException> { debts.settle("nope") }
    }

    @Test
    fun `perdonar cierra la deuda con saldo pendiente`() = runBlocking<Unit> {
        val d = debts.create(input())
        debts.forgive(d.id)
        assertEquals(DebtStatus.FORGIVEN, debts.get(d.id)!!.status)
        assertEquals(10_000, debts.balance(d.id).pendingMinor)
        assertFails<NotFoundException> { debts.forgive("nope") }
    }

    @Test
    fun `actualiza descripcion y vencimiento`() = runBlocking<Unit> {
        val d = debts.create(input(dueDate = start.plusDays(30)))
        debts.update(d.id, description = " Nuevo ")
        assertEquals("Nuevo", debts.get(d.id)!!.description)
        assertEquals(start.plusDays(30), debts.get(d.id)!!.dueDate)

        debts.update(d.id, dueDate = start.plusDays(60))
        assertEquals(start.plusDays(60), debts.get(d.id)!!.dueDate)
        debts.update(d.id, clearDueDate = true)
        assertNull(debts.get(d.id)!!.dueDate)
        assertFails<InvalidInputException> { debts.update(d.id, dueDate = start.minusDays(1)) }
        assertFails<NotFoundException> { debts.update("nope", description = "x") }
    }

    @Test
    fun `filtra el listado y reemite con los abonos`() = runBlocking<Unit> {
        val acc = newAccount()
        val a = debts.create(input(DebtDirection.OWED_TO_ME, 1_000))
        val b = debts.create(input(DebtDirection.I_OWE, 2_000))
        transactions.create(payment(acc.id, b.id, TransactionType.EXPENSE, 500))
        debts.forgive(b.id)

        assertEquals(setOf(a.id, b.id), debts.list().map { it.debt.id }.toSet())
        assertEquals(listOf(a.id), debts.list(direction = DebtDirection.OWED_TO_ME).map { it.debt.id })
        assertEquals(listOf(b.id), debts.list(status = DebtStatus.FORGIVEN).map { it.debt.id })

        debts.setArchived(a.id, true)
        assertEquals(listOf(b.id), debts.list().map { it.debt.id })
        assertEquals(2, debts.list(includeArchived = true).size)

        assertEquals(500, debts.observe().first().single().paidMinor)
        assertFails<NotFoundException> { debts.setArchived("nope", true) }
    }

    @Test
    fun `un abono de mas queda como excedente y no como saldo negativo`() = runBlocking<Unit> {
        val acc = newAccount()
        val d = debts.create(input(DebtDirection.I_OWE, 1_000))
        transactions.create(payment(acc.id, d.id, TransactionType.EXPENSE, 1_500))
        val b = debts.balance(d.id)
        assertEquals(0, b.pendingMinor)
        assertEquals(500, b.excessMinor)
        assertTrue(b.isFullyPaid)
    }
}
