import 'package:drift/drift.dart';

import 'enums.dart';
import 'ids.dart';

/// Cuenta de dinero (efectivo, banco, tarjeta...). Cada cuenta tiene su
/// propia moneda; los montos se guardan como enteros en la unidad menor
/// (centavos) para evitar errores de punto flotante.
class Accounts extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get initialBalanceMinor => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
