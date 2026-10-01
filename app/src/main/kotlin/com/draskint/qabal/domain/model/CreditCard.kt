package com.draskint.qabal.domain.model

import com.draskint.qabal.domain.card.CardCycle
import com.draskint.qabal.domain.card.StatementStatus
import java.time.Instant
import java.time.LocalDate

/** Estado de cuenta cerrado, con los valores que reporta el banco. */
data class CreditCardStatement(
    val id: String,
    val accountId: String,
    val periodStart: LocalDate,
    val closingDate: LocalDate,
    val dueDate: LocalDate,
    val statementBalanceMinor: Long,
    val minimumPaymentMinor: Long,
    val note: String?,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

/** [periodStart] y [dueDate] se derivan del horario de la tarjeta si no se indican. */
data class StatementInput(
    val accountId: String,
    val closingDate: LocalDate,
    val statementBalanceMinor: Long,
    val minimumPaymentMinor: Long,
    val periodStart: LocalDate? = null,
    val dueDate: LocalDate? = null,
    val note: String? = null,
)

/**
 * Movimientos de una tarjeta en una ventana de tiempo.
 * `closingDebtMinor` = deuda inicial + compras + intereses + avances − devoluciones − otros créditos − pagos.
 */
data class CycleMovements(
    /** Deuda al inicio de la ventana (arrastra lo no pagado de ciclos anteriores). */
    val openingDebtMinor: Long,
    /** Gastos de la tarjeta, salvo la categoría del sistema «Intereses y cargos». */
    val purchasesMinor: Long,
    /** Gastos con la categoría del sistema «Intereses y cargos». */
    val interestMinor: Long,
    /** Transferencias salientes de la tarjeta. */
    val cashAdvancesMinor: Long,
    /** Ingresos con la categoría del sistema «Devoluciones». */
    val refundsMinor: Long,
    /** Cualquier otro ingreso a la tarjeta. */
    val otherCreditsMinor: Long,
    /** Transferencias hacia la tarjeta. */
    val paymentsMinor: Long,
) {
    val closingDebtMinor: Long
        get() = openingDebtMinor + purchasesMinor + interestMinor + cashAdvancesMinor -
            refundsMinor - otherCreditsMinor - paymentsMinor
}

data class CardCycleSummary(
    val cycle: CardCycle,
    val movements: CycleMovements,
    /** `ceil(estimado × minPaymentBp / 10000)`; nulo sin `minPaymentBp` o sin deuda. */
    val estimatedMinimumMinor: Long?,
    /** Lo que falta pagar del último estado de cuenta anterior al ciclo; nulo si no hay ninguno. */
    val previousStatementPendingMinor: Long?,
) {
    /** Deuda estimada al próximo corte (incluye lo arrastrado). */
    val estimatedClosingMinor: Long get() = movements.closingDebtMinor
}

data class CardOverview(
    val account: Account,
    val settings: CreditCardSettings,
    /** Saldo; negativo = deuda. */
    val balanceMinor: Long,
    val summary: CardCycleSummary,
) {
    /** Deuda; negativa si hay saldo a favor. */
    val debtMinor: Long get() = -balanceMinor

    /** Cuánto debo (nunca negativo). */
    val owedMinor: Long get() = maxOf(debtMinor, 0)

    /** Límite menos deuda; negativo si se excede el límite. */
    val availableCreditMinor: Long get() = settings.creditLimitMinor - debtMinor
}

data class StatementView(
    val statement: CreditCardStatement,
    /** Suma de las transferencias vinculadas con `statementId`. */
    val paidMinor: Long,
    val status: StatementStatus,
    /** Deuda al corte calculada por la app. */
    val estimatedBalanceMinor: Long,
    /** Desglose de la ventana del estado de cuenta. */
    val movements: CycleMovements,
) {
    /** Oficial − estimado. Positivo: el banco reporta más de lo registrado. */
    val differenceMinor: Long get() = statement.statementBalanceMinor - estimatedBalanceMinor
}

/** Estado de cuenta que aún no está pagado por completo, con su tarjeta. */
data class PendingStatement(
    val card: Account,
    val statement: CreditCardStatement,
    val paidMinor: Long,
    val status: StatementStatus,
) {
    /** Lo que falta para saldar el estado (nunca negativo). */
    val pendingMinor: Long get() = maxOf(statement.statementBalanceMinor - paidMinor, 0)

    /** Lo que falta para cubrir el mínimo (nunca negativo). */
    val minimumPendingMinor: Long get() = maxOf(statement.minimumPaymentMinor - paidMinor, 0)
}
