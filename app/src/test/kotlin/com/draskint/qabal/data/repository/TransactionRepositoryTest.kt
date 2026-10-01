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
import com.draskint.qabal.domain.model.AccountType
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
}
