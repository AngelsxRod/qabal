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

/** Deuda con lo abonado hasta ahora; `pendiente = principal − abonos` (puede quedar negativo si se paga de más). */
data class DebtBalance(val debt: Debt, val paidMinor: Long) {
    val pendingMinor: Long get() = debt.principalMinor - paidMinor
    val isFullyPaid: Boolean get() = pendingMinor <= 0
}
