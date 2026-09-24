enum StatementStatus { paid, minimumCovered, pending, overdue }

/// Estado de un estado de cuenta según lo pagado hasta hoy.
///
/// 1. Pagado el saldo completo (o saldo cero) → `paid`.
/// 2. Pasó la fecha de pago sin cubrir el mínimo → `overdue`.
/// 3. Cubierto el mínimo → `minimumCovered`.
/// 4. En cualquier otro caso → `pending`.
StatementStatus statementStatus({
  required int balanceMinor,
  required int minimumMinor,
  required int paidMinor,
  required DateTime dueDate,
  required DateTime today,
}) {
  if (paidMinor >= balanceMinor) return StatementStatus.paid;
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final now = DateTime(today.year, today.month, today.day);
  if (now.isAfter(due) && paidMinor < minimumMinor) {
    return StatementStatus.overdue;
  }
  if (paidMinor >= minimumMinor) return StatementStatus.minimumCovered;
  return StatementStatus.pending;
}
