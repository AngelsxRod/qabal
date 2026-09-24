import 'package:finanzas/app/router.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/ui/design/account_chips.dart';
import 'package:finanzas/ui/design/amount_input.dart';
import 'package:finanzas/ui/design/picker_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;
  late Account cash;
  late Account bank;

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
  Future<List<Transaction>> all() => env.transactions.list(const TransactionFilter());

  testWidgets('registra un gasto con categoría y nota; el monto se formatea al escribir', (
    tester,
  ) async {
    await openNew(tester);
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    // El monto es lo primero y tiene el foco al abrir.
    expect(tester.widget<TextField>(amountField()).autofocus, isTrue);

    await chooseAccount(tester, 'Mi caja');
    await enterAmount(tester, '1234,50');
    expect(amountText(tester), '1,234.50');
    await chooseCategory(tester, 'Comida');
    await openMoreDetails(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Nota'), 'Almuerzo');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    final tx = (await all()).single;
    expect(tx.type, TransactionType.expense);
    expect(tx.accountId, cash.id);
    expect(tx.amountMinor, 123450);
    expect(tx.categoryId, 'default:food');
    expect(tx.note, 'Almuerzo');
    expect(tx.occurredAt, DateTime(2026, 9, 1));
    expect(await balanceOf(cash), 10000 - 123450);
    // Volvió a la pantalla anterior.
    expect(find.text('Guardar gasto'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('la última cuenta usada va primero y viene preseleccionada', (tester) async {
    await env.expense(bank.id, 100, DateTime(2026, 8, 30));
    await openNew(tester);

    final chipsFinder = find.byType(AccountChips);
    final bankX = tester
        .getTopLeft(find.descendant(of: chipsFinder, matching: find.text('Mi banco')))
        .dx;
    final cashX = tester
        .getTopLeft(find.descendant(of: chipsFinder, matching: find.text('Mi caja')))
        .dx;
    expect(bankX, lessThan(cashX)); // aunque "Mi caja" gane alfabéticamente

    // Sin elegir cuenta, el gasto se registra en la última usada.
    await enterAmount(tester, '5');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect((await all()).first.accountId, bank.id);
    await unmountApp(tester);
  });

  testWidgets('sin movimientos previos no hay cuenta preseleccionada', (tester) async {
    await openNew(tester);
    await enterAmount(tester, '5');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(chipsError('Elige una cuenta'), findsOneWidget);
    expect(await all(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('un ingreso ofrece categorías de ingreso y rotula el contacto como Fuente', (
    tester,
  ) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.income);

    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
    await tester.tap(find.text('Sueldo'));
    await tester.pumpAndSettle();

    await openMoreDetails(tester);
    expect(find.text('Fuente'), findsOneWidget);
    expect(find.text('Contacto'), findsNothing);

    // Crea la fuente al vuelo desde la hoja de contactos.
    await tester.tap(find.text('Fuente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo contacto…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Empresa SA');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Empresa SA'), findsOneWidget);

    await enterAmount(tester, '3,500.00');
    expect(amountText(tester), '3,500.00');
    await tester.tap(find.text('Guardar ingreso'));
    await tester.pumpAndSettle();

    final tx = (await all()).single;
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
    await chooseCategory(tester, 'Comida');
    expect(find.text('Comida'), findsOneWidget);

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsNothing);
    expect(find.text('Elegir categoría'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('registra una transferencia entre cuentas y los saldos cuadran', (tester) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.transfer);

    // Una transferencia no lleva categoría ni contacto.
    expect(find.byType(PickerRow), findsOneWidget); // solo la fecha
    expect(find.text('Categoría'), findsNothing);
    await openMoreDetails(tester);
    expect(find.text('Contacto'), findsNothing);
    expect(find.text('Fuente'), findsNothing);

    // El origen no se ofrece como destino.
    expect(
      find.descendant(of: find.byType(AccountChips).at(1), matching: find.text('Mi banco')),
      findsNothing,
    );
    await chooseAccount(tester, 'Mi caja', group: 1);

    await enterAmount(tester, '300');
    // Misma moneda: no pide monto de llegada.
    expect(find.text('Monto que llega'), findsNothing);
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    final tx = (await all()).single;
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

    await chooseAccount(tester, 'Dólares', group: 1);
    expect(find.text('Monto que llega'), findsOneWidget);

    await enterAmount(tester, '780');
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();
    // Falta el monto que llega: el error queda en ese campo y no se guarda.
    expect(errorIn(find.byType(AmountInput).at(1), 'Escribe el monto que llega'), findsOneWidget);
    expect(errorIn(find.byType(AmountInput).at(0), 'Escribe el monto que llega'), findsNothing);
    expect(await all(), isEmpty);

    await enterAmount(tester, '100', index: 1);
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    final tx = (await all()).single;
    expect(tx.amountMinor, 78000);
    expect(tx.transferAmountMinor, 10000);
    expect(await balanceOf(usd), 10000);
    await unmountApp(tester);
  });

  testWidgets('cada error de validación aparece bajo su campo', (tester) async {
    await openNew(tester);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(chipsError('Elige una cuenta'), findsOneWidget);
    expect(errorIn(find.byType(AmountInput).first, 'Escribe un monto'), findsOneWidget);

    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();
    expect(chipsError('Elige la cuenta destino', group: 1), findsOneWidget);
    expect(chipsError('Elige la cuenta destino', group: 0), findsNothing);
    expect(await all(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('un monto en cero lo rechaza el dominio y el error queda en el monto', (
    tester,
  ) async {
    await openNew(tester, accountId: cash.id);
    await enterAmount(tester, '0');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(
      errorIn(find.byType(AmountInput).first, 'El monto debe ser mayor que cero'),
      findsOneWidget,
    );
    expect(find.textContaining('Elige una cuenta'), findsNothing);
    expect(await all(), isEmpty);

    await enterAmount(tester, '5');
    expect(find.text('El monto debe ser mayor que cero'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('una cuenta archivada mientras se llena el formulario marca las cuentas', (
    tester,
  ) async {
    await openNew(tester);
    await chooseAccount(tester, 'Mi caja');
    await enterAmount(tester, '10');

    // La cuenta se archiva por otro lado antes de guardar.
    await env.accounts.update(cash.id, isArchived: true);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AccountChips).first,
        matching: find.textContaining('archivada'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AmountInput), matching: find.textContaining('archivada')),
      findsNothing,
    );
    expect(await all(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('una cuenta destino archivada marca el destino, no el origen', (tester) async {
    await openNew(tester, accountId: bank.id, type: TransactionType.transfer);
    await chooseAccount(tester, 'Mi caja', group: 1);
    await enterAmount(tester, '10');

    await env.accounts.update(cash.id, isArchived: true);
    await tester.tap(find.text('Guardar transferencia'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AccountChips).at(1),
        matching: find.textContaining('archivada'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AccountChips).at(0),
        matching: find.textContaining('archivada'),
      ),
      findsNothing,
    );
    await unmountApp(tester);
  });

  testWidgets('las cuentas archivadas no se ofrecen para movimientos nuevos', (tester) async {
    await env.accounts.update(bank.id, isArchived: true);
    await openNew(tester);

    final chips = find.byType(AccountChips);
    expect(find.descendant(of: chips, matching: find.text('Mi caja')), findsOneWidget);
    expect(find.descendant(of: chips, matching: find.text('Mi banco')), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('sin cuentas invita a crear una en lugar de mostrar un formulario vacío', (
    tester,
  ) async {
    // Una base aparte, sin ninguna cuenta.
    final empty = TestEnv(DateTime(2026, 9, 1, 10));
    addTearDown(empty.close);
    await pumpApp(tester, empty, location: Routes.transactions);
    await pushRoute(tester, Routes.transactionNew);

    expect(find.text('Primero crea una cuenta'), findsOneWidget);
    expect(find.text('Guardar gasto'), findsNothing);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);
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
      expect(amountText(tester), '25.00');
      expect(tester.widget<TextField>(amountField()).autofocus, isFalse);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('30 ago 2026'), findsOneWidget);
      // Tiene nota y etiqueta: "Más detalles" ya viene desplegado.
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Nota')).controller!.text,
        'Taxi',
      );
      expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);

      await enterAmount(tester, '31.75');
      await chooseCategory(tester, 'Comida');
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

    testWidgets('la fecha de hoy y de ayer se muestran con su nombre', (tester) async {
      final today = await env.expense(cash.id, 100, DateTime(2026, 9, 1));
      final yesterday = await env.expense(cash.id, 100, DateTime(2026, 8, 31));
      await pumpApp(tester, env, location: Routes.transactions);

      await pushRoute(tester, Routes.transactionEdit(today.id));
      expect(find.text('Hoy'), findsOneWidget);
      await unmountApp(tester);

      await pumpApp(tester, env, location: Routes.transactions);
      await pushRoute(tester, Routes.transactionEdit(yesterday.id));
      expect(find.text('Ayer'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('permite cambiar el tipo a transferencia', (tester) async {
      await openEdit(tester);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await chooseAccount(tester, 'Mi banco', group: 1);
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
      await openMoreDetails(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nota'), 'Con nota');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final updated = (await env.transactions.get(origin.id))!;
      expect(updated.debtId, debt.id);
      expect(updated.note, 'Con nota');
      await unmountApp(tester);
    });
  });
}
