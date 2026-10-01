package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.data.mapper.toSettings
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.card.StatementStatus
import com.draskint.qabal.domain.card.cycleClosingOn
import com.draskint.qabal.domain.card.cycleForPurchase
import com.draskint.qabal.domain.error.DuplicateStatementException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotACreditCardException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.error.StatementOverlapException
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CardCycleSummary
import com.draskint.qabal.domain.model.CardOverview
import com.draskint.qabal.domain.model.CreditCardStatement
import com.draskint.qabal.domain.model.PendingStatement
import com.draskint.qabal.domain.model.StatementInput
import com.draskint.qabal.domain.model.StatementView
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow

private val CARD_TABLES = arrayOf("accounts", "transactions", "credit_card_details", "credit_card_statements")

/**
 * Ciclos y estados de cuenta de tarjetas de crédito.
 *
 * Convención: el saldo de una tarjeta es negativo cuando se debe; `deuda = −saldo`. Todo lo «del
 * ciclo» se calcula a partir de los movimientos; el valor oficial es el que se registra del banco
 * en [registerStatement].
 */
@Singleton
class CreditCardRepository @Inject constructor(
    private val db: AppDatabase,
    private val ledger: LedgerQueries,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val cards get() = db.creditCardDao()

    private suspend fun card(accountId: String): Pair<AccountEntity, CreditCardDetailsEntity> {
        val account = db.accountDao().getById(accountId) ?: throw NotFoundException("Cuenta", accountId)
        if (account.type != AccountType.CREDIT_CARD) throw NotACreditCardException(accountId)
        val details = cards.getDetails(accountId) ?: throw NotFoundException("Detalles de tarjeta", accountId)
        return account to details
    }

    private suspend fun statement(id: String): CreditCardStatementEntity =
        cards.getStatement(id) ?: throw NotFoundException("Estado de cuenta", id)

    // --- Resumen del ciclo ---

    suspend fun overview(accountId: String): CardOverview {
        val (account, details) = card(accountId)
        return CardOverview(
            account = account.toDomain(), settings = details.toSettings(),
            balanceMinor = ledger.balanceOf(accountId), summary = cycleSummary(accountId),
        )
    }

    fun observeOverview(accountId: String): Flow<CardOverview> =
        db.observeComputed(*CARD_TABLES) { overview(accountId) }

    /**
     * Ciclo al que pertenece [forDate] (por defecto hoy), con sus movimientos y el saldo estimado al
     * corte. La deuda no pagada de ciclos anteriores no se reinicia: entra en `openingDebtMinor` y
     * por tanto en el estimado.
     */
    suspend fun cycleSummary(accountId: String, forDate: LocalDate? = null): CardCycleSummary {
        val (_, details) = card(accountId)
        val cycle = cycleForPurchase(forDate ?: ledger.today(), details.statementDay, details.dueDay)
        val movements = ledger.cycleMovements(accountId, cycle.periodStart, cycle.closingDate)

        val closing = movements.closingDebtMinor
        val bp = details.minPaymentBp
        val estimatedMinimum = if (bp != null && closing > 0) (closing * bp + 9999) / 10000 else null

        val previousPending = cards.getLastStatementBefore(accountId, cycle.periodStart)?.let { previous ->
            val paid = ledger.paidByStatement(listOf(previous.id))[previous.id] ?: 0
            maxOf(previous.statementBalanceMinor - paid, 0)
        }
        return CardCycleSummary(cycle, movements, estimatedMinimum, previousPending)
    }

    // --- Estados de cuenta ---

    /** Registra un estado de cuenta con los valores del banco; `periodStart` y `dueDate` se derivan del horario si no se indican. */
    suspend fun registerStatement(input: StatementInput): CreditCardStatement = db.withTransaction {
        val (_, details) = card(input.accountId)
        val closing = input.closingDate
        val derived = cycleClosingOn(closing.year, closing.monthValue, details.statementDay, details.dueDay)
        val start = input.periodStart ?: derived.periodStart
        val due = input.dueDate ?: derived.dueDate

        validateAmounts(input.statementBalanceMinor, input.minimumPaymentMinor)
        validateDates(start, closing, due)

        if (cards.getStatementByClosing(input.accountId, closing) != null) {
            throw DuplicateStatementException("Ya hay un estado de cuenta con corte $closing para esta tarjeta")
        }
        if (cards.findOverlappingStatement(input.accountId, start, closing) != null) {
            throw StatementOverlapException("El período $start – $closing se solapa con otro estado de cuenta")
        }

        val now = clock.instant()
        val entity = CreditCardStatementEntity(
            id = ids.newId(), accountId = input.accountId, periodStart = start, closingDate = closing,
            dueDate = due, statementBalanceMinor = input.statementBalanceMinor,
            minimumPaymentMinor = input.minimumPaymentMinor, note = input.note, createdAt = now, updatedAt = now,
        )
        cards.insertStatement(entity)
        entity.toDomain()
    }

    /** Los argumentos nulos no se tocan. */
    suspend fun updateStatement(
        id: String,
        balanceMinor: Long? = null,
        minimumMinor: Long? = null,
        dueDate: LocalDate? = null,
        note: String? = null,
    ) {
        db.withTransaction {
            val s = statement(id)
            val balance = balanceMinor ?: s.statementBalanceMinor
            val minimum = minimumMinor ?: s.minimumPaymentMinor
            val due = dueDate ?: s.dueDate
            validateAmounts(balance, minimum)
            validateDates(s.periodStart, s.closingDate, due)
            cards.updateStatement(
                s.copy(
                    statementBalanceMinor = balance, minimumPaymentMinor = minimum, dueDate = due,
                    note = note ?: s.note, updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun setStatementArchived(id: String, archived: Boolean) {
        db.withTransaction {
            cards.updateStatement(statement(id).copy(isArchived = archived, updatedAt = clock.instant()))
        }
    }

    suspend fun statementView(id: String): StatementView {
        val s = statement(id)
        return view(s, ledger.paidByStatement(listOf(id))[id] ?: 0, ledger.today())
    }

    /** Estados de cuenta de la tarjeta, del corte más reciente al más antiguo. */
    suspend fun statements(cardId: String, includeArchived: Boolean = false): List<StatementView> {
        card(cardId)
        val list = cards.getStatements(cardId, includeArchived)
        val paid = ledger.paidByStatement(list.map { it.id })
        val today = ledger.today()
        return list.map { view(it, paid[it.id] ?: 0, today) }
    }

    fun observeStatements(cardId: String, includeArchived: Boolean = false): Flow<List<StatementView>> =
        db.observeComputed(*CARD_TABLES) { statements(cardId, includeArchived) }

    /** Deuda estimada por la app al final del día [closingDate] (positiva si se debe). */
    suspend fun estimatedBalanceAt(cardId: String, closingDate: LocalDate): Long {
        card(cardId)
        return -ledger.balanceOf(cardId, before = ledger.startOfDay(closingDate.plusDays(1)))
    }

    /**
     * Estados de cuenta activos de tarjetas activas que no están pagados por completo, de la fecha
     * de pago más próxima a la más lejana.
     */
    suspend fun pendingStatements(): List<PendingStatement> {
        val rows = cards.getActiveStatementsWithCard()
        val paid = ledger.paidByStatement(rows.map { it.statement.id })
        val today = ledger.today()
        return rows.mapNotNull { (s, account) ->
            val paidMinor = paid[s.id] ?: 0
            val status = ledger.statusOf(s, paidMinor, today)
            if (status == StatementStatus.PAID) null else PendingStatement(account.toDomain(), s.toDomain(), paidMinor, status)
        }
    }

    fun observePendingStatements(): Flow<List<PendingStatement>> =
        db.observeComputed(*CARD_TABLES) { pendingStatements() }

    /**
     * Estado de cuenta al que asignar un pago nuevo: el no archivado y no pagado por completo con
     * fecha de pago más antigua (incluye los que solo tienen el mínimo cubierto).
     */
    suspend fun suggestStatementForPayment(cardId: String): String? {
        card(cardId)
        return ledger.suggestStatementForPayment(cardId)
    }

    // ---

    private suspend fun view(s: CreditCardStatementEntity, paidMinor: Long, today: LocalDate) = StatementView(
        statement = s.toDomain(), paidMinor = paidMinor, status = ledger.statusOf(s, paidMinor, today),
        estimatedBalanceMinor = estimatedBalanceAt(s.accountId, s.closingDate),
        movements = ledger.cycleMovements(s.accountId, s.periodStart, s.closingDate),
    )

    private fun validateAmounts(balance: Long, minimum: Long) {
        if (balance < 0 || minimum < 0) {
            throw InvalidInputException("Los montos del estado de cuenta no pueden ser negativos")
        }
        if (minimum > balance) {
            throw InvalidInputException("El pago mínimo no puede superar el saldo del estado de cuenta")
        }
    }

    private fun validateDates(start: LocalDate, closing: LocalDate, due: LocalDate) {
        if (start.isAfter(closing)) throw InvalidInputException("El inicio del período no puede ser posterior al corte")
        if (!due.isAfter(closing)) throw InvalidInputException("La fecha de pago debe ser posterior al corte")
    }
}
