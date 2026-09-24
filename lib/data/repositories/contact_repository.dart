import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'models.dart';
import 'validation.dart';

class ContactRepository {
  ContactRepository(this._db, {this._now = DateTime.now});

  final AppDatabase _db;
  final Now _now;

  Future<Contact> create(ContactInput input) {
    final n = _now();
    return _db.into(_db.contacts).insertReturning(
          ContactsCompanion.insert(
            name: requireText(input.name, 'El nombre'),
            type: Value(input.type),
            note: Value(input.note),
            createdAt: Value(n),
            updatedAt: Value(n),
          ),
        );
  }

  Future<void> update(String id, {String? name, ContactType? type, String? note}) async {
    final rows = await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
      ContactsCompanion(
        name: Value.absentIfNull(name == null ? null : requireText(name, 'El nombre')),
        type: Value.absentIfNull(type),
        note: Value.absentIfNull(note),
        updatedAt: Value(_now()),
      ),
    );
    if (rows == 0) throw NotFoundException('Contacto', id);
  }

  Future<void> setArchived(String id, bool archived) async {
    final rows = await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
      ContactsCompanion(isArchived: Value(archived), updatedAt: Value(_now())),
    );
    if (rows == 0) throw NotFoundException('Contacto', id);
  }

  Future<Contact?> get(String id) =>
      (_db.select(_db.contacts)..where((c) => c.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$ContactsTable, Contact> _listQuery(bool includeArchived) {
    final q = _db.select(_db.contacts)..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (!includeArchived) q.where((c) => c.isArchived.equals(false));
    return q;
  }

  Future<List<Contact>> list({bool includeArchived = false}) =>
      _listQuery(includeArchived).get();

  Stream<List<Contact>> watch({bool includeArchived = false}) =>
      _listQuery(includeArchived).watch();
}
