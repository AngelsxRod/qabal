package com.draskint.qabal.data.repository

import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.domain.error.ArchivedAccountException
import com.draskint.qabal.domain.error.CategoryKindMismatchException
import com.draskint.qabal.domain.error.CurrencyMismatchException
import com.draskint.qabal.domain.error.DebtClosedException
import com.draskint.qabal.domain.error.DebtMovementCategoryException
import com.draskint.qabal.domain.error.InvalidAmountException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.InvalidStatementLinkException
import com.draskint.qabal.domain.error.InvalidTransferException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.AccountInput
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CategoryKind
import com.draskint.qabal.domain.model.CreditCardSettings
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.TransactionFilter
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.TransactionType
import java.time.Duration
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TransactionRepositoryTest : RepositoryTestBase() {

    private fun input(
        accountId: String,
        type: TransactionType = TransactionType.EXPENSE,
        amount: Long = 1_000,
        at: java.time.Instant = now,
        categoryId: String? = null,
        transferTo: String? = null,
        transferAmount: Long? = null,
        debtId: String? = null,
        statementId: String? = null,
        contactId: String? = null,
    ) = TransactionInput(
        accountId, type, amount, at, categoryId = categoryId, transferAccountId = transferTo,
        transferAmountMinor = transferAmount, debtId = debtId, statementId = statementId, contactId = contactId,
    )

    private fun tag(id: String) = runBlocking {
        db.tagDao().insert(TagEntity(id, "tag-$id", createdAt = now, updatedAt = now))
    }

    @Test
    fun `crea y lee un movimiento`() = runBlocking<Unit> {
        val a = newAccount()
        val t = transactions.create(input(a.id, categoryId = "default:food").copy(note = "Almuerzo"))
        assertEquals(t, transactions.get(t.id))
        assertEquals("Almuerzo", t.note)
        assertEquals(now, t.createdAt)
    }

    @Test
    fun `rechaza montos no positivos y cuentas inexistentes`() = runBlocking<Unit> {
        val a = newAccount()
        assertFails<InvalidAmountException> { transactions.create(input(a.id, amount = 0)) }
        assertFails<InvalidAmountException> { transactions.create(input(a.id, amount = -1)) }
        assertFails<NotFoundException> { transactions.create(input("nope")) }
    }

    @Test
    fun `valida las transferencias`() = runBlocking<Unit> {
        val a = newAccount("A")
        val b = newAccount("B")
        val usd = newAccount("USD", currency = "USD")
        val t = TransactionType.TRANSFER

        assertFails<InvalidTransferException> { transactions.create(input(a.id, t)) }
        assertFails<InvalidTransferException> { transactions.create(input(a.id, t, transferTo = a.id)) }
        assertFails<InvalidTransferException> { transactions.create(input(a.id, transferTo = b.id)) }
        assertFails<InvalidTransferException> { transactions.create(input(a.id, transferAmount = 5)) }
        // Misma moneda: no lleva monto destino. Distinta moneda: lo exige.
        assertFails<InvalidTransferException> { transactions.create(input(a.id, t, transferTo = b.id, transferAmount = 5)) }
        assertFails<InvalidTransferException> { transactions.create(input(a.id, t, transferTo = usd.id)) }
        assertFails<InvalidTransferException> { transactions.create(input(a.id, t, transferTo = usd.id, transferAmount = 0)) }
        assertFails<NotFoundException> { transactions.create(input(a.id, t, transferTo = "nope")) }

        transactions.create(input(a.id, t, transferTo = b.id))
        transactions.create(input(a.id, t, transferTo = usd.id, transferAmount = 130))
    }

    @Test
    fun `no acepta movimientos nuevos en cuentas archivadas pero si editar los existentes`() = runBlocking<Unit> {
        val a = newAccount("A")
        val b = newAccount("B")
        val t = transactions.create(input(a.id))
        accounts.update(a.id, isArchived = true)

        assertFails<ArchivedAccountException> { transactions.create(input(a.id)) }
        assertFails<ArchivedAccountException> {
            transactions.create(input(b.id, TransactionType.TRANSFER, transferTo = a.id))
        }
        transactions.update(t.id, input(a.id, amount = 2_500)) // conserva su cuenta
        assertEquals(2_500L, transactions.get(t.id)!!.amountMinor)
        accounts.update(b.id, isArchived = true)
        assertFails<ArchivedAccountException> { transactions.update(t.id, input(b.id)) }
    }

    @Test
    fun `la categoria debe existir y coincidir con el tipo`() = runBlocking<Unit> {
        val a = newAccount()
        assertFails<NotFoundException> { transactions.create(input(a.id, categoryId = "nope")) }
        assertFails<CategoryKindMismatchException> { transactions.create(input(a.id, categoryId = "default:salary")) }
        assertFails<CategoryKindMismatchException> {
            transactions.create(input(a.id, TransactionType.INCOME, categoryId = "default:food"))
        }
        transactions.create(input(a.id, TransactionType.INCOME, categoryId = "default:salary"))
    }

    @Test
    fun `una transferencia no lleva categoria`() = runBlocking<Unit> {
        val a = newAccount("A")
        val b = newAccount("B")
        assertFails<InvalidTransferException> {
            transactions.create(input(a.id, TransactionType.TRANSFER, transferTo = b.id, categoryId = "default:food"))
        }
    }

    @Test
    fun `solo una transferencia a la tarjeta del estado puede vincular el estado`() = runBlocking<Unit> {
        val a = newAccount("A")
        val visa = account("visa", type = AccountType.CREDIT_CARD)
        db.accountDao().insert(visa)
        val other = newAccount("Otra")
        db.creditCardDao().insertDetails(
            com.draskint.qabal.data.local.entity.CreditCardDetailsEntity(visa.id, 500_000, 15, 5, null, now, now),
        )
        db.creditCardDao().insertStatement(
            CreditCardStatementEntity(
                "s1", visa.id, LocalDate.of(2026, 9, 16), LocalDate.of(2026, 10, 15), LocalDate.of(2026, 11, 5),
                100_000, 5_000, null, false, now, now,
            ),
        )
        val t = TransactionType.TRANSFER

        assertFails<InvalidStatementLinkException> { transactions.create(input(a.id, statementId = "s1")) }
        assertFails<NotFoundException> { transactions.create(input(a.id, t, transferTo = visa.id, statementId = "nope")) }
        assertFails<InvalidStatementLinkException> { transactions.create(input(a.id, t, transferTo = other.id, statementId = "s1")) }
        val payment = transactions.create(input(a.id, t, 5_000, transferTo = visa.id, statementId = "s1"))
        assertEquals("s1", payment.statementId)
    }

    @Test
    fun `los movimientos de deuda validan moneda, categoria y estado`() = runBlocking<Unit> {
        val gtq = newAccount("GTQ")
        val usd = newAccount("USD", currency = "USD")
        db.contactDao().insert(contact("c"))
        db.debtDao().insert(debt("d", "c")) // I_OWE en GTQ: el abono es un gasto

        assertFails<CurrencyMismatchException> { transactions.create(input(usd.id, debtId = "d")) }
        assertFails<DebtMovementCategoryException> { transactions.create(input(gtq.id, debtId = "d", categoryId = "default:food")) }
        assertFails<NotFoundException> { transactions.create(input(gtq.id, debtId = "nope")) }

        val abono = transactions.create(input(gtq.id, debtId = "d"))
        db.debtDao().setStatus("d", DebtStatus.SETTLED, now.toEpochMilli())
        assertFails<DebtClosedException> { transactions.create(input(gtq.id, debtId = "d")) }
        // El tipo contrario (el origen) sí se acepta, y editar un abono ya existente también.
        transactions.create(input(gtq.id, TransactionType.INCOME, debtId = "d"))
        transactions.update(abono.id, input(gtq.id, amount = 2_000, debtId = "d"))
    }

    @Test
    fun `el contacto debe existir`() = runBlocking<Unit> {
        val a = newAccount()
        assertFails<NotFoundException> { transactions.create(input(a.id, contactId = "nope")) }
        db.contactDao().insert(contact("c"))
        assertEquals("c", transactions.create(input(a.id, contactId = "c")).contactId)
    }

    @Test
    fun `un fallo de validacion no deja nada guardado`() = runBlocking<Unit> {
        val a = newAccount()
        tag("t1")
        assertFails<NotFoundException> { transactions.create(input(a.id), tagIds = setOf("t1", "nope")) }
        assertTrue(transactions.list().isEmpty())
    }

    @Test
    fun `update reemplaza campos y respeta createdAt`() = runBlocking<Unit> {
        val a = newAccount()
        val t = transactions.create(input(a.id))
        transactions.update(t.id, input(a.id, TransactionType.INCOME, 9_999, categoryId = "default:salary"))

        val u = transactions.get(t.id)!!
        assertEquals(TransactionType.INCOME, u.type)
        assertEquals(9_999L, u.amountMinor)
        assertEquals(t.createdAt, u.createdAt)
        assertFails<NotFoundException> { transactions.update("nope", input(a.id)) }
        assertFails<InvalidAmountException> { transactions.update(t.id, input(a.id, amount = 0)) }
    }

    @Test
    fun `las etiquetas se reemplazan, se conservan con null y se validan`() = runBlocking<Unit> {
        val a = newAccount()
        listOf("x", "y", "z").forEach(::tag)
        val t = transactions.create(input(a.id), tagIds = setOf("x", "y"))
        fun tagsOf() = runBlocking { transactions.list(TransactionFilter(tagId = "x")).map { it.id } }

        assertEquals(listOf(t.id), tagsOf())
        transactions.update(t.id, input(a.id, amount = 5)) // null = no tocar
        assertEquals(listOf(t.id), tagsOf())
        transactions.setTags(t.id, setOf("z"))
        assertTrue(tagsOf().isEmpty())
        assertEquals(listOf(t.id), transactions.list(TransactionFilter(tagId = "z")).map { it.id })
        assertFails<NotFoundException> { transactions.setTags(t.id, setOf("nope")) }
        assertFails<NotFoundException> { transactions.setTags("nope", setOf("x")) }
    }

    @Test
    fun `delete borra el movimiento`() = runBlocking<Unit> {
        val a = newAccount()
        val t = transactions.create(input(a.id))
        transactions.delete(t.id)
        assertNull(transactions.get(t.id))
        assertFails<NotFoundException> { transactions.delete(t.id) }
    }

    @Test
    fun `list filtra, ordena y pagina`() = runBlocking<Unit> {
        val a = newAccount("A")
        val b = newAccount("B")
        val day = Duration.ofDays(1)
        val old = transactions.create(input(a.id, at = now - day.multipliedBy(2), categoryId = "default:food"))
        val mid = transactions.create(input(a.id, TransactionType.INCOME, at = now - day, categoryId = "default:salary"))
        val incoming = transactions.create(input(b.id, TransactionType.TRANSFER, at = now, transferTo = a.id))
        val other = transactions.create(input(b.id, at = now - day))

        fun ids(f: TransactionFilter) = runBlocking { transactions.list(f).map { it.id } }

        assertEquals(listOf(incoming.id, other.id, mid.id, old.id), ids(TransactionFilter()))
        assertEquals(listOf(incoming.id, mid.id, old.id), ids(TransactionFilter(accountId = a.id)))
        assertEquals(listOf(old.id), ids(TransactionFilter(categoryId = "default:food")))
        assertEquals(listOf(mid.id), ids(TransactionFilter(type = TransactionType.INCOME)))
        assertEquals(listOf(other.id, mid.id), ids(TransactionFilter(from = now - day, to = now)))
        assertEquals(listOf(incoming.id, other.id), ids(TransactionFilter(limit = 2)))
        assertEquals(listOf(mid.id, old.id), ids(TransactionFilter(limit = 2, offset = 2)))
        assertEquals(listOf(mid.id, old.id), ids(TransactionFilter(offset = 2)))
    }

    @Test
    fun `en un empate de fecha el ultimo insertado va arriba`() = runBlocking<Unit> {
        val a = newAccount()
        val first = transactions.create(input(a.id))
        val second = transactions.create(input(a.id))
        assertEquals(listOf(second.id, first.id), transactions.list().map { it.id })
    }

    @Test
    fun `observe reemite al cambiar los movimientos`() = runBlocking<Unit> {
        val a = newAccount()
        assertTrue(transactions.observe().first().isEmpty())
        transactions.create(input(a.id))
        assertEquals(1, transactions.observe(TransactionFilter(accountId = a.id)).first().size)
    }

    @Test
    fun `validate no deja pasar un tipo de deuda invalido por transferencia`() = runBlocking<Unit> {
        val a = newAccount("A")
        val b = newAccount("B")
        db.contactDao().insert(contact("c"))
        db.debtDao().insert(debt("d", "c"))
        assertFails<InvalidInputException> {
            transactions.create(input(a.id, TransactionType.TRANSFER, transferTo = b.id, debtId = "d"))
        }
    }

    // --- Asignación automática de estado de cuenta ---

    private fun card(name: String = "Visa") = runBlocking {
        accounts.create(
            AccountInput(name, AccountType.CREDIT_CARD, "GTQ"),
            CreditCardSettings(creditLimitMinor = 500_000, statementDay = 15, dueDay = 5),
        )
    }

    private fun statement(id: String, cardId: String, closing: String, balance: Long = 10_000) = runBlocking {
        val closingDate = LocalDate.parse(closing)
        db.creditCardDao().insertStatement(
            CreditCardStatementEntity(
                id, cardId, closingDate.minusMonths(1).plusDays(1), closingDate, closingDate.plusDays(21),
                balance, 1_000, createdAt = now, updatedAt = now,
            ),
        )
    }

    @Test
    fun `un pago a la tarjeta se vincula al estado pendiente mas antiguo`() = runBlocking<Unit> {
        val bank = newAccount()
        val visa = card()
        statement("s1", visa.id, "2026-08-15")
        statement("s2", visa.id, "2026-09-15")

        val first = transactions.create(input(bank.id, TransactionType.TRANSFER, 10_000, transferTo = visa.id))
        assertEquals("s1", first.statementId)
        // s1 quedó pagado por completo: el siguiente pago va al s2.
        assertEquals("s2", transactions.create(input(bank.id, TransactionType.TRANSFER, 500, transferTo = visa.id)).statementId)
    }

    @Test
    fun `no asigna estado si se pide lo contrario, ya viene indicado o no aplica`() = runBlocking<Unit> {
        val bank = newAccount()
        val other = newAccount("Otra")
        val visa = card()
        statement("s1", visa.id, "2026-08-15")
        statement("s2", visa.id, "2026-09-15")

        val manual = input(bank.id, TransactionType.TRANSFER, 500, transferTo = visa.id)
        assertNull(transactions.create(manual, autoAssignStatement = false).statementId)
        assertEquals("s2", transactions.create(manual.copy(statementId = "s2")).statementId)
        assertNull(transactions.create(input(bank.id, TransactionType.TRANSFER, 500, transferTo = other.id)).statementId)
        assertNull(transactions.create(input(bank.id, TransactionType.EXPENSE, 500)).statementId)
        // Sin estados de cuenta registrados no hay nada que asignar.
        assertNull(transactions.create(input(bank.id, TransactionType.TRANSFER, 500, transferTo = card("Mastercard").id)).statementId)
    }

    @Test
    fun `editar un movimiento no le asigna estado de cuenta`() = runBlocking<Unit> {
        val bank = newAccount()
        val visa = card()
        val payment = transactions.create(input(bank.id, TransactionType.TRANSFER, 500, transferTo = visa.id))
        assertNull(payment.statementId)
        statement("s1", visa.id, "2026-09-15")
        transactions.update(payment.id, input(bank.id, TransactionType.TRANSFER, 600, transferTo = visa.id))
        assertNull(transactions.get(payment.id)!!.statementId)
    }

    // --- Totales ---

    private fun day(date: String): java.time.Instant = LocalDate.parse(date).atTime(10, 0).toInstant(java.time.ZoneOffset.UTC)

    private val octFrom = day("2026-10-01").minus(Duration.ofHours(10))
    private val octTo = day("2026-11-01").minus(Duration.ofHours(10))

    @Test
    fun `los totales por moneda restan las devoluciones y excluyen transferencias y deudas`() = runBlocking<Unit> {
        val gtq = newAccount("GTQ")
        val gtq2 = newAccount("GTQ 2")
        val usd = newAccount("USD", currency = "USD")
        transactions.create(input(gtq.id, TransactionType.INCOME, 100_000, day("2026-10-02"), categoryId = "default:salary"))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 30_000, day("2026-10-03"), categoryId = "default:food"))
        transactions.create(input(gtq2.id, TransactionType.EXPENSE, 5_000, day("2026-10-04")))
        transactions.create(input(gtq.id, TransactionType.INCOME, 2_000, day("2026-10-05"), categoryId = "system:refunds"))
        transactions.create(input(gtq.id, TransactionType.TRANSFER, 9_999, day("2026-10-06"), transferTo = gtq2.id))
        transactions.create(input(usd.id, TransactionType.EXPENSE, 700, day("2026-10-07")))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 8_888, day("2026-09-30"))) // fuera del periodo
        db.contactDao().insert(contact("c"))
        db.debtDao().insert(debt("d2", "c"))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 4_444, day("2026-10-08"), debtId = "d2"))

        val totals = transactions.totals(octFrom, octTo)
        assertEquals(listOf("GTQ", "USD"), totals.map { it.currency })
        val q = totals[0]
        assertEquals(100_000, q.incomeMinor)
        assertEquals(33_000, q.expenseMinor) // 35 000 − 2 000 de devoluciones
        assertEquals(2_000, q.refundsMinor)
        assertEquals(35_000, q.grossExpenseMinor)
        assertEquals(700, totals[1].expenseMinor)

        assertEquals(listOf("GTQ"), transactions.totals(octFrom, octTo, setOf(gtq.id, gtq2.id)).map { it.currency })
        assertEquals(30_000L - 2_000, transactions.totals(octFrom, octTo, setOf(gtq.id)).single().expenseMinor)
        assertTrue(transactions.totals(octFrom, octTo, emptySet()).isEmpty())
        assertEquals(totals, transactions.observeTotals(octFrom, octTo).first())
    }

    @Test
    fun `los totales por categoria van de mayor a menor con devoluciones en negativo`() = runBlocking<Unit> {
        val gtq = newAccount("GTQ")
        val usd = newAccount("USD", currency = "USD")
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 1_000, day("2026-10-02"), categoryId = "default:food"))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 4_000, day("2026-10-03"), categoryId = "default:groceries"))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 500, day("2026-10-04"), categoryId = "default:food"))
        transactions.create(input(gtq.id, TransactionType.EXPENSE, 300, day("2026-10-05"))) // sin categoría
        transactions.create(input(gtq.id, TransactionType.INCOME, 700, day("2026-10-06"), categoryId = "system:refunds"))
        transactions.create(input(usd.id, TransactionType.EXPENSE, 90, day("2026-10-07"), categoryId = "default:food"))
        transactions.create(input(gtq.id, TransactionType.INCOME, 50_000, day("2026-10-08"), categoryId = "default:salary"))

        val expenses = transactions.totalsByCategory(octFrom, octTo, CategoryKind.EXPENSE)
        assertEquals(
            listOf(
                Triple("GTQ", "default:groceries", 4_000L), Triple("GTQ", "default:food", 1_500L),
                Triple("GTQ", null, 300L), Triple("GTQ", "system:refunds", -700L), Triple("USD", "default:food", 90L),
            ),
            expenses.map { Triple(it.currency, it.categoryId, it.totalMinor) },
        )
        assertEquals(listOf("USD"), transactions.totalsByCategory(octFrom, octTo, CategoryKind.EXPENSE, "USD").map { it.currency })

        val income = transactions.totalsByCategory(octFrom, octTo, CategoryKind.INCOME)
        assertEquals(listOf("default:salary"), income.map { it.categoryId })
    }
}
