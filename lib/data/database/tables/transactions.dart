import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'enums.dart';
import 'ids.dart';

/// Movimiento de dinero. `amountMinor` es siempre positivo; el signo lo
/// determina `type`. En una transferencia, `accountId` es el origen y
/// `transferAccountId` el destino; `transferAmountMinor` solo se usa cuando
/// las monedas de ambas cuentas difieren.
@TableIndex(name: 'idx_transactions_account_date', columns: {#accountId, #occurredAt})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  @ReferenceName('transactions')
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId => text()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => textEnum<TransactionType>()();
  // ignore: recursive_getters
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
  @ReferenceName('incomingTransfers')
  TextColumn get transferAccountId => text()
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get transferAmountMinor => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
