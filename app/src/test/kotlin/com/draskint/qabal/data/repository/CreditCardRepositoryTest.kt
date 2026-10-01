package com.draskint.qabal.data.repository

import com.draskint.qabal.data.local.seed.INTEREST_FEES_CATEGORY_ID
import com.draskint.qabal.data.local.seed.REFUNDS_CATEGORY_ID
import com.draskint.qabal.domain.card.StatementStatus
import com.draskint.qabal.domain.error.DuplicateStatementException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotACreditCardException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.error.StatementOverlapException
import com.draskint.qabal.domain.model.Account
import com.draskint.qabal.domain.model.AccountInput
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CreditCardSettings
import com.draskint.qabal.domain.model.StatementInput
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.TransactionType
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Hoy es 2026-10-01; la tarjeta corta el 15 y paga el 5, así que el ciclo vigente es 16-sep → 15-oct. */
class CreditCardRepositoryTest : RepositoryTestBase() {

    private lateinit var cards: CreditCardRepository
    private lateinit var visa: Account
    private lateinit var bank: Account

    private val settings = CreditCardSettings(creditLimitMinor = 500_000, statementDay = 15, dueDay = 5, minPaymentBp = 333)

    @Before
    fun createCardRepository() = runBlocking {
        cards = CreditCardRepository(db, ledger, clock, ids)
        visa = accounts.create(AccountInput("Visa", AccountType.CREDIT_CARD, "GTQ", -50_000), settings)
        bank = newAccount("Banco")
    }

    private fun at(date: String): Instant = LocalDate.parse(date).atTime(10, 0).toInstant(ZoneOffset.UTC)

    private suspend fun expense(date: String, amount: Long, category: String? = null) = transactions.create(
        TransactionInput(visa.id, TransactionType.EXPENSE, amount, at(date), categoryId = category),
    )

    private suspend fun payment(date: String, amount: Long, statementId: String? = null) = transactions.create(
        TransactionInput(bank.id, TransactionType.TRANSFER, amount, at(date), transferAccountId = visa.id, statementId = statementId),
    )

    private suspend fun statement(closing: String, balance: Long, minimum: Long = balance / 10) =
        cards.registerStatement(StatementInput(visa.id, LocalDate.parse(closing), balance, minimum))

    // --- Resumen del ciclo ---

    @Test
    fun `desglosa el ciclo vigente y estima el minimo`() = runBlocking<Unit> {
        expense("2026-08-20", 5_000) // antes del ciclo: se arrastra
        expense("2026-09-20", 10_000)
        expense("2026-09-25", 300, INTEREST_FEES_CATEGORY_ID)
        transactions.create(TransactionInput(visa.id, TransactionType.INCOME, 1_000, at("2026-09-26"), categoryId = REFUNDS_CATEGORY_ID))
        transactions.create(TransactionInput(visa.id, TransactionType.TRANSFER, 2_000, at("2026-09-28"), transferAccountId = bank.id))
        payment("2026-10-01", 4_000)
        expense("2026-10-16", 9_999) // ya es del ciclo siguiente

        val summary = cards.cycleSummary(visa.id)
        assertEquals(LocalDate.of(2026, 9, 16), summary.cycle.periodStart)
        assertEquals(LocalDate.of(2026, 10, 15), summary.cycle.closingDate)
        assertEquals(LocalDate.of(2026, 11, 5), summary.cycle.dueDate)
        with(summary.movements) {
            assertEquals(55_000, openingDebtMinor)
            assertEquals(10_000, purchasesMinor)
            assertEquals(300, interestMinor)
            assertEquals(2_000, cashAdvancesMinor)
            assertEquals(1_000, refundsMinor)
            assertEquals(0, otherCreditsMinor)
            assertEquals(4_000, paymentsMinor)
        }
        assertEquals(62_300, summary.estimatedClosingMinor)
        assertEquals(2_075L, summary.estimatedMinimumMinor) // ceil(62 300 × 3,33 %)
        assertNull(summary.previousStatementPendingMinor)
    }

    @Test
    fun `una compra el dia de corte entra al ciclo y sin deuda no hay minimo estimado`() = runBlocking<Unit> {
        accounts.update(visa.id, initialBalanceMinor = 0)
        assertNull(cards.cycleSummary(visa.id).estimatedMinimumMinor)
        expense("2026-10-15", 700)
        assertEquals(700, cards.cycleSummary(visa.id).movements.purchasesMinor)
        assertEquals(0, cards.cycleSummary(visa.id, forDate = LocalDate.of(2026, 10, 16)).movements.purchasesMinor)
    }

    @Test
    fun `el resumen incluye saldo, deuda y credito disponible`() = runBlocking<Unit> {
        expense("2026-09-20", 10_000)
        val o = cards.overview(visa.id)
        assertEquals(-60_000, o.balanceMinor)
        assertEquals(60_000, o.owedMinor)
        assertEquals(440_000, o.availableCreditMinor)
        assertEquals(settings, o.settings)
        assertEquals(o, cards.observeOverview(visa.id).first())
    }

    @Test
    fun `rechaza cuentas que no son tarjeta`() {
        assertFails<NotACreditCardException> { cards.overview(bank.id) }
        assertFails<NotFoundException> { cards.overview("nope") }
    }

    // --- Estados de cuenta ---

    @Test
    fun `registra un estado de cuenta derivando periodo y fecha de pago`() = runBlocking<Unit> {
        val s = statement("2026-09-15", 50_000)
        assertEquals(LocalDate.of(2026, 8, 16), s.periodStart)
        assertEquals(LocalDate.of(2026, 10, 5), s.dueDate)
        assertEquals(5_000, s.minimumPaymentMinor)
    }

    @Test
    fun `valida montos, fechas, duplicados y solapes`() = runBlocking<Unit> {
        statement("2026-09-15", 50_000)
        fun input(closing: String, balance: Long = 1_000, minimum: Long = 100, start: String? = null, due: String? = null) =
            StatementInput(visa.id, LocalDate.parse(closing), balance, minimum, start?.let(LocalDate::parse), due?.let(LocalDate::parse))

        assertFails<InvalidInputException> { cards.registerStatement(input("2026-10-15", balance = -1)) }
        assertFails<InvalidInputException> { cards.registerStatement(input("2026-10-15", minimum = 2_000)) }
        assertFails<InvalidInputException> { cards.registerStatement(input("2026-10-15", start = "2026-10-20")) }
        assertFails<InvalidInputException> { cards.registerStatement(input("2026-10-15", due = "2026-10-15")) }
        assertFails<DuplicateStatementException> { cards.registerStatement(input("2026-09-15")) }
        assertFails<StatementOverlapException> { cards.registerStatement(input("2026-10-15", start = "2026-09-10")) }

        // Archivar libera el periodo.
        cards.setStatementArchived(statements().single().statement.id, true)
        assertFails<DuplicateStatementException> { cards.registerStatement(input("2026-09-15")) }
        cards.registerStatement(input("2026-10-15", start = "2026-09-10"))
    }

    private suspend fun statements(includeArchived: Boolean = false) = cards.statements(visa.id, includeArchived)

    @Test
    fun `actualiza un estado de cuenta validando los montos`() = runBlocking<Unit> {
        val s = statement("2026-09-15", 50_000)
        cards.updateStatement(s.id, balanceMinor = 40_000, minimumMinor = 2_000, note = "ajustado")
        val updated = cards.statementView(s.id).statement
        assertEquals(40_000, updated.statementBalanceMinor)
        assertEquals(2_000, updated.minimumPaymentMinor)
        assertEquals("ajustado", updated.note)
        assertFails<InvalidInputException> { cards.updateStatement(s.id, minimumMinor = 50_000) }
        assertFails<InvalidInputException> { cards.updateStatement(s.id, dueDate = s.closingDate) }
        assertFails<NotFoundException> { cards.updateStatement("nope", balanceMinor = 1) }
    }

    @Test
    fun `el estado de cuenta compara lo oficial contra lo estimado`() = runBlocking<Unit> {
        expense("2026-09-10", 10_000)
        val s = statement("2026-09-15", 70_000)
        val view = cards.statementView(s.id)
        assertEquals(60_000, view.estimatedBalanceMinor)
        assertEquals(10_000, view.differenceMinor)
        assertEquals(50_000, view.movements.openingDebtMinor)
        assertEquals(10_000, view.movements.purchasesMinor)
        assertEquals(60_000, cards.estimatedBalanceAt(visa.id, LocalDate.of(2026, 9, 15)))
    }

    @Test
    fun `el estado depende de los pagos vinculados`() = runBlocking<Unit> {
        val s = statement("2026-09-15", 10_000, 1_000)
        assertEquals(StatementStatus.PENDING, cards.statementView(s.id).status)
        payment("2026-09-20", 1_000, s.id)
        assertEquals(StatementStatus.MINIMUM_COVERED, cards.statementView(s.id).status)
        payment("2026-09-21", 9_000, s.id)
        val paid = cards.statementView(s.id)
        assertEquals(StatementStatus.PAID, paid.status)
        assertEquals(10_000, paid.paidMinor)
    }

    @Test
    fun `lista los estados del mas reciente al mas antiguo y oculta los archivados`() = runBlocking<Unit> {
        val old = statement("2026-08-15", 1_000)
        statement("2026-09-15", 2_000)
        assertEquals(listOf(LocalDate.of(2026, 9, 15), LocalDate.of(2026, 8, 15)), statements().map { it.statement.closingDate })
        cards.setStatementArchived(old.id, true)
        assertEquals(1, statements().size)
        assertEquals(2, statements(includeArchived = true).size)
        assertEquals(1, cards.observeStatements(visa.id).first().size)
    }

    @Test
    fun `el resumen del ciclo muestra lo pendiente del estado anterior`() = runBlocking<Unit> {
        val s = statement("2026-09-15", 10_000)
        assertEquals(null, cards.cycleSummary(visa.id, forDate = LocalDate.of(2026, 9, 1)).previousStatementPendingMinor)
        assertEquals(10_000L, cards.cycleSummary(visa.id).previousStatementPendingMinor)
        payment("2026-09-20", 12_000, s.id)
        assertEquals(0L, cards.cycleSummary(visa.id).previousStatementPendingMinor)
    }

    // --- Pendientes y sugerencia ---

    @Test
    fun `los pendientes excluyen pagados, archivados y tarjetas archivadas`() = runBlocking<Unit> {
        val paid = statement("2026-07-15", 1_000)
        payment("2026-07-20", 1_000, paid.id)
        val archived = statement("2026-08-15", 2_000)
        cards.setStatementArchived(archived.id, true)
        val open = statement("2026-09-15", 3_000)

        val pending = cards.pendingStatements()
        assertEquals(listOf(open.id), pending.map { it.statement.id })
        assertEquals(visa.id, pending.single().card.id)
        assertEquals(3_000, pending.single().pendingMinor)
        assertEquals(StatementStatus.PENDING, pending.single().status)
        assertEquals(1, cards.observePendingStatements().first().size)

        accounts.update(visa.id, isArchived = true)
        assertTrue(cards.pendingStatements().isEmpty())
    }

    @Test
    fun `sugiere el estado no pagado con fecha de pago mas antigua`() = runBlocking<Unit> {
        assertNull(cards.suggestStatementForPayment(visa.id))
        val first = statement("2026-08-15", 1_000, 100)
        val second = statement("2026-09-15", 2_000, 200)
        assertEquals(first.id, cards.suggestStatementForPayment(visa.id))

        payment("2026-08-20", 100, first.id) // mínimo cubierto: sigue sin estar pagado
        assertEquals(first.id, cards.suggestStatementForPayment(visa.id))
        payment("2026-08-21", 900, first.id)
        assertEquals(second.id, cards.suggestStatementForPayment(visa.id))
        assertFails<NotACreditCardException> { cards.suggestStatementForPayment(bank.id) }
    }
}
