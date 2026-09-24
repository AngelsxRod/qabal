import 'package:finanzas/domain/credit_card/statement_status.dart';
import 'package:flutter_test/flutter_test.dart';

StatementStatus status({
  int balance = 10000,
  int minimum = 1000,
  required int paid,
  required DateTime today,
}) =>
    statementStatus(
      balanceMinor: balance,
      minimumMinor: minimum,
      paidMinor: paid,
      dueDate: DateTime(2026, 10, 15),
      today: today,
    );

void main() {
  final before = DateTime(2026, 10, 1);
  final after = DateTime(2026, 10, 16);

  test('pagado completo', () {
    expect(status(paid: 10000, today: before), StatementStatus.paid);
    expect(status(paid: 12000, today: after), StatementStatus.paid);
  });
  test('saldo cero cuenta como pagado', () {
    expect(status(balance: 0, minimum: 0, paid: 0, today: after), StatementStatus.paid);
  });
  test('mínimo cubierto', () {
    expect(status(paid: 1000, today: before), StatementStatus.minimumCovered);
    expect(status(paid: 5000, today: after), StatementStatus.minimumCovered);
  });
  test('pendiente antes de la fecha de pago', () {
    expect(status(paid: 0, today: before), StatementStatus.pending);
    expect(status(paid: 999, today: before), StatementStatus.pending);
  });
  test('vencido después de la fecha sin cubrir el mínimo', () {
    expect(status(paid: 0, today: after), StatementStatus.overdue);
    expect(status(paid: 999, today: after), StatementStatus.overdue);
  });
  test('el día de pago todavía no está vencido', () {
    expect(status(paid: 0, today: DateTime(2026, 10, 15, 23, 59)), StatementStatus.pending);
  });
}
