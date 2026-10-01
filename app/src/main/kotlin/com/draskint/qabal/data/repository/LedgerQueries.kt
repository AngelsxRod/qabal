package com.draskint.qabal.data.repository

import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.data.local.seed.INTEREST_FEES_CATEGORY_ID
import com.draskint.qabal.data.local.seed.REFUNDS_CATEGORY_ID
import com.draskint.qabal.domain.card.StatementStatus
import com.draskint.qabal.domain.card.statementStatus
import com.draskint.qabal.domain.model.CycleMovements
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Consultas de saldos y sumas compartidas por los repositorios de tarjetas y movimientos. Las
 * ventanas de tiempo son `[start, end)`.
 */
@Singleton
class LedgerQueries @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
) {
    fun today(): LocalDate = LocalDate.now(clock)

    /** Medianoche local del día: inicio de una ventana que incluye [date]. */
    fun startOfDay(date: LocalDate): Instant = date.atStartOfDay(clock.zone).toInstant()

    /** Saldo de la cuenta (negativo = deuda en una tarjeta); [before] limita a movimientos anteriores. */
    suspend fun balanceOf(accountId: String, before: Instant? = null): Long =
        db.transactionDao().getBalanceBefore(accountId, before?.toEpochMilli() ?: Long.MAX_VALUE) ?: 0

    /** Movimientos de la tarjeta del día [from] al día [to], ambos inclusivos. */
    suspend fun cycleMovements(cardId: String, from: LocalDate, to: LocalDate): CycleMovements {
        val start = startOfDay(from)
        val sums = db.transactionDao().getCycleSums(
            cardId, INTEREST_FEES_CATEGORY_ID, REFUNDS_CATEGORY_ID,
            start.toEpochMilli(), startOfDay(to.plusDays(1)).toEpochMilli(),
        )
        return CycleMovements(
            openingDebtMinor = -balanceOf(cardId, before = start),
            purchasesMinor = sums.purchases, interestMinor = sums.interest, cashAdvancesMinor = sums.advances,
            refundsMinor = sums.refunds, otherCreditsMinor = sums.otherCredits, paymentsMinor = sums.payments,
        )
    }

    /** Suma de pagos vinculados (`statementId`) a cada estado de cuenta. */
    suspend fun paidByStatement(statementIds: Collection<String>): Map<String, Long> =
        if (statementIds.isEmpty()) {
            emptyMap()
        } else {
            db.transactionDao().getPaidByStatement(statementIds.toList()).associate { it.statementId to it.paidMinor }
        }

    fun statusOf(s: CreditCardStatementEntity, paidMinor: Long, today: LocalDate): StatementStatus =
        statementStatus(s.statementBalanceMinor, s.minimumPaymentMinor, paidMinor, s.dueDate, today)

    /**
     * Estado de cuenta al que conviene asignar un pago nuevo: el no archivado y no pagado por
     * completo con fecha de pago más antigua (incluye los que solo tienen el mínimo cubierto).
     */
    suspend fun suggestStatementForPayment(cardId: String): String? {
        val statements = db.creditCardDao().getActiveStatementsByDue(cardId)
        val paid = paidByStatement(statements.map { it.id })
        val today = today()
        return statements.firstOrNull { statusOf(it, paid[it.id] ?: 0, today) != StatementStatus.PAID }?.id
    }
}
