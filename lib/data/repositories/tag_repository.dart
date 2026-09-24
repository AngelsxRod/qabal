import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'validation.dart';

class TagRepository {
  TagRepository(this._db, {this._now = DateTime.now});

  final AppDatabase _db;
  final Now _now;

  /// El nombre es único sin distinguir mayúsculas (igual que la restricción de
  /// la tabla).
  Future<Tag> create(String name, {int? colorValue}) => _db.transaction(() async {
        final n = requireText(name, 'El nombre', max: 40);
        await _ensureUnique(n);
        final now = _now();
        return _db.into(_db.tags).insertReturning(
              TagsCompanion.insert(
                name: n,
                colorValue: Value(colorValue),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      });

  Future<void> update(String id, {String? name, int? colorValue}) =>
      _db.transaction(() async {
        String? clean;
        if (name != null) {
          clean = requireText(name, 'El nombre', max: 40);
          await _ensureUnique(clean, exceptId: id);
        }
        final rows = await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
          TagsCompanion(
            name: Value.absentIfNull(clean),
            colorValue: Value.absentIfNull(colorValue),
            updatedAt: Value(_now()),
          ),
        );
        if (rows == 0) throw NotFoundException('Etiqueta', id);
      });

  Future<void> setArchived(String id, bool archived) async {
    final rows = await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(isArchived: Value(archived), updatedAt: Value(_now())),
    );
    if (rows == 0) throw NotFoundException('Etiqueta', id);
  }

  SimpleSelectStatement<$TagsTable, Tag> _listQuery(bool includeArchived) {
    final q = _db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q;
  }

  Future<List<Tag>> list({bool includeArchived = false}) =>
      _listQuery(includeArchived).get();

  Stream<List<Tag>> watch({bool includeArchived = false}) =>
      _listQuery(includeArchived).watch();

  /// Etiquetas de un movimiento.
  Future<List<Tag>> tagsOf(String transactionId) {
    final q = _db.select(_db.tags).join([
      innerJoin(_db.transactionTags, _db.transactionTags.tagId.equalsExp(_db.tags.id)),
    ])
      ..where(_db.transactionTags.transactionId.equals(transactionId))
      ..orderBy([OrderingTerm.asc(_db.tags.name)]);
    return q.map((row) => row.readTable(_db.tags)).get();
  }

  Future<void> _ensureUnique(String name, {String? exceptId}) async {
    final rows = await _db.customSelect(
      'SELECT 1 FROM tags WHERE name = ? COLLATE NOCASE AND id <> ?',
      variables: [Variable.withString(name), Variable.withString(exceptId ?? '')],
      readsFrom: {_db.tags},
    ).get();
    if (rows.isNotEmpty) throw DuplicateNameException(name);
  }
}
