import 'dart:async';

import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  group('categorías', () {
    test('crea una categoría y una subcategoría del mismo tipo', () async {
      final parent = await env.categories
          .create(const CategoryInput(name: 'Hogar', kind: CategoryKind.expense));
      final child = await env.categories.create(CategoryInput(
          name: 'Luz', kind: CategoryKind.expense, parentId: parent.id));
      expect(child.parentId, parent.id);
      expect(child.createdAt, DateTime(2026, 9, 1, 10));
    });

    test('rechaza subcategoría de otro tipo y padre inexistente', () async {
      final parent = await env.categories
          .create(const CategoryInput(name: 'Hogar', kind: CategoryKind.expense));
      await expectLater(
          env.categories.create(CategoryInput(
              name: 'Bono', kind: CategoryKind.income, parentId: parent.id)),
          throwsA(isA<CategoryKindMismatchException>()));
      await expectLater(
          env.categories.create(const CategoryInput(
              name: 'X', kind: CategoryKind.expense, parentId: 'nope')),
          throwsA(isA<NotFoundException>()));
    });

    test('update toca updatedAt; archivar oculta del listado; filtra por tipo', () async {
      final c = await env.categories
          .create(const CategoryInput(name: 'Café', kind: CategoryKind.expense));
      env.clock.current = DateTime(2026, 9, 2);
      await env.categories.update(c.id, name: 'Cafetería');
      expect((await env.categories.get(c.id))!.updatedAt, DateTime(2026, 9, 2));
      await env.categories.setArchived(c.id, true);
      final active = await env.categories.list(kind: CategoryKind.expense);
      expect(active.map((x) => x.name), isNot(contains('Cafetería')));
      final withArchived =
          await env.categories.list(kind: CategoryKind.expense, includeArchived: true);
      expect(withArchived.map((x) => x.name), contains('Cafetería'));
      final income = await env.categories.list(kind: CategoryKind.income);
      expect(income.every((x) => x.kind == CategoryKind.income), isTrue);
    });

    test('nombre vacío e inexistente', () async {
      await expectLater(
          env.categories.create(const CategoryInput(name: '', kind: CategoryKind.expense)),
          throwsA(isA<InvalidInputException>()));
      await expectLater(env.categories.setArchived('nope', true),
          throwsA(isA<NotFoundException>()));
    });

    test('watch emite al crear una categoría', () async {
      final it = StreamIterator(env.categories.watch(kind: CategoryKind.expense));
      await it.moveNext();
      final before = it.current.length;
      await env.categories
          .create(const CategoryInput(name: 'Nueva', kind: CategoryKind.expense));
      await it.moveNext();
      expect(it.current.length, before + 1);
      await it.cancel();
    });
  });

  group('contactos', () {
    test('crea, actualiza (updatedAt) y archiva', () async {
      final c = await env.contacts.create(
          const ContactInput(name: 'Mi empresa', type: ContactType.employer));
      expect(c.type, ContactType.employer);
      env.clock.current = DateTime(2026, 9, 3);
      await env.contacts.update(c.id, note: 'Quincena');
      final u = (await env.contacts.get(c.id))!;
      expect(u.note, 'Quincena');
      expect(u.updatedAt, DateTime(2026, 9, 3));
      await env.contacts.setArchived(c.id, true);
      expect(await env.contacts.list(), isEmpty);
      expect(await env.contacts.list(includeArchived: true), hasLength(1));
    });

    test('nombre vacío e inexistente', () async {
      await expectLater(env.contacts.create(const ContactInput(name: '  ')),
          throwsA(isA<InvalidInputException>()));
      await expectLater(
          env.contacts.update('nope', name: 'x'), throwsA(isA<NotFoundException>()));
    });
  });

  group('etiquetas', () {
    test('nombre único sin distinguir mayúsculas', () async {
      final t = await env.tags.create('Viaje');
      await expectLater(env.tags.create('viaje'), throwsA(isA<DuplicateNameException>()));
      await env.tags.create('Casa');
      await expectLater(
          env.tags.update(t.id, name: 'CASA'), throwsA(isA<DuplicateNameException>()));
      // Renombrarse a sí misma (cambiando solo mayúsculas) sí se permite.
      await env.tags.update(t.id, name: 'VIAJE');
      expect((await env.tags.list()).map((x) => x.name), containsAll(['VIAJE', 'Casa']));
    });

    test('tagsOf devuelve las etiquetas del movimiento', () async {
      final a = await env.cash();
      final t1 = await env.tags.create('Comida fuera');
      final t2 = await env.tags.create('Amigos');
      final tx = await env.transactions.create(
        TransactionInput(
            accountId: a.id,
            type: TransactionType.expense,
            amountMinor: 5000,
            occurredAt: DateTime(2026, 9, 3)),
        tagIds: {t1.id, t2.id},
      );
      expect((await env.tags.tagsOf(tx.id)).map((t) => t.name), ['Amigos', 'Comida fuera']);
    });

    test('archivar y actualizar tocan updatedAt', () async {
      final t = await env.tags.create('X');
      env.clock.current = DateTime(2026, 9, 4);
      await env.tags.setArchived(t.id, true);
      expect(await env.tags.list(), isEmpty);
      final all = await env.tags.list(includeArchived: true);
      expect(all.single.updatedAt, DateTime(2026, 9, 4));
      await expectLater(env.tags.update('nope', name: 'y'), throwsA(isA<NotFoundException>()));
    });
  });
}
