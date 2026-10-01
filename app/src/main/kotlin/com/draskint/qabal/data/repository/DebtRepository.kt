package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.error.DebtNotFullyPaidException
import com.draskint.qabal.domain.error.InvalidAmountException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.Debt
import com.draskint.qabal.domain.model.DebtBalance
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtInput
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.TransactionInput
import com.draskint.qabal.domain.model.originTypeOf
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/**
 * Deudas con personas (las tarjetas de crédito no van aquí).
 *
 * Movimientos de una deuda (`Transaction.debtId`), según la dirección:
 *
 * | Deuda         | Origen (nace la deuda)    | Abono                       |
 * |---------------|---------------------------|-----------------------------|
 * | `OWED_TO_ME`  | gasto desde mi cuenta     | ingreso a mi cuenta         |
 * | `I_OWE`       | ingreso a mi cuenta       | gasto desde mi cuenta       |
 *
 * Solo los abonos restan del saldo: `pendiente = principal − Σ abonos`.
 */
@Singleton
class DebtRepository @Inject constructor(
    private val db: AppDatabase,
    private val transactions: TransactionRepository,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val debts get() = db.debtDao()

    /**
     * Crea la deuda y, si se indica [originAccountId], su movimiento de origen (por el monto del
     * principal, sin categoría) en una sola transacción. Sin cuenta de origen sirve para deudas
     * históricas.
     */
    suspend fun create(input: DebtInput, originAccountId: String? = null): Debt {
        if (input.principalMinor <= 0) throw InvalidAmountException()
        val description = requireText(input.description, "La descripción", max = 200)
        val currency = normalizeCurrency(input.currency)
        if (input.dueDate != null && input.dueDate.isBefore(input.startDate)) {
            throw InvalidInputException("La fecha de vencimiento no puede ser anterior al inicio")
        }
        return db.withTransaction {
            if (db.contactDao().getById(input.contactId) == null) throw NotFoundException("Contacto", input.contactId)
            val now = clock.instant()
            val entity = DebtEntity(
                id = ids.newId(), contactId = input.contactId, direction = input.direction,
                principalMinor = input.principalMinor, currency = currency, description = description,
                startDate = input.startDate, dueDate = input.dueDate, createdAt = now, updatedAt = now,
            )
            debts.insert(entity)
            if (originAccountId != null) {
                transactions.create(
                    TransactionInput(
                        accountId = originAccountId, type = originTypeOf(input.direction),
                        amountMinor = input.principalMinor, occurredAt = input.startDate.startOfDay(),
                        contactId = input.contactId, debtId = entity.id, note = description,
                    ),
                )
            }
            entity.toDomain()
        }
    }

    /** Los argumentos nulos no se tocan; [clearDueDate] quita el vencimiento. */
    suspend fun update(
        id: String,
        description: String? = null,
        dueDate: LocalDate? = null,
        clearDueDate: Boolean = false,
    ) {
        val validDescription = description?.let { requireText(it, "La descripción", max = 200) }
        db.withTransaction {
            val current = debts.getById(id) ?: throw NotFoundException("Deuda", id)
            val newDue = if (clearDueDate) null else dueDate ?: current.dueDate
            if (newDue != null && newDue.isBefore(current.startDate)) {
                throw InvalidInputException("La fecha de vencimiento no puede ser anterior al inicio")
            }
            debts.update(
                current.copy(
                    description = validDescription ?: current.description, dueDate = newDue,
                    updatedAt = clock.instant(),
                ),
            )
        }
    }

    /** Marca la deuda como saldada; exige que no quede saldo pendiente (para cerrarla con saldo, [forgive]). */
    suspend fun settle(id: String) {
        db.withTransaction {
            val balance = balance(id)
            if (!balance.isFullyPaid) {
                throw DebtNotFullyPaidException("Quedan ${balance.pendingMinor} por pagar de la deuda \"$id\"")
            }
            setStatus(id, DebtStatus.SETTLED)
        }
    }

    /** Cierra la deuda perdonando el saldo pendiente. */
    suspend fun forgive(id: String) = db.withTransaction { setStatus(id, DebtStatus.FORGIVEN) }

    suspend fun reopen(id: String) = db.withTransaction { setStatus(id, DebtStatus.OPEN) }

    suspend fun setArchived(id: String, archived: Boolean) {
        db.withTransaction {
            val current = debts.getById(id) ?: throw NotFoundException("Deuda", id)
            debts.update(current.copy(isArchived = archived, updatedAt = clock.instant()))
        }
    }

    suspend fun get(id: String): Debt? = debts.getById(id)?.toDomain()

    suspend fun balance(id: String): DebtBalance {
        val debt = get(id) ?: throw NotFoundException("Deuda", id)
        return DebtBalance(debt, debts.getPaid().firstOrNull { it.debtId == id }?.paidMinor ?: 0)
    }

    suspend fun list(
        direction: DebtDirection? = null,
        status: DebtStatus? = null,
        includeArchived: Boolean = false,
    ): List<DebtBalance> {
        val paid = debts.getPaid().associate { it.debtId to it.paidMinor }
        return debts.list(direction, status, includeArchived).map { DebtBalance(it.toDomain(), paid[it.id] ?: 0) }
    }

    /** Deudas con su saldo; se reemite al cambiar deudas o movimientos. */
    fun observe(
        direction: DebtDirection? = null,
        status: DebtStatus? = null,
        includeArchived: Boolean = false,
    ): Flow<List<DebtBalance>> =
        combine(debts.observeList(direction, status, includeArchived), debts.observePaid()) { list, paid ->
            val byId = paid.associate { it.debtId to it.paidMinor }
            list.map { DebtBalance(it.toDomain(), byId[it.id] ?: 0) }
        }

    private suspend fun setStatus(id: String, status: DebtStatus) {
        debts.getById(id) ?: throw NotFoundException("Deuda", id)
        debts.setStatus(id, status, clock.instant().toEpochMilli())
    }

    /** Medianoche local del día: los movimientos de origen se fechan al inicio de la deuda. */
    private fun LocalDate.startOfDay() = atStartOfDay(clock.zone).toInstant()
}
