// ignore_for_file: recursive_getters (patrón de Drift para CHECK en columnas)

import 'package:drift/drift.dart';

import '../date_only_converter.dart';
import 'accounts.dart';
import 'ids.dart';

/// Estado de cuenta ya cerrado, con los valores que reporta el banco.
/// El estado (pagado, vencido...) no se guarda: se calcula a partir de los
/// pagos asociados y la fecha actual.
@TableIndex(name: 'idx_statements_account_due', columns: {#accountId, #dueDate})
class CreditCardStatements extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get periodStart => text().map(const DateOnlyConverter())();
  TextColumn get closingDate => text().map(const DateOnlyConverter())();
  TextColumn get dueDate => text().map(const DateOnlyConverter())();
  IntColumn get statementBalanceMinor =>
      integer().check(statementBalanceMinor.isBiggerOrEqualValue(0))();
  IntColumn get minimumPaymentMinor =>
      integer().check(minimumPaymentMinor.isBiggerOrEqualValue(0))();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {accountId, closingDate},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (minimum_payment_minor <= statement_balance_minor)',
      ];
}
