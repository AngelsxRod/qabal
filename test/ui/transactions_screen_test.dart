import 'package:finanzas/app/router.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/ui/design/account_chips.dart';
import 'package:finanzas/ui/design/transaction_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  group('primer arranque', () {
    testWidgets('Inicio invita a crear la primera cuenta y lleva al formulario', (tester) async {
      await pumpApp(tester, env);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
      await tester.tap(find.text('Crear mi primera cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva cuenta'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('Movimientos también invita en lugar de mostrar una pantalla vacía', (
      tester,
    ) async {
      await pumpApp(tester, env, location: Routes.transactions);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
      expect(find.text('Nuevo movimiento'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('con cuentas, Inicio ya no muestra la invitación', (tester) async {
      await env.cash();
      await pumpApp(tester, env);

      expect(find.text('Aún no tienes cuentas'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('las tarjetas no cuentan como cuenta usable todavía', (tester) async {
      await env.card();
      await pumpApp(tester, env, location: Routes.accounts);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('lista y filtros', () {
    late Account cash;
    late Account bank;

    setUp(() async {
      cash = await env.cash(name: 'Mi caja', initial: 100000);
      bank = await env.bank(name: 'Mi banco', initial: 100000);
      final tag = await env.tags.create('Viaje');
      await env.expense(cash.id, 500, DateTime(2026, 9, 1), categoryId: 'default:food');
      await env.income(bank.id, 200000, DateTime(2026, 8, 31), categoryId: 'default:salary');
      final trip = await env.expense(
        bank.id,
        7500,
        DateTime(2026, 8, 15),
        categoryId: 'default:transport',
      );
      await env.transactions.setTags(trip.id, {tag.id});
      await env.transfer(bank.id, cash.id, 3000, DateTime(2026, 8, 10));
    });

    testWidgets('sin filtros muestra todo, con la cuenta de cada movimiento', (tester) async {
      await pumpApp(tester, env, location: Routes.transactions);

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Mi banco → Mi caja'), findsOneWidget);
      expect(find.text('Mi caja'), findsOneWidget); // la fila del gasto en efectivo
      // Vista general: las transferencias no suman ni restan.
      expect(inRow('Transferencia', 'Q30.00'), findsOneWidget);
      expect(inRow('Comida', '-Q5.00'), findsOneWidget);
      expect(inRow('Sueldo', '+Q2,000.00'), findsOneWidget);
      // El total del día no cuenta las transferencias.
      expect(inDayHeader('Hoy', '-Q5.00'), findsOneWidget);
      expect(inDayHeader('Ayer', '+Q2,000.00'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('filtra por tipo desde la hoja de filtros y se quita con el chip', (tester) async {
      await pumpApp(tester, env, location: Routes.transactions);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Sueldo'), findsNothing);
      expect(find.text('Transferencia'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Gasto'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // insignia con la cuenta de filtros

      // Quitar el chip restablece la lista completa.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Gasto'),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('combina cuenta y categoría, y limpiar quita todo', (tester) async {
      await pumpApp(tester, env, location: Routes.transactions);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      final cashChip = find.descendant(
        of: find.byType(AccountChips),
        matching: find.text('Mi caja'),
      );
      await tester.ensureVisible(cashChip); // la fila de chips se desplaza
      await tester.pumpAndSettle();
      await tester.tap(cashChip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categoría'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comida').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TransactionRow, 'Comida'), findsOneWidget);
      expect(find.text('Sueldo'), findsNothing);
      expect(find.text('Transporte'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Mi caja'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Comida'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Sueldo'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('filtra por etiqueta', (tester) async {
      await pumpApp(tester, env, location: Routes.transactions);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Comida'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('el rango de fechas (hasta inclusivo) llega en la URL', (tester) async {
      await pumpApp(
        tester,
        env,
        location: '${Routes.transactions}?desde=2026-08-15&hasta=2026-08-31',
      );

      expect(find.text('Sueldo'), findsOneWidget); // 31 ago: el último día cuenta
      expect(find.text('Transporte'), findsOneWidget); // 15 ago: el primer día cuenta
      expect(find.text('Comida'), findsNothing); // 1 sep: fuera
      expect(find.text('Transferencia'), findsNothing); // 10 ago: fuera
      expect(find.widgetWithText(InputChip, '15 ago 2026 – 31 ago 2026'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('filtrar por cuenta muestra las transferencias desde su perspectiva', (
      tester,
    ) async {
      await pumpApp(tester, env, location: '${Routes.transactions}?cuenta=${cash.id}');

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transferencia'), findsOneWidget);
      expect(find.text('De Mi banco'), findsOneWidget);
      expect(inRow('Transferencia', '+Q30.00'), findsOneWidget);
      expect(find.text('Sueldo'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('sin coincidencias explica que ningún movimiento cumple los filtros', (
      tester,
    ) async {
      await pumpApp(tester, env, location: '${Routes.transactions}?desde=2027-01-01');

      expect(find.text('Ningún movimiento coincide con los filtros.'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('los parámetros inválidos de la URL se ignoran', (tester) async {
      await pumpApp(tester, env, location: '${Routes.transactions}?tipo=xx&desde=hoy');

      expect(find.text('Comida'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      await unmountApp(tester);
    });
  });
}
