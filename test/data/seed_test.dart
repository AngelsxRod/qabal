import 'package:drift/drift.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/database/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<List<Category>> all() => env.db.select(env.db.categories).get();

  test('al crear la base se siembran las categorías por defecto y del sistema', () async {
    final cats = await all();
    final income = cats.where((c) => c.kind == CategoryKind.income).map((c) => c.name);
    final expense = cats.where((c) => c.kind == CategoryKind.expense).map((c) => c.name);
    expect(income, containsAll(['Sueldo', 'Freelance', 'Ventas', 'Intereses ganados',
        'Regalos recibidos', 'Otros ingresos', 'Devoluciones']));
    expect(expense, containsAll(['Comida', 'Supermercado', 'Transporte', 'Servicios', 'Vivienda',
        'Salud', 'Educación', 'Entretenimiento', 'Compras', 'Suscripciones',
        'Regalos y donaciones', 'Otros gastos', 'Intereses y cargos']));
    expect(cats, hasLength(20));
  });

  test('las categorías del sistema tienen id fijo y el tipo correcto', () async {
    final cats = {for (final c in await all()) c.id: c};
    expect(cats[kInterestFeesCategoryId]!.kind, CategoryKind.expense);
    expect(cats[kRefundsCategoryId]!.kind, CategoryKind.income);
    expect(kRefundsCategoryId, 'system:refunds');
  });

  test('es idempotente: repetir el sembrado no duplica', () async {
    await all();
    await seedDefaults(env.db);
    await seedDefaults(env.db);
    await ensureSystemCategories(env.db);
    await ensureSystemCategories(env.db);
    expect(await all(), hasLength(20));
  });

  test('no pisa cambios del usuario (renombrar, archivar)', () async {
    await env.categories.update(kInterestFeesCategoryId, name: 'Comisiones');
    await env.categories.setArchived('default:food', true);
    await seedDefaults(env.db);
    await ensureSystemCategories(env.db);
    final cats = {for (final c in await all()) c.id: c};
    expect(cats[kInterestFeesCategoryId]!.name, 'Comisiones');
    expect(cats['default:food']!.isArchived, isTrue);
    expect(cats, hasLength(20));
  });

  test('ensureSystemCategories repone una categoría del sistema que falte', () async {
    await env.db.customStatement("DELETE FROM categories WHERE id = 'system:refunds'");
    await ensureSystemCategories(env.db);
    expect(
      (await all()).where((c) => c.id == kRefundsCategoryId),
      hasLength(1),
    );
    // No repone las de por defecto.
    await env.db.customStatement("DELETE FROM categories WHERE id = 'default:food'");
    await ensureSystemCategories(env.db);
    expect((await all()).where((c) => c.id == 'default:food'), isEmpty);
  });

  test('ids de sembrado usan insertOrIgnore sobre la misma clave', () async {
    await env.db.into(env.db.categories).insert(
          CategoriesCompanion.insert(
              id: const Value('default:salary'), name: 'Mi sueldo', kind: CategoryKind.income),
          mode: InsertMode.insertOrReplace,
        );
    await seedDefaults(env.db);
    final salary = (await all()).firstWhere((c) => c.id == 'default:salary');
    expect(salary.name, 'Mi sueldo');
  });
}
