import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/app/router.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/domain/credit_card/statement_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

/// Escenario real: tarjeta con corte el 21 y pago el 15, hoy 30 sep 2026.
void main() {
  late TestEnv env;

  setUp(() => env = TestEnv(DateTime(2026, 9, 30, 9)));
  tearDown(() => env.close());

  Finder dayField(String label) => field(label);

  group('crear y editar tarjeta', () {
    testWidgets('con corte 21 y pago 15 muestra las próximas fechas y crea la tarjeta', (
      tester,
    ) async {
      await pumpApp(tester, env, location: Routes.accountNew);

      await tester.tap(find.text('Tarjeta de crédito'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'Visa');
      await enterAmount(tester, '500'); // deuda actual
      await enterAmount(tester, '10000', index: 1); // límite
      await tester.enterText(dayField('Día de corte'), '21');
      await tester.enterText(dayField('Día de pago'), '15');
      await tester.enterText(field('Porcentaje de la deuda'), '5');
      await tester.pumpAndSettle();

      // Hoy es 30 sep: el ciclo en curso corta el 21 oct y se paga el 15 nov.
      expect(find.text('Próximo corte: 21 oct · Pago hasta: 15 nov'), findsOneWidget);

      await tester.tap(find.text('Crear tarjeta'));
      await tester.pumpAndSettle();

      final card = (await env.accounts.list()).single;
      expect(card.type, AccountType.creditCard);
      expect(card.initialBalanceMinor, -50000); // la deuda se guarda negativa
      final settings = (await env.accounts.cardSettings(card.id))!;
      expect(settings.creditLimitMinor, 1000000);
      expect(settings.statementDay, 21);
      expect(settings.dueDay, 15);
      expect(settings.minPaymentBp, 500);
      // Cuentas la muestra con lo que debo y el crédito disponible.
      expect(find.text('Debes Q500.00 · disponible Q9,500.00'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('un corte y un pago que coinciden en meses cortos se rechazan bajo los días', (
      tester,
    ) async {
      await pumpApp(tester, env, location: Routes.accountNew);

      await tester.tap(find.text('Tarjeta de crédito'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'Visa');
      await enterAmount(tester, '10000', index: 1);
      await tester.enterText(dayField('Día de corte'), '30');
      await tester.enterText(dayField('Día de pago'), '31');
      await tester.pumpAndSettle();
      // Sin un horario válido no hay vista previa.
      expect(find.textContaining('Próximo corte'), findsNothing);

      await tester.tap(find.text('Crear tarjeta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cae el mismo día del corte o antes'), findsOneWidget);
      expect(await env.accounts.list(), isEmpty);
      await unmountApp(tester);
    });

    testWidgets('el error del nombre se ve aunque el formulario esté desplazado', (tester) async {
      await pumpApp(tester, env, location: Routes.accountNew);
      tester.view.physicalSize = const Size(960, 1920); // 320 × 640 dp
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tarjeta de crédito'));
      await tester.pumpAndSettle();
      await enterAmount(tester, '10000', index: 1);
      await tester.enterText(dayField('Día de corte'), '21');
      await tester.enterText(dayField('Día de pago'), '15');
      await tester.ensureVisible(find.text('PAGO MÍNIMO (OPCIONAL)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear tarjeta'));
      await tester.pumpAndSettle();

      final error = find.text('El nombre no puede estar vacío');
      expect(error, findsOneWidget);
      expect(tester.getTopLeft(error).dy, greaterThan(0));
      expect(tester.getBottomLeft(error).dy, lessThan(640 - 72));
      await unmountApp(tester);
    });

    testWidgets('pide límite y días antes de guardar', (tester) async {
      await pumpApp(tester, env, location: Routes.accountNew);

      await tester.tap(find.text('Tarjeta de crédito'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nombre'), 'Visa');
      await tester.tap(find.text('Crear tarjeta'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el límite de crédito'), findsOneWidget);
      expect(find.textContaining('Escribe el día de corte'), findsOneWidget);
      expect(await env.accounts.list(), isEmpty);
      await unmountApp(tester);
    });

    testWidgets('edita el límite y los días de una tarjeta existente', (tester) async {
      final visa = await env.card(limit: 1000000, statementDay: 21, dueDay: 15, minPaymentBp: 1000);
      await pumpApp(tester, env, location: Routes.accountEdit(visa.id));

      expect(tester.widget<TextField>(dayField('Día de corte')).controller!.text, '21');
      expect(tester.widget<TextField>(field('Porcentaje de la deuda')).controller!.text, '10');
      await enterAmount(tester, '20000', index: 1);
      await tester.enterText(dayField('Día de pago'), '10');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final settings = (await env.accounts.cardSettings(visa.id))!;
      expect(settings.creditLimitMinor, 2000000);
      expect(settings.dueDay, 10);
      expect(settings.statementDay, 21);
      await unmountApp(tester);
    });
  });

  group('escenario de compras', () {
    late Account bank;
    late Account visa;

    setUp(() async {
      bank = await env.bank(initial: 500000);
      visa = await env.card(limit: 1000000, statementDay: 21, dueDay: 15, minPaymentBp: 1000);
      // Q100 (25 ago), Q300 (5 sep), Q200 (18 sep), Q150 (21 sep) y Q400 (22 sep).
      await env.expense(visa.id, 10000, DateTime(2026, 8, 25));
      await env.expense(visa.id, 30000, DateTime(2026, 9, 5));
      await env.expense(visa.id, 20000, DateTime(2026, 9, 18));
      await env.expense(visa.id, 15000, DateTime(2026, 9, 21));
      await env.expense(visa.id, 40000, DateTime(2026, 9, 22));
    });

    Future<CreditCardStatement> officialStatement() => env.cards.registerStatement(
      StatementInput(
        accountId: visa.id,
        closingDate: DateTime(2026, 9, 21),
        statementBalanceMinor: 75000,
        minimumPaymentMinor: 7500,
      ),
    );

    testWidgets('el detalle muestra lo que debo, el disponible y el ciclo en curso', (
      tester,
    ) async {
      await pumpApp(tester, env, location: Routes.accountDetail(visa.id));

      expect(find.text('Debes'), findsOneWidget);
      expect(find.text('Disponible Q8,850.00'), findsOneWidget);
      expect(find.text('Límite Q10,000.00'), findsOneWidget);
      expect(find.text('22 sep – 21 oct 2026'), findsOneWidget);
      expect(find.text('Corte 21 oct'), findsOneWidget);
      expect(find.text('Faltan 21 días'), findsOneWidget);
      expect(find.text('Pago hasta 15 nov'), findsOneWidget);
      // Ciclo: 750 arrastrados + 400 de compras = 1,150 estimados; mínimo 10 %.
      expect(find.text('Deuda arrastrada'), findsOneWidget);
      expect(find.text('Q750.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mínimo estimado'), 200);
      expect(find.text('Estimado al corte'), findsOneWidget);
      expect(find.text('Q11,500.00'), findsNothing); // sanidad: no es 10 veces más
      await unmountApp(tester);
    });

    testWidgets('registra el estado oficial de Q750 y avisa cuando el estimado no coincide', (
      tester,
    ) async {
      await pumpApp(tester, env, location: Routes.statementNew(visa.id));

      // El corte por defecto es el último sin registrar: el 21 de septiembre.
      expect(find.text('21 sep 2026'), findsOneWidget);
      await enterAmount(tester, '750');
      await enterAmount(tester, '75', index: 1);
      await tester.pumpAndSettle();
      expect(
        find.text('La app estima Q750.00 · El banco dice Q750.00 · Diferencia Q0.00'),
        findsOneWidget,
      );

      await enterAmount(tester, '760');
      await tester.pumpAndSettle();
      expect(
        find.text('La app estima Q750.00 · El banco dice Q760.00 · Diferencia +Q10.00'),
        findsOneWidget,
      );
      await enterAmount(tester, '750');
      await tester.tap(find.text('Registrar estado'));
      await tester.pumpAndSettle();

      final saved = (await env.cards.statements(visa.id)).single.statement;
      expect(saved.closingDate, DateTime(2026, 9, 21));
      expect(saved.dueDate, DateTime(2026, 10, 15));
      expect(saved.statementBalanceMinor, 75000);
      expect(saved.minimumPaymentMinor, 7500);
      await unmountApp(tester);
    });

    testWidgets('rechaza un mínimo mayor al saldo bajo su campo', (tester) async {
      await pumpApp(tester, env, location: Routes.statementNew(visa.id));

      await enterAmount(tester, '100');
      await enterAmount(tester, '200', index: 1);
      await tester.tap(find.text('Registrar estado'));
      await tester.pumpAndSettle();

      expect(find.text('El pago mínimo no puede superar el saldo'), findsOneWidget);
      expect(await env.cards.statements(visa.id), isEmpty);
      await unmountApp(tester);
    });

    testWidgets('el detalle del estado muestra pagos vinculados y "Pagar este estado"', (
      tester,
    ) async {
      final s = await officialStatement();
      await env.transfer(bank.id, visa.id, 7500, DateTime(2026, 9, 25));
      await pumpApp(tester, env, location: Routes.statementDetail(visa.id, s.id));

      expect(find.text('Corte 21 sep 2026'), findsOneWidget);
      expect(find.text('Mínimo cubierto'), findsOneWidget);
      expect(find.text('El estimado de la app coincide con el estado del banco.'), findsOneWidget);
      expect(find.text('Pagar este estado'), findsOneWidget);

      await tester.tap(find.text('Pagar este estado'));
      await tester.pumpAndSettle();
      // Llega al formulario con la tarjeta, el estado y lo pendiente ya puestos.
      expect(find.text('Guardar transferencia'), findsOneWidget);
      expect(amountText(tester), '675.00');
      expect(find.text('Corte 21 sep 2026'), findsOneWidget);
      await unmountApp(tester);
    });

    group('pago de tarjeta desde el formulario', () {
      Future<void> openPayment(WidgetTester tester) async {
        await pumpApp(
          tester,
          env,
          location: Routes.transactionNewFor(
            type: TransactionType.transfer,
            destinationId: visa.id,
          ),
        );
        await chooseAccount(tester, 'Banco');
      }

      testWidgets('muestra el estado sugerido y el pago total lo salda', (tester) async {
        final s = await officialStatement();
        await openPayment(tester);

        expect(find.text('ESTADO DE CUENTA'), findsOneWidget);
        expect(find.text('Corte 21 sep 2026'), findsOneWidget);
        expect(find.text('Saldo Q750.00 · pendiente Q750.00 · vence 15 oct'), findsOneWidget);
        await tester.tap(find.text('Pago total Q750.00'));
        await tester.pumpAndSettle();
        expect(amountText(tester), '750.00');
        await tester.tap(find.text('Guardar transferencia'));
        await tester.pumpAndSettle();

        final view = await env.cards.statementView(s.id);
        expect(view.paidMinor, 75000);
        expect(view.status, StatementStatus.paid);
        await unmountApp(tester);
      });

      testWidgets('el pago mínimo deja el estado con el mínimo cubierto', (tester) async {
        final s = await officialStatement();
        await openPayment(tester);

        await tester.tap(find.text('Pago mínimo Q75.00'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar transferencia'));
        await tester.pumpAndSettle();

        final view = await env.cards.statementView(s.id);
        expect(view.paidMinor, 7500);
        expect(view.status, StatementStatus.minimumCovered);
        await unmountApp(tester);
      });

      testWidgets('"No vincular" deja el pago sin estado y el estado vence después del 15 oct', (
        tester,
      ) async {
        final s = await officialStatement();
        await openPayment(tester);

        await tester.ensureVisible(find.text('No vincular (pago adelantado)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No vincular (pago adelantado)'));
        await tester.pumpAndSettle();
        expect(find.text('Sin vincular'), findsOneWidget);
        expect(find.text('Pago total Q750.00'), findsNothing);
        await enterAmount(tester, '100');
        await tester.tap(find.text('Guardar transferencia'));
        await tester.pumpAndSettle();

        final tx = (await env.transactions.list(const TransactionFilter())).first;
        expect(tx.statementId, isNull);
        var view = await env.cards.statementView(s.id);
        expect(view.paidMinor, 0);
        expect(view.status, StatementStatus.pending);

        env.clock.current = DateTime(2026, 10, 16, 9);
        view = await env.cards.statementView(s.id);
        expect(view.status, StatementStatus.overdue);
        await unmountApp(tester);
      });

      testWidgets('"Elegir otro" vincula el pago a un estado anterior', (tester) async {
        final older = await env.cards.registerStatement(
          StatementInput(
            accountId: visa.id,
            closingDate: DateTime(2026, 8, 21),
            statementBalanceMinor: 20000,
            minimumPaymentMinor: 2000,
          ),
        );
        final newer = await officialStatement();
        await openPayment(tester);

        // El sugerido es el de fecha de pago más antigua: el de agosto.
        expect(find.text('Corte 21 ago 2026'), findsOneWidget);
        await tester.ensureVisible(find.text('Elegir otro…'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elegir otro…'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Corte 21 sep 2026').last);
        await tester.pumpAndSettle();
        expect(find.text('Saldo Q750.00 · pendiente Q750.00 · vence 15 oct'), findsOneWidget);

        await enterAmount(tester, '750');
        await tester.tap(find.text('Guardar transferencia'));
        await tester.pumpAndSettle();

        expect((await env.cards.statementView(newer.id)).status, StatementStatus.paid);
        expect((await env.cards.statementView(older.id)).paidMinor, 0);
        await unmountApp(tester);
      });

      testWidgets('sin estados pendientes avisa que el pago no se vinculará', (tester) async {
        await openPayment(tester);

        expect(find.textContaining('no tiene estados de cuenta pendientes'), findsOneWidget);
        expect(find.text('Aplicar al sugerido'), findsNothing);
        await unmountApp(tester);
      });
    });

    group('Próximos pagos en Inicio', () {
      testWidgets('sin tarjetas el bloque no aparece', (tester) async {
        final other = TestEnv(DateTime(2026, 9, 30, 9));
        addTearDown(other.close);
        await other.cash(name: 'Caja');
        await pumpApp(tester, other);

        expect(find.text('PRÓXIMOS PAGOS'), findsNothing);
        await unmountApp(tester);
      });

      testWidgets('lista el estado sin pagar y su resumen, y pasa a Vencido al avanzar el día', (
        tester,
      ) async {
        await officialStatement();
        env.clock.current = DateTime(2026, 10, 14, 22);
        await pumpApp(tester, env);

        expect(find.text('PRÓXIMOS PAGOS'), findsOneWidget);
        expect(find.text('Visa · corte 21 sep'), findsOneWidget);
        expect(find.text('Pago hasta 15 oct · Falta 1 día'), findsOneWidget);
        expect(find.textContaining('Estimado al corte Q1,150.00'), findsOneWidget);
        expect(find.text('Vencido'), findsNothing);

        // Pasa la medianoche del 15 al 16: ya no se puede pagar a tiempo.
        env.clock.current = DateTime(2026, 10, 16, 0, 0, 5);
        await tester.pump(const Duration(hours: 26));
        await tester.pumpAndSettle();
        expect(find.text('Vencido'), findsOneWidget);
        expect(find.text('Venció el 15 oct'), findsOneWidget);
        await unmountApp(tester);
      });

      testWidgets('un estado pagado por completo sale de la lista', (tester) async {
        final s = await officialStatement();
        await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 9, 25));
        await pumpApp(tester, env);

        expect(await env.cards.statementView(s.id).then((v) => v.status), StatementStatus.paid);
        expect(find.text('Visa · corte 21 sep'), findsNothing);
        // El resumen de la tarjeta sigue.
        expect(find.textContaining('Estimado al corte'), findsOneWidget);
        await unmountApp(tester);
      });
    });
  });
}
