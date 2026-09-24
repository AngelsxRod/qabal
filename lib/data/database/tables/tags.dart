import 'package:drift/drift.dart';

import 'ids.dart';
import 'transactions.dart';

/// Etiqueta libre para filtrar movimientos. El nombre es único sin
/// distinguir mayúsculas.
class Tags extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get name =>
      text().withLength(min: 1, max: 40).customConstraint('NOT NULL UNIQUE COLLATE NOCASE')();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_transaction_tags_tag', columns: {#tagId})
class TransactionTags extends Table {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
