package com.draskint.qabal.domain.card

import java.time.LocalDate

enum class StatementStatus { PAID, MINIMUM_COVERED, PENDING, OVERDUE }

/**
 * Estado de un estado de cuenta según lo pagado hasta [today].
 *
 * 1. Pagado el saldo completo (o saldo cero) → `PAID`.
 * 2. Pasó la fecha de pago sin cubrir el mínimo → `OVERDUE`.
 * 3. Cubierto el mínimo → `MINIMUM_COVERED`.
 * 4. En cualquier otro caso → `PENDING`.
 */
fun statementStatus(
    balanceMinor: Long,
    minimumMinor: Long,
    paidMinor: Long,
    dueDate: LocalDate,
    today: LocalDate,
): StatementStatus = when {
    paidMinor >= balanceMinor -> StatementStatus.PAID
    today.isAfter(dueDate) && paidMinor < minimumMinor -> StatementStatus.OVERDUE
    paidMinor >= minimumMinor -> StatementStatus.MINIMUM_COVERED
    else -> StatementStatus.PENDING
}
