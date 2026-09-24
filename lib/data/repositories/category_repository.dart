import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'models.dart';
import 'validation.dart';

class CategoryRepository {
  CategoryRepository(this._db, {this._now = DateTime.now});

  final AppDatabase _db;
  final Now _now;

  /// Una subcategoría debe tener el mismo `kind` que su padre. No se ofrece
  /// cambiar el padre, así que no pueden formarse ciclos.
  Future<Category> create(CategoryInput input) => _db.transaction(() async {
        final name = requireText(input.name, 'El nombre');
        if (input.parentId != null) {
          final parent = await get(input.parentId!) ??
              (throw NotFoundException('Categoría', input.parentId!));
          if (parent.kind != input.kind) {
            throw const CategoryKindMismatchException(
                'La subcategoría debe tener el mismo tipo que su categoría padre');
          }
        }
        final n = _now();
        return _db.into(_db.categories).insertReturning(
              CategoriesCompanion.insert(
                name: name,
                kind: input.kind,
                parentId: Value(input.parentId),
                icon: Value(input.icon),
                colorValue: Value(input.colorValue),
                createdAt: Value(n),
                updatedAt: Value(n),
              ),
            );
      });

  Future<void> update(String id, {String? name, String? icon, int? colorValue}) async {
    final rows = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value.absentIfNull(name == null ? null : requireText(name, 'El nombre')),
        icon: Value.absentIfNull(icon),
        colorValue: Value.absentIfNull(colorValue),
        updatedAt: Value(_now()),
      ),
    );
    if (rows == 0) throw NotFoundException('Categoría', id);
  }

  Future<void> setArchived(String id, bool archived) async {
    final rows = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(isArchived: Value(archived), updatedAt: Value(_now())),
    );
    if (rows == 0) throw NotFoundException('Categoría', id);
  }

  Future<Category?> get(String id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$CategoriesTable, Category> _listQuery(
      CategoryKind? kind, bool includeArchived) {
    final q = _db.select(_db.categories)..orderBy([(c) => OrderingTerm.asc(c.name)]);
    q.where((c) {
      Expression<bool> e = const Constant(true);
      if (kind != null) e = e & c.kind.equalsValue(kind);
      if (!includeArchived) e = e & c.isArchived.equals(false);
      return e;
    });
    return q;
  }

  Future<List<Category>> list({CategoryKind? kind, bool includeArchived = false}) =>
      _listQuery(kind, includeArchived).get();

  Stream<List<Category>> watch({CategoryKind? kind, bool includeArchived = false}) =>
      _listQuery(kind, includeArchived).watch();
}
