import 'package:drift/drift.dart';

import 'enums.dart';
import 'ids.dart';

/// De quién viene o a quién va el dinero (empleador, cliente, persona...).
class Contacts extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => textEnum<ContactType>().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
