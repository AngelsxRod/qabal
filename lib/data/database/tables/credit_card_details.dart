// ignore_for_file: recursive_getters (patrón de Drift para CHECK en columnas)

import 'package:drift/drift.dart';

import 'accounts.dart';

/// Datos propios de una cuenta de tipo `creditCard` (relación 1 a 1).
/// `minPaymentBp` es el pago mínimo estimado en puntos básicos (500 = 5 %).
class CreditCardDetails extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get creditLimitMinor => integer().check(creditLimitMinor.isBiggerThanValue(0))();
  IntColumn get statementDay =>
      integer().check(statementDay.isBetweenValues(1, 31))();
  IntColumn get dueDay => integer().check(dueDay.isBetweenValues(1, 31))();
  IntColumn get minPaymentBp =>
      integer().nullable().check(minPaymentBp.isBetweenValues(0, 10000))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {accountId};
}
