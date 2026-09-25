import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  testWidgets('Más lleva a Contactos y a Etiquetas', (tester) async {
    await pumpApp(tester, env, location: Routes.more);

    await tester.tap(find.text('Contactos'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay contactos'), findsOneWidget);
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Etiquetas'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay etiquetas'), findsOneWidget);
    await unmountApp(tester);
  });

  group('contactos', () {
    testWidgets('crea, renombra y archiva un contacto', (tester) async {
      await pumpApp(tester, env, location: Routes.contacts);

      await tester.tap(find.byTooltip('Nuevo contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'Tienda Lupita');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Tienda Lupita'), findsOneWidget);

      await tester.tap(find.text('Tienda Lupita'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'Lupita');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Lupita'), findsOneWidget);
      expect((await env.contacts.list()).single.name, 'Lupita');

      await tester.tap(find.byTooltip('Archivar Lupita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar').last);
      await tester.pumpAndSettle();
      expect(find.text('Lupita'), findsNothing);
      expect(find.text('Todo está archivado'), findsOneWidget);
      expect((await env.contacts.list(includeArchived: true)).single.isArchived, isTrue);
      await unmountApp(tester);
    });

    testWidgets('los archivados se ocultan y se pueden ver y restaurar', (tester) async {
      final a = await env.contacts.create(const ContactInput(name: 'Ana'));
      await env.contacts.create(const ContactInput(name: 'Beto'));
      await env.contacts.setArchived(a.id, true);
      await pumpApp(tester, env, location: Routes.contacts);

      expect(find.text('Ana'), findsNothing);
      expect(find.text('Beto'), findsOneWidget);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar archivados'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Archivado'), findsOneWidget);

      await tester.tap(find.byTooltip('Restaurar Ana'));
      await tester.pumpAndSettle();
      expect(find.text('Archivado'), findsNothing);
      expect((await env.contacts.get(a.id))!.isArchived, isFalse);
      await unmountApp(tester);
    });

    testWidgets('un nombre vacío se rechaza bajo el campo sin cerrar el diálogo', (tester) async {
      await pumpApp(tester, env, location: Routes.contacts);

      await tester.tap(find.byTooltip('Nuevo contacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(errorOf(tester, 'Nombre'), isNotNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await env.contacts.list(), isEmpty);
      await unmountApp(tester);
    });
  });

  group('etiquetas', () {
    testWidgets('crea una etiqueta y rechaza una repetida bajo el campo', (tester) async {
      await env.tags.create('Viaje');
      await pumpApp(tester, env, location: Routes.tags);

      await tester.tap(find.byTooltip('Nueva etiqueta'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'viaje');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(errorOf(tester, 'Nombre'), isNotNull);

      await tester.enterText(field('Nombre'), 'Trabajo');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Trabajo'), findsOneWidget);
      expect(find.text('Viaje'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('archivar cancela sin cambios y, al confirmar, oculta la etiqueta', (tester) async {
      final tag = await env.tags.create('Viaje');
      await pumpApp(tester, env, location: Routes.tags);

      await tester.tap(find.byTooltip('Archivar Viaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje'), findsOneWidget);

      await tester.tap(find.byTooltip('Archivar Viaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar').last);
      await tester.pumpAndSettle();
      expect(find.text('Viaje'), findsNothing);
      expect(await env.tags.list(), isEmpty);
      expect((await env.tags.list(includeArchived: true)).single.id, tag.id);
      await unmountApp(tester);
    });
  });

  group('archivados y el formulario de movimiento', () {
    testWidgets('no se ofrecen al registrar, pero un movimiento existente los conserva', (
      tester,
    ) async {
      final cash = await env.cash(name: 'Caja', initial: 100000);
      final oldContact = await env.contacts.create(const ContactInput(name: 'Antiguo'));
      await env.contacts.create(const ContactInput(name: 'Vigente'));
      final oldTag = await env.tags.create('Vieja');
      await env.tags.create('Nueva');
      final tx = await env.expense(
        cash.id,
        1000,
        DateTime(2026, 9, 1),
        categoryId: 'default:food',
        contactId: oldContact.id,
      );
      await env.transactions.setTags(tx.id, {oldTag.id});
      await env.contacts.setArchived(oldContact.id, true);
      await env.tags.setArchived(oldTag.id, true);

      // Movimiento nuevo: ni el contacto ni la etiqueta archivados.
      await pumpApp(tester, env, location: Routes.transactionNew);
      await openMoreDetails(tester);
      expect(find.text('Nueva'), findsOneWidget);
      expect(find.text('Vieja'), findsNothing);
      await tester.tap(find.text('Ninguno'));
      await tester.pumpAndSettle();
      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('Antiguo'), findsNothing);
      await unmountApp(tester);

      // Al editar el movimiento que los usa, siguen apareciendo.
      await pumpApp(tester, env, location: Routes.transactionEdit(tx.id));
      expect(find.text('Antiguo'), findsOneWidget);
      expect(find.text('Vieja'), findsOneWidget);
      await unmountApp(tester);
    });
  });
}
