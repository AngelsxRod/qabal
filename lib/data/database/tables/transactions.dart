// ignore_for_file: recursive_getters (patrón de Drift para CHECK en columnas)

import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'contacts.dart';
import 'credit_card_statements.dart';
import 'debts.dart';
import 'enums.dart';
import 'ids.dart';

/// Movimiento de dinero. `amountMinor` es siempre positivo; el signo lo
/// determina `type`. En una transferencia, `accountId` es el origen y
/// `transferAccountId` el destino; `transferAmountMinor` solo se usa cuando
/// las monedas de ambas cuentas difieren.
///
/// - Pago de tarjeta: `transfer` hacia la tarjeta, opcionalmente con
///   `statementId`.
/// - Movimiento de deuda (origen o abono): lleva `debtId`, sin categoría, y
///   se excluye de los totales de ingresos/gastos.
@TableIndex(name: 'idx_transactions_account_date', columns: {#accountId, #occurredAt})
@TableIndex(name: 'idx_transactions_transfer_date', columns: {#transferAccountId, #occurredAt})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
@TableIndex(name: 'idx_transactions_statement', columns: {#statementId})
@TableIndex(name: 'idx_transactions_debt', columns: {#debtId})
@TableIndex(name: 'idx_transactions_contact', columns: {#contactId})
class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  @ReferenceName('transactions')
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId => text()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
  @ReferenceName('incomingTransfers')
  TextColumn get transferAccountId => text()
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get transferAmountMinor => integer().nullable()();
  TextColumn get contactId => text()
      .nullable()
      .references(Contacts, #id, onDelete: KeyAction.restrict)();
  TextColumn get debtId => text()
      .nullable()
      .references(Debts, #id, onDelete: KeyAction.restrict)();
  TextColumn get statementId => text()
      .nullable()
      .references(CreditCardStatements, #id, onDelete: KeyAction.setNull)();
  TextColumn get note => text().nullable()();
  /// Ruta relativa a la carpeta de documentos de la app.
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK ((type = 'transfer') = (transfer_account_id IS NOT NULL))",
        'CHECK (transfer_account_id IS NULL OR transfer_account_id <> account_id)',
        "CHECK (transfer_amount_minor IS NULL OR type = 'transfer')",
        'CHECK (transfer_amount_minor IS NULL OR transfer_amount_minor > 0)',
        "CHECK (statement_id IS NULL OR type = 'transfer')",
        "CHECK (debt_id IS NULL OR type <> 'transfer')",
      ];
}
