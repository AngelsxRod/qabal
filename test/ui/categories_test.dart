import 'package:finanzas/data/database/seed.dart';
import 'package:finanzas/app/providers.dart';
import 'package:finanzas/app/router.dart';
import 'package:finanzas/ui/categories/category_order.dart';
import 'package:finanzas/ui/design/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  Future<Category> byName(String name) async =>
      (await env.categories.list(includeArchived: true)).firstWhere((c) => c.name == name);

  Future<void> createCategory(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombre'), name);
    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();
  }

  testWidgets('Más lleva a Categorías, que separa gastos de ingresos', (tester) async {
    await pumpApp(tester, env, location: Routes.more);

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Sueldo'), findsNothing);

    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();
    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('crea una categoría con ícono y color elegidos', (tester) async {
    await pumpApp(tester, env, location: Routes.categories);

    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombre'), 'Mascotas');
    await tester.tap(find.bySemanticsLabel('Ícono pets'));
    await tester.tap(find.bySemanticsLabel('Color 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();

    expect(find.text('Mascotas'), findsOneWidget);
    final saved = await byName('Mascotas');
    expect(saved.kind, CategoryKind.expense);
    expect(saved.icon, 'pets');
    expect(saved.colorValue, categoryColorChoices[2].toARGB32());
    await unmountApp(tester);
  });

  testWidgets('crea una categoría de ingreso y rechaza un nombre vacío bajo el campo', (
    tester,
  ) async {
    await pumpApp(tester, env, location: Routes.categories);

    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();
    expect(errorOf(tester, 'Nombre'), isNotNull);

    await tester.tap(find.text('Ingreso'));
    await tester.enterText(field('Nombre'), 'Alquiler cobrado');
    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();

    expect((await byName('Alquiler cobrado')).kind, CategoryKind.income);
    await unmountApp(tester);
  });

  testWidgets('renombra una categoría', (tester) async {
    await pumpApp(tester, env, location: Routes.categories);

    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombre'), 'Restaurantes');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Restaurantes'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
    expect((await env.categories.get('default:food'))!.name, 'Restaurantes');
    await unmountApp(tester);
  });

  testWidgets('archiva una categoría: sale de la lista y del formulario, y se puede restaurar', (
    tester,
  ) async {
    await pumpApp(tester, env, location: Routes.categories);
    await createCategory(tester, 'Mascotas');

    await tester.tap(find.text('Mascotas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archivar categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar').last);
    await tester.pumpAndSettle();

    expect(find.text('Mascotas'), findsNothing);
    expect((await byName('Mascotas')).isArchived, isTrue);

    // No se ofrece al registrar un gasto.
    await env.cash(name: 'Caja');
    await pushRoute(tester, Routes.transactionNew);
    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Mascotas'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // cierra la hoja
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    // Se ve al pedir las archivadas y se restaura.
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar archivadas'));
    await tester.pumpAndSettle();
    expect(find.text('Archivada'), findsOneWidget);
    await tester.tap(find.text('Mascotas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restaurar categoría'));
    await tester.pumpAndSettle();
    expect((await byName('Mascotas')).isArchived, isFalse);
    await unmountApp(tester);
  });

  testWidgets('un movimiento con una categoría archivada la sigue mostrando al editarlo', (
    tester,
  ) async {
    final cash = await env.cash(name: 'Caja', initial: 100000);
    final tx = await env.expense(cash.id, 1000, DateTime(2026, 9, 1), categoryId: 'default:food');
    await env.categories.setArchived('default:food', true);
    await pumpApp(tester, env, location: Routes.transactionEdit(tx.id));

    expect(find.text('Comida'), findsOneWidget);
    await unmountApp(tester);
  });

  group('categorías del sistema', () {
    testWidgets('no se pueden renombrar ni archivar', (tester) async {
      await pumpApp(tester, env, location: Routes.categories);

      expect(find.text('Del sistema'), findsOneWidget);
      await tester.tap(find.text('Intereses y cargos'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field('Nombre')).enabled, isFalse);
      expect(find.byTooltip('Archivar categoría'), findsNothing);
      expect(find.textContaining('no se puede renombrar'), findsOneWidget);

      // Sí se puede cambiar el aspecto; el nombre no se toca.
      await tester.tap(find.bySemanticsLabel('Color 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final saved = (await env.categories.get(kInterestFeesCategoryId))!;
      expect(saved.name, 'Intereses y cargos');
      expect(saved.isArchived, isFalse);
      expect(saved.colorValue, categoryColorChoices[4].toARGB32());
      await unmountApp(tester);
    });

    testWidgets('no admiten subcategorías', (tester) async {
      await pumpApp(tester, env, location: Routes.categories);

      expect(find.byTooltip('Agregar subcategoría a Intereses y cargos'), findsNothing);
      expect(find.byTooltip('Agregar subcategoría a Comida'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('subcategorías', () {
    testWidgets('se crean desde el padre y se rotulan "Padre › Hijo" en el selector', (
      tester,
    ) async {
      await env.cash(name: 'Caja');
      await pumpApp(tester, env, location: Routes.categories);

      await tester.tap(find.byTooltip('Agregar subcategoría a Comida'));
      await tester.pumpAndSettle();
      expect(find.text('Subcategoría de Comida'), findsOneWidget);
      await tester.enterText(field('Nombre'), 'Café');
      await tester.tap(find.text('Crear categoría'));
      await tester.pumpAndSettle();

      final sub = await byName('Café');
      expect(sub.parentId, 'default:food');
      expect(sub.kind, CategoryKind.expense);
      expect(find.text('Café'), findsOneWidget);
      // Una subcategoría no ofrece más subcategorías.
      expect(find.byTooltip('Agregar subcategoría a Café'), findsNothing);

      await pushRoute(tester, Routes.transactionNew);
      await tester.tap(find.text('Categoría'));
      await tester.pumpAndSettle();
      expect(find.text('Comida › Café'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('archivar la categoría padre archiva sus subcategorías', (tester) async {
      final sub = await env.categories.create(
        const CategoryInput(name: 'Café', kind: CategoryKind.expense, parentId: 'default:food'),
      );
      await pumpApp(tester, env, location: Routes.categories);

      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Archivar categoría'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sus subcategorías'), findsOneWidget);
      await tester.tap(find.text('Archivar').last);
      await tester.pumpAndSettle();

      expect((await env.categories.get('default:food'))!.isArchived, isTrue);
      expect((await env.categories.get(sub.id))!.isArchived, isTrue);
      expect(find.text('Café'), findsNothing);
      await unmountApp(tester);
    });
  });

  test('orderForPicker pone cada subcategoría tras su padre', () async {
    final food = await env.categories.create(
      const CategoryInput(name: 'Comida', kind: CategoryKind.expense),
    );
    final cafe = await env.categories.create(
      CategoryInput(name: 'Café', kind: CategoryKind.expense, parentId: food.id),
    );
    final auto = await env.categories.create(
      const CategoryInput(name: 'Auto', kind: CategoryKind.expense),
    );
    final orphan = await env.categories.create(
      const CategoryInput(name: 'Zeta', kind: CategoryKind.expense),
    );

    final ordered = orderForPicker([cafe, orphan, food, auto]);
    expect(ordered.map((c) => c.name), ['Auto', 'Comida', 'Café', 'Zeta']);
    // Sin el padre en la lista, la subcategoría pasa a primer nivel.
    expect(orderForPicker([cafe, auto]).map((c) => c.name), ['Auto', 'Café']);
  });
}
