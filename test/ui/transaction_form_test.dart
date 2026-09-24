import 'package:finanzas/app/router.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;
  late Account cash;
  late Account bank;

  const cashLabel = 'Mi caja · Efectivo (GTQ)';
  const bankLabel = 'Mi banco · Cuenta bancaria (GTQ)';

  setUp(() async {
    env = TestEnv(DateTime(2026, 9, 1, 10));
    cash = await env.cash(name: 'Mi caja', initial: 10000);
    bank = await env.bank(name: 'Mi banco', initial: 50000);
  });
  tearDown(() => env.close());

  Future<void> openNew(WidgetTester tester, {String? accountId, TransactionType? type}) async {
    await pumpApp(tester, env, location: Routes.transactions);
    await pushRoute(tester, Routes.transactionNewFor(accountId: accountId, type: type));
  }

  Future<int> balanceOf(Account a) async => (await env.accounts.balance(a.id)).balanceMinor;

  testWidgets('registra un gasto con categoría, nota y coma decimal', (tester) async {
    await openNew(tester);
    expect(find.text('Nuevo movimiento'), findsOneWidget);

    await pick(tester, 'Cuenta', cashLabel);
    await tester.enterText(field('Monto'), '45,50');
    await pick(tester, 'Categoría', 'Comida');
    await tester.enterText(field('Nota'), 'Almuerzo');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    final tx = (await env.transactions.list(const TransactionFilter())).single;
    expect(tx.type, TransactionType.expense);
    expect(tx.accountId, cash.id);
    expect(tx.amountMinor, 4550);
    expect(tx.categoryId, 'default:food');
    expect(tx.note, 'Almuerzo');
    expect(tx.occurredAt, DateTime(2026, 9, 1));
    expect(await balanceOf(cash), 10000 - 4550);
    // Volvió a la pantalla anterior.
    expect(find.text('Guardar gasto'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('un ingreso ofrece categorías de ingreso y rotula el contacto como Fuente', (
    tester,
  ) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.income);

    expect(find.text('Fuente'), findsOneWidget);
    expect(find.text('Contacto'), findsNothing);

    await tester.tap(dropdown('Categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
    await tester.tap(find.text('Sueldo'));
    await tester.pumpAndSettle();

    // Crea la fuente al vuelo.
    await pick(tester, 'Fuente', 'Nuevo contacto…');
    await tester.enterText(find.byType(TextField).last, 'Empresa SA');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Monto'), '3,500.00');
    await tester.tap(find.text('Guardar ingreso'));
    await tester.pumpAndSettle();

    final tx = (await env.transactions.list(const TransactionFilter())).single;
    expect(tx.type, TransactionType.income);
    expect(tx.accountId, bank.id);
    expect(tx.amountMinor, 350000);
    expect(tx.categoryId, 'default:salary');
    final contact = (await env.contacts.list()).single;
    expect(contact.name, 'Empresa SA');
    expect(tx.contactId, contact.id);
    expect(await balanceOf(bank), 50000 + 350000);
    await unmountApp(tester);
  });

  testWidgets('al pasar de gasto a ingreso se descarta la categoría que ya no aplica', (
    tester,
  ) async {
    await openNew(tester, accountId: cash.id);
    await pick(tester, 'Categoría', 'Comida');

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsNothing);
    expect(find.text('Sin categoría'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('registra una transferencia entre cuentas y los saldos cuadran', (tester) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.transfer);

    // Una transferencia no lleva categoría ni contacto.
    expect(find.text('Categoría'), findsNothing);
    expect(find.text('Contacto'), findsNothing);
    expect(find.text('Fuente'), findsNothing);

    await pick(tester, 'Cuenta destino', cashLabel);
    // El origen ya no se ofrece como destino.
    await tester.tap(dropdown('Cuenta destino'));
    await tester.pumpAndSettle();
    expect(find.text(bankLabel), findsOneWidget); // solo el origen elegido
    await tester.tap(find.text(cashLabel).last);
    await tester.pumpAndSettle();

    await tester.enterText(field('Monto'), '300');
    // Misma moneda: no pide monto de llegada.
    expect(find.text('Monto que llega'), findsNothing);
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    final tx = (await env.transactions.list(const TransactionFilter())).single;
    expect(tx.type, TransactionType.transfer);
    expect(tx.accountId, bank.id);
    expect(tx.transferAccountId, cash.id);
    expect(tx.amountMinor, 30000);
    expect(tx.transferAmountMinor, isNull);
    expect(await balanceOf(bank), 50000 - 30000);
    expect(await balanceOf(cash), 10000 + 30000);
    await unmountApp(tester);
  });

  testWidgets('transferencia entre monedas distintas pide el monto que llega', (tester) async {
    final usd = await env.cash(name: 'Dólares', currency: 'USD');
    await openNew(tester, accountId: bank.id, type: TransactionType.transfer);

    await pick(tester, 'Cuenta destino', 'Dólares · Efectivo (USD)');
    expect(find.text('Monto que llega'), findsOneWidget);

    await tester.enterText(field('Monto'), '780');
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();
    // Falta el monto que llega: el error queda en ese campo y no se guarda.
    expect(errorOf(tester, 'Monto que llega'), 'Escribe el monto que llega');
    expect(await env.transactions.list(const TransactionFilter()), isEmpty);

    await tester.enterText(field('Monto que llega'), '100');
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    final tx = (await env.transactions.list(const TransactionFilter())).single;
    expect(tx.amountMinor, 78000);
    expect(tx.transferAmountMinor, 10000);
    expect(await balanceOf(usd), 10000);
    await unmountApp(tester);
  });

  testWidgets('validaciones del formulario: cuenta, monto y destino obligatorios', (tester) async {
    await openNew(tester);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(errorOf(tester, 'Cuenta'), 'Elige una cuenta');
    expect(errorOf(tester, 'Monto'), 'Escribe un monto');

    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();
    expect(errorOf(tester, 'Cuenta destino'), 'Elige la cuenta destino');

    await tester.enterText(field('Monto'), '1,234');
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();
    expect(errorOf(tester, 'Monto'), contains('Monto inválido'));
    expect(await env.transactions.list(const TransactionFilter()), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('un monto en cero lo rechaza el dominio y el error queda en Monto', (tester) async {
    await openNew(tester, accountId: cash.id);
    await tester.enterText(field('Monto'), '0');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(errorOf(tester, 'Monto'), 'El monto debe ser mayor que cero');
    expect(errorOf(tester, 'Cuenta'), isNull);
    expect(await env.transactions.list(const TransactionFilter()), isEmpty);

    await tester.enterText(field('Monto'), '5');
    await tester.pump();
    expect(errorOf(tester, 'Monto'), isNull);
    await unmountApp(tester);
  });

  testWidgets('una cuenta archivada mientras se llena el formulario marca el campo Cuenta', (
    tester,
  ) async {
    await openNew(tester);
    await pick(tester, 'Cuenta', cashLabel);
    await tester.enterText(field('Monto'), '10');

    // La cuenta se archiva por otro lado antes de guardar.
    await env.accounts.update(cash.id, isArchived: true);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(errorOf(tester, 'Cuenta'), contains('archivada'));
    expect(errorOf(tester, 'Monto'), isNull);
    expect(await env.transactions.list(const TransactionFilter()), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('una cuenta destino archivada marca el campo Cuenta destino', (tester) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.transfer);
    await pick(tester, 'Cuenta destino', cashLabel);
    await tester.enterText(field('Monto'), '10');

    await env.accounts.update(cash.id, isArchived: true);
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    expect(errorOf(tester, 'Cuenta destino'), contains('archivada'));
    expect(errorOf(tester, 'Cuenta origen'), isNull);
    await unmountApp(tester);
  });

  testWidgets('las cuentas archivadas no se ofrecen para movimientos nuevos', (tester) async {
    await env.accounts.update(bank.id, isArchived: true);
    await openNew(tester);

    await tester.tap(dropdown('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text(cashLabel), findsOneWidget);
    expect(find.text(bankLabel), findsNothing);
    await unmountApp(tester);
  });

  group('edición', () {
    late Transaction tx;

    setUp(() async {
      final tag = await env.tags.create('Trabajo');
      tx = await env.transactions.create(
        TransactionInput(
          accountId: cash.id,
          type: TransactionType.expense,
          amountMinor: 2500,
          occurredAt: DateTime(2026, 8, 30, 14, 30),
          categoryId: 'default:transport',
          note: 'Taxi',
        ),
        tagIds: {tag.id},
      );
    });

    Future<void> openEdit(WidgetTester tester) async {
      await pumpApp(tester, env, location: Routes.transactions);
      await pushRoute(tester, Routes.transactionEdit(tx.id));
    }

    testWidgets('muestra los datos actuales y guarda los cambios', (tester) async {
      await openEdit(tester);

      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(tester.widget<TextField>(field('Monto')).controller!.text, '25.00');
      expect(tester.widget<TextField>(field('Nota')).controller!.text, 'Taxi');
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('30 ago 2026'), findsOneWidget);
      expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);

      await tester.enterText(field('Monto'), '31.75');
      await pick(tester, 'Categoría', 'Comida');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final updated = (await env.transactions.get(tx.id))!;
      expect(updated.amountMinor, 3175);
      expect(updated.categoryId, 'default:food');
      expect(updated.note, 'Taxi');
      // La hora no cambia si no se toca la fecha.
      expect(updated.occurredAt, DateTime(2026, 8, 30, 14, 30));
      expect((await env.tags.tagsOf(tx.id)).map((t) => t.name), ['Trabajo']);
      expect(await balanceOf(cash), 10000 - 3175);
      await unmountApp(tester);
    });

    testWidgets('permite cambiar el tipo a transferencia', (tester) async {
      await openEdit(tester);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await pick(tester, 'Cuenta destino', bankLabel);
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final updated = (await env.transactions.get(tx.id))!;
      expect(updated.type, TransactionType.transfer);
      expect(updated.transferAccountId, bank.id);
      expect(updated.categoryId, isNull);
      await unmountApp(tester);
    });

    testWidgets('eliminar pide confirmación y respeta Cancelar', (tester) async {
      await openEdit(tester);

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar movimiento'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await env.transactions.get(tx.id), isNotNull);
      expect(find.text('Editar movimiento'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('eliminar confirmado borra el movimiento y recalcula el saldo', (tester) async {
      await openEdit(tester);
      expect(await balanceOf(cash), 10000 - 2500);

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(await env.transactions.get(tx.id), isNull);
      expect(await balanceOf(cash), 10000);
      expect(find.text('Editar movimiento'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('editar conserva la deuda del movimiento', (tester) async {
      final ana = await env.contact('Ana');
      final debt = await env.debts.create(
        DebtInput(
          contactId: ana.id,
          direction: DebtDirection.owedToMe,
          principalMinor: 5000,
          currency: 'GTQ',
          description: 'Préstamo',
          startDate: DateTime(2026, 9, 1),
        ),
        originAccountId: cash.id,
      );
      final origin = (await env.transactions.list(TransactionFilter(debtId: debt.id))).single;
      await pumpApp(tester, env, location: Routes.transactions);
      await pushRoute(tester, Routes.transactionEdit(origin.id));

      // Los movimientos de deuda no llevan categoría.
      expect(find.text('Categoría'), findsNothing);
      await tester.enterText(field('Nota'), 'Con nota');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final updated = (await env.transactions.get(origin.id))!;
      expect(updated.debtId, debt.id);
      expect(updated.note, 'Con nota');
      await unmountApp(tester);
    });
  });
}
