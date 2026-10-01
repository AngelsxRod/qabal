package com.draskint.qabal.domain.model

import java.time.Instant
import java.time.LocalDate

data class Debt(
    val id: String,
    val contactId: String,
    val direction: DebtDirection,
    val principalMinor: Long,
    val currency: String,
    val description: String,
    val startDate: LocalDate,
    val dueDate: LocalDate?,
    val status: DebtStatus,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class DebtInput(
    val contactId: String,
    val direction: DebtDirection,
    val principalMinor: Long,
    val currency: String,
    val description: String,
    val startDate: LocalDate,
    val dueDate: LocalDate? = null,
)

/** Deuda con lo abonado hasta ahora (no incluye el movimiento de origen). */
data class DebtBalance(val debt: Debt, val paidMinor: Long) {
    /** `principal − abonos`, nunca negativo. */
    val pendingMinor: Long get() = maxOf(debt.principalMinor - paidMinor, 0)

    /** Lo abonado de más sobre el principal. */
    val excessMinor: Long get() = maxOf(paidMinor - debt.principalMinor, 0)

    val isFullyPaid: Boolean get() = pendingMinor == 0L
}
