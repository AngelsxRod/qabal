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

  // El reloj falso marca el martes 1 de septiembre de 2026.
  setUp(() async {
    env = TestEnv(DateTime(2026, 9, 1, 10));
    cash = await env.cash(name: 'Mi caja', initial: 10000);
    bank = await env.bank(name: 'Mi banco', initial: 50000);
  });
  tearDown(() => env.close());

  Future<void> openDetail(WidgetTester tester, Account a) async {
    await pumpApp(tester, env, location: Routes.accounts);
    await tester.tap(find.text(a.name));
    await tester.pumpAndSettle();
  }

  Future<void> seed() async {
    await env.expense(cash.id, 500, DateTime(2026, 9, 1, 9), categoryId: 'default:food');
    await env.income(cash.id, 2000, DateTime(2026, 8, 31), categoryId: 'default:salary');
    await env.transfer(bank.id, cash.id, 3000, DateTime(2026, 8, 20));
  }

  testWidgets('muestra el saldo y los movimientos agrupados por día', (tester) async {
    await seed();
    await openDetail(tester, cash);

    // 100 + 30 (transferencia recibida) + 20 (ingreso) - 5 (gasto).
    expect(find.text('Q145.00'), findsOneWidget);
    expect(find.text('Efectivo · GTQ'), findsOneWidget);

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('jueves 20 ago 2026'), findsOneWidget);

    expect(find.text('Comida'), findsOneWidget);
    expect(inRow('Comida', '-Q5.00'), findsOneWidget);
    expect(inDayHeader('Hoy', '-Q5.00'), findsOneWidget); // total del día
    expect(find.text('Sueldo'), findsOneWidget);
    expect(inRow('Sueldo', '+Q20.00'), findsOneWidget);
    expect(inDayHeader('Ayer', '+Q20.00'), findsOneWidget);
    // La transferencia se ve desde la cuenta: entra dinero, viene del banco.
    expect(find.text('Transferencia'), findsOneWidget);
    expect(find.text('De Mi banco'), findsOneWidget);
    expect(inRow('Transferencia', '+Q30.00'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('la transferencia se ve como salida desde la cuenta origen', (tester) async {
    await seed();
    await openDetail(tester, bank);

    expect(find.text('Q470.00'), findsOneWidget);
    expect(find.text('A Mi caja'), findsOneWidget);
    expect(inRow('Transferencia', '-Q30.00'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('sin movimientos muestra un mensaje en lugar de una lista vacía', (tester) async {
    await openDetail(tester, cash);
    expect(find.text('Esta cuenta aún no tiene movimientos.'), findsOneWidget);
    expect(find.text('Q100.00'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('la lista se actualiza sola al registrar un movimiento', (tester) async {
    await openDetail(tester, cash);
    expect(find.text('Q100.00'), findsOneWidget);

    await env.expense(cash.id, 2500, DateTime(2026, 9, 1), categoryId: 'default:transport');
    await tester.pumpAndSettle();

    expect(find.text('Q75.00'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(inRow('Transporte', '-Q25.00'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('archiva con confirmación y restaura la cuenta', (tester) async {
    await openDetail(tester, cash);
    expect(find.text('Nuevo movimiento'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Archivar cuenta'), findsWidgets); // el diálogo

    // Cancelar no archiva.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await env.accounts.get(cash.id))!.isArchived, isFalse);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archivar'));
    await tester.pumpAndSettle();

    expect((await env.accounts.get(cash.id))!.isArchived, isTrue);
    expect(find.text('Archivada'), findsOneWidget);
    expect(find.text('Nuevo movimiento'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar cuenta'));
    await tester.pumpAndSettle();
    expect((await env.accounts.get(cash.id))!.isArchived, isFalse);
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('el botón Nuevo movimiento abre el formulario con la cuenta elegida', (tester) async {
    await openDetail(tester, cash);
    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo movimiento'), findsOneWidget); // título del formulario
    expect(find.text('Mi caja · Efectivo (GTQ)'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('tocar un movimiento abre su edición', (tester) async {
    await seed();
    await openDetail(tester, cash);
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();

    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(tester.widget<TextField>(field('Monto')).controller!.text, '5.00');
    await unmountApp(tester);
  });

  testWidgets('pagina: al llegar al final carga los movimientos más antiguos', (tester) async {
    for (var i = 1; i <= 45; i++) {
      await env.transactions.create(
        TransactionInput(
          accountId: cash.id,
          type: TransactionType.expense,
          amountMinor: 100,
          occurredAt: DateTime(2026, 7, 1).add(Duration(days: i)),
          note: 'mov ${i.toString().padLeft(2, '0')}',
        ),
      );
    }
    await openDetail(tester, cash);

    // El más reciente está a la vista; el más antiguo queda fuera de la primera
    // página (40), no existe todavía.
    expect(find.text('mov 45'), findsOneWidget);
    expect(find.text('mov 01'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('mov 01'),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    expect(find.text('mov 01'), findsOneWidget);
    await unmountApp(tester);
  });
}
