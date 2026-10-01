package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import androidx.sqlite.db.SimpleSQLiteQuery
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.di.IdGenerator
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
import com.draskint.qabal.data.local.seed.REFUNDS_CATEGORY_ID
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CategoryKind
import com.draskint.qabal.domain.model.CategoryTotal
import com.draskint.qabal.domain.model.PeriodTotals
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.Transaction
import com.draskint.qabal.domain.model.TransactionFilter
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.TransactionType
import com.draskint.qabal.domain.model.repaymentTypeOf
import java.time.Clock
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class TransactionRepository @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
    private val ids: IdGenerator,
    private val ledger: LedgerQueries,
) {
    private val transactions get() = db.transactionDao()

    // --- Escritura ---

    /**
     * Crea un movimiento (y sus etiquetas) en una sola transacción.
     *
     * Si es una transferencia hacia una tarjeta de crédito sin `statementId` y [autoAssignStatement]
     * es verdadero, se vincula al estado de cuenta que sugiere `suggestStatementForPayment` (si
     * existe). Pasar `false` para, por ejemplo, un pago adelantado del ciclo en curso.
     */
    suspend fun create(
        input: TransactionInput,
        tagIds: Set<String> = emptySet(),
        autoAssignStatement: Boolean = true,
    ): Transaction =
        db.withTransaction {
            val i = if (autoAssignStatement) withSuggestedStatement(input) else input
            validate(i)
            val now = clock.instant()
            val entity = TransactionEntity(
                id = ids.newId(), accountId = i.accountId, categoryId = i.categoryId, type = i.type,
                amountMinor = i.amountMinor, transferAccountId = i.transferAccountId,
                transferAmountMinor = i.transferAmountMinor, contactId = i.contactId,
                debtId = i.debtId, statementId = i.statementId, note = i.note,
                receiptPath = i.receiptPath, occurredAt = i.occurredAt, createdAt = now, updatedAt = now,
            )
            transactions.insert(entity)
            replaceTags(entity.id, tagIds)
            entity.toDomain()
        }

    /** Reemplaza todos los campos del movimiento. `tagIds` nulo = no tocar las etiquetas. */
    suspend fun update(id: String, input: TransactionInput, tagIds: Set<String>? = null) {
        db.withTransaction {
            val existing = transactions.getById(id) ?: throw NotFoundException("Movimiento", id)
            validate(input, existing)
            transactions.update(
                existing.copy(
                    accountId = input.accountId, categoryId = input.categoryId, type = input.type,
                    amountMinor = input.amountMinor, transferAccountId = input.transferAccountId,
                    transferAmountMinor = input.transferAmountMinor, contactId = input.contactId,
                    debtId = input.debtId, statementId = input.statementId, note = input.note,
                    receiptPath = input.receiptPath, occurredAt = input.occurredAt, updatedAt = clock.instant(),
                ),
            )
            if (tagIds != null) replaceTags(id, tagIds)
        }
    }

    /** Reemplaza solo las etiquetas de un movimiento (y actualiza su `updatedAt`). */
    suspend fun setTags(id: String, tagIds: Set<String>) {
        db.withTransaction {
            val existing = transactions.getById(id) ?: throw NotFoundException("Movimiento", id)
            replaceTags(id, tagIds)
            transactions.update(existing.copy(updatedAt = clock.instant()))
        }
    }

    /** Borrado real (los movimientos no se archivan); las etiquetas asociadas se borran en cascada. */
    suspend fun delete(id: String) {
        db.withTransaction {
            transactions.getById(id) ?: throw NotFoundException("Movimiento", id)
            transactions.deleteById(id)
        }
    }

    /** Vincula el pago a una tarjeta con su estado de cuenta pendiente más antiguo, si hay uno. */
    private suspend fun withSuggestedStatement(i: TransactionInput): TransactionInput {
        if (i.type != TransactionType.TRANSFER || i.statementId != null || i.transferAccountId == null) return i
        val dest = db.accountDao().getById(i.transferAccountId)
        if (dest == null || dest.type != AccountType.CREDIT_CARD) return i
        return i.copy(statementId = ledger.suggestStatementForPayment(dest.id))
    }

    // --- Lectura ---

    suspend fun get(id: String): Transaction? = transactions.getById(id)?.toDomain()

    suspend fun list(filter: TransactionFilter = TransactionFilter()): List<Transaction> =
        db.transactionQueryDao().query(buildQuery(filter)).map { it.toDomain() }

    fun observe(filter: TransactionFilter = TransactionFilter()): Flow<List<Transaction>> =
        db.transactionQueryDao().observe(buildQuery(filter)).map { rows -> rows.map { it.toDomain() } }

    // --- Totales ---

    /**
     * Totales por moneda de `[from, to)`, opcionalmente de [accountIds]; sin transferencias ni
     * movimientos de deuda. El gasto es neto de devoluciones.
     */
    suspend fun totals(from: Instant, to: Instant, accountIds: Set<String>? = null): List<PeriodTotals> {
        if (accountIds != null && accountIds.isEmpty()) return emptyList()
        return transactions.getPeriodTotals(
            REFUNDS_CATEGORY_ID, from.toEpochMilli(), to.toEpochMilli(), accountIds == null, accountIds?.toList().orEmpty(),
        ).map { PeriodTotals(it.currency, it.income, it.grossExpense - it.refunds, it.refunds) }
    }

    fun observeTotals(from: Instant, to: Instant, accountIds: Set<String>? = null): Flow<List<PeriodTotals>> =
        db.observeComputed("transactions", "accounts") { totals(from, to, accountIds) }

    /**
     * Totales por moneda y categoría de `[from, to)`, de mayor a menor dentro de cada moneda. En
     * gastos se añade una línea **negativa** con las devoluciones (`system:refunds`); en ingresos las
     * devoluciones no aparecen.
     */
    suspend fun totalsByCategory(
        from: Instant,
        to: Instant,
        kind: CategoryKind,
        currency: String? = null,
    ): List<CategoryTotal> {
        val isExpense = kind == CategoryKind.EXPENSE
        val type = if (isExpense) TransactionType.EXPENSE else TransactionType.INCOME
        val (fromMs, toMs) = from.toEpochMilli() to to.toEpochMilli()
        val main = transactions.getCategoryTotals(type, REFUNDS_CATEGORY_ID, false, fromMs, toMs, currency)
            .map { CategoryTotal(it.currency, it.categoryId, it.total) }
        val refunds = if (isExpense) {
            transactions.getCategoryTotals(TransactionType.INCOME, REFUNDS_CATEGORY_ID, true, fromMs, toMs, currency)
                .map { CategoryTotal(it.currency, REFUNDS_CATEGORY_ID, -it.total) }
        } else {
            emptyList()
        }
        return (main + refunds).sortedWith(compareBy<CategoryTotal> { it.currency }.thenByDescending { it.totalMinor })
    }

    private fun buildQuery(f: TransactionFilter): SimpleSQLiteQuery {
        val where = mutableListOf<String>()
        val args = mutableListOf<Any>()
        fun add(clause: String, vararg values: Any) {
            where += clause
            args.addAll(values)
        }
        f.accountId?.let { add("(accountId = ? OR transferAccountId = ?)", it, it) }
        f.categoryId?.let { add("categoryId = ?", it) }
        f.contactId?.let { add("contactId = ?", it) }
        f.debtId?.let { add("debtId = ?", it) }
        f.statementId?.let { add("statementId = ?", it) }
        f.type?.let { add("type = ?", it.name) }
        f.from?.let { add("occurredAt >= ?", it.toEpochMilli()) }
        f.to?.let { add("occurredAt < ?", it.toEpochMilli()) }
        f.tagId?.let { add("id IN (SELECT transactionId FROM transaction_tags WHERE tagId = ?)", it) }

        val sql = buildString {
            append("SELECT * FROM transactions")
            if (where.isNotEmpty()) append(" WHERE ").append(where.joinToString(" AND "))
            // Orden estable: en un empate de fecha, el último insertado va arriba.
            append(" ORDER BY occurredAt DESC, createdAt DESC, rowid DESC")
            if (f.limit != null) {
                append(" LIMIT ?")
                args += f.limit
                if (f.offset != null) {
                    append(" OFFSET ?")
                    args += f.offset
                }
            } else if (f.offset != null) {
                append(" LIMIT -1 OFFSET ?")
                args += f.offset
            }
        }
        return SimpleSQLiteQuery(sql, args.toTypedArray())
    }

    // --- Validación ---

    private suspend fun validate(i: TransactionInput, existing: TransactionEntity? = null) {
        if (i.amountMinor <= 0) throw InvalidAmountException()

        val isTransfer = i.type == TransactionType.TRANSFER
        if (isTransfer) {
            if (i.transferAccountId == null) throw InvalidTransferException("Una transferencia requiere cuenta destino")
            if (i.transferAccountId == i.accountId) {
                throw InvalidTransferException("El origen y el destino deben ser distintos")
            }
        } else if (i.transferAccountId != null || i.transferAmountMinor != null) {
            throw InvalidTransferException("Solo las transferencias llevan cuenta y monto de destino")
        }

        val source = db.accountDao().getById(i.accountId) ?: throw NotFoundException("Cuenta", i.accountId)
        val dest = if (isTransfer) {
            db.accountDao().getById(i.transferAccountId!!) ?: throw NotFoundException("Cuenta", i.transferAccountId)
        } else {
            null
        }

        // No se aceptan movimientos nuevos en cuentas archivadas; al editar se permite conservar la
        // cuenta que ya tenía el movimiento.
        if (source.isArchived && existing?.accountId != source.id) throw ArchivedAccountException(source.id)
        if (dest != null && dest.isArchived && existing?.transferAccountId != dest.id) {
            throw ArchivedAccountException(dest.id)
        }

        if (dest != null) {
            val differs = source.currency != dest.currency
            val destAmount = i.transferAmountMinor
            if (differs && (destAmount == null || destAmount <= 0)) {
                throw InvalidTransferException("Las cuentas tienen monedas distintas: indica el monto de destino")
            }
            if (!differs && destAmount != null) {
                throw InvalidTransferException("Las cuentas tienen la misma moneda: no lleva monto de destino")
            }
        }

        if (i.categoryId != null) {
            if (isTransfer) throw InvalidTransferException("Las transferencias no llevan categoría")
            if (i.debtId != null) throw DebtMovementCategoryException("Los movimientos de deuda no llevan categoría")
            val category = db.categoryDao().getById(i.categoryId) ?: throw NotFoundException("Categoría", i.categoryId)
            val expected = if (i.type == TransactionType.INCOME) CategoryKind.INCOME else CategoryKind.EXPENSE
            if (category.kind != expected) {
                throw CategoryKindMismatchException(
                    "La categoría \"${category.name}\" es de ${category.kind.name.lowercase()} y el " +
                        "movimiento es de ${i.type.name.lowercase()}",
                )
            }
        }

        if (i.statementId != null) {
            if (!isTransfer) {
                throw InvalidStatementLinkException("Solo una transferencia puede vincularse a un estado de cuenta")
            }
            val statement = db.creditCardDao().getStatement(i.statementId)
                ?: throw NotFoundException("Estado de cuenta", i.statementId)
            if (statement.accountId != i.transferAccountId) {
                throw InvalidStatementLinkException("El destino del pago debe ser la tarjeta del estado de cuenta")
            }
        }

        if (i.debtId != null) {
            if (isTransfer) throw InvalidInputException("Una transferencia no puede ser un movimiento de deuda")
            val debt = db.debtDao().getById(i.debtId) ?: throw NotFoundException("Deuda", i.debtId)
            if (debt.currency != source.currency) {
                throw CurrencyMismatchException("La deuda es en ${debt.currency} y la cuenta en ${source.currency}")
            }
            // Los abonos no se aceptan en deudas saldadas o perdonadas (hay que reabrirlas); al editar
            // se permite conservar la deuda que ya tenía.
            if (debt.status != DebtStatus.OPEN && i.type == repaymentTypeOf(debt.direction) &&
                existing?.debtId != debt.id
            ) {
                throw DebtClosedException(debt.id, debt.status)
            }
        }

        if (i.contactId != null && db.contactDao().getById(i.contactId) == null) {
            throw NotFoundException("Contacto", i.contactId)
        }
    }

    private suspend fun replaceTags(transactionId: String, tagIds: Set<String>) {
        tagIds.firstOrNull { db.tagDao().getById(it) == null }?.let { throw NotFoundException("Etiqueta", it) }
        transactions.replaceTags(transactionId, tagIds)
    }
}
