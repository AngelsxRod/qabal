import 'package:drift/drift.dart';

import 'enums.dart';
import 'ids.dart';

/// Categoría de ingreso o gasto. `parentId` permite subcategorías.
class Categories extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get parentId =>
      text().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get icon => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
