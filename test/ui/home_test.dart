import 'package:finanzas/app/router.dart';
import 'package:finanzas/ui/accounts/account_detail_screen.dart';
import 'package:finanzas/ui/design/amount_text.dart';
import 'package:finanzas/ui/design/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  /// Un `AmountText` con ese monto y moneda.
  Finder amount(int minor, String currency) =>
      find.byWidgetPredicate((w) => w is AmountText && w.minor == minor && w.currency == currency);

  testWidgets('Inicio muestra el saldo total de las cuentas activas', (tester) async {
    final cash = await env.cash(name: 'Caja', initial: 10000);
    await env.bank(name: 'Banco', initial: 250050);
    final old = await env.bank(name: 'Vieja', initial: 99900);
    await env.accounts.update(old.id, isArchived: true); // no cuenta
    await env.card(initial: -50000); // la deuda de tarjeta va aparte
    await env.expense(cash.id, 2000, DateTime(2026, 9, 1));
    await pumpApp(tester, env);

    expect(find.text('Saldo total'), findsOneWidget);
    // 100.00 - 20.00 + 2,500.50
    expect(amount(258050, 'GTQ'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('las monedas distintas no se suman: un saldo por moneda', (tester) async {
    await env.cash(name: 'Caja', initial: 10000);
    await env.cash(name: 'Dólares', currency: 'USD', initial: 5000);
    await pumpApp(tester, env);

    // Saldo total, neto y la fila de la cuenta.
    expect(amount(10000, 'GTQ'), findsNWidgets(3));
    expect(amount(5000, 'USD'), findsNWidgets(3));
    await unmountApp(tester);
  });

  testWidgets('los accesos rápidos abren el formulario con el tipo elegido', (tester) async {
    await env.cash(name: 'Caja');
    await pumpApp(tester, env);

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    expect(find.text('Guardar ingreso'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('el botón central "+" abre el formulario de movimiento', (tester) async {
    await env.cash(name: 'Caja');
    await pumpApp(tester, env, location: Routes.accounts);

    await tester.tap(
      find.descendant(of: find.byType(AppBottomBar), matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardar gasto'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('Cuentas también muestra el saldo total arriba', (tester) async {
    await env.cash(name: 'Caja', initial: 10000);
    await env.bank(name: 'Banco', initial: 5000);
    await pumpApp(tester, env, location: Routes.accounts);

    expect(find.text('Saldo total'), findsOneWidget);
    expect(amount(15000, 'GTQ'), findsOneWidget);
    expect(amount(10000, 'GTQ'), findsOneWidget); // fila de la caja
    await unmountApp(tester);
  });

  group('resumen del mes', () {
    /// Ícono de flecha de [MonthSelector] (`Mes anterior` / `Mes siguiente`).
    Finder arrow(String tooltip) =>
        find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

    Future<void> seedTwoMonths() async {
      final cash = await env.cash(name: 'Caja', initial: 100000);
      await env.income(cash.id, 500000, DateTime(2026, 9, 1), categoryId: 'default:salary');
      await env.expense(cash.id, 12000, DateTime(2026, 9, 1), categoryId: 'default:food');
      await env.income(cash.id, 300000, DateTime(2026, 8, 15), categoryId: 'default:salary');
      await env.expense(cash.id, 7500, DateTime(2026, 8, 20), categoryId: 'default:food');
    }

    testWidgets('muestra ingresos y gastos del mes en curso', (tester) async {
      await seedTwoMonths();
      await pumpApp(tester, env);

      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(amount(500000, 'GTQ'), findsOneWidget); // ingresos
      expect(amount(-12000, 'GTQ'), findsOneWidget); // gastos
      expect(find.text('Devoluciones'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('cambia de mes con las flechas y no pasa del mes en curso', (tester) async {
      await seedTwoMonths();
      await pumpApp(tester, env);

      expect(tester.widget<IconButton>(arrow('Mes siguiente')).onPressed, isNull);
      await tester.tap(arrow('Mes anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(amount(300000, 'GTQ'), findsOneWidget);
      expect(amount(-7500, 'GTQ'), findsOneWidget);
      expect(amount(500000, 'GTQ'), findsNothing);

      await tester.tap(arrow('Mes anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Julio 2026'), findsOneWidget);
      expect(find.text('Sin ingresos ni gastos este mes.'), findsOneWidget);

      await tester.tap(arrow('Mes siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(arrow('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(arrow('Mes siguiente')).onPressed, isNull);
      await unmountApp(tester);
    });

    testWidgets('un resumen por moneda, con las devoluciones aparte', (tester) async {
      final cash = await env.cash(name: 'Caja', initial: 100000);
      final usd = await env.cash(name: 'Dólares', currency: 'USD', initial: 5000);
      await env.expense(cash.id, 20000, DateTime(2026, 9, 1), categoryId: 'default:food');
      await env.income(cash.id, 5000, DateTime(2026, 9, 1), categoryId: 'system:refunds');
      await env.income(usd.id, 1000, DateTime(2026, 9, 1), categoryId: 'default:salary');
      await pumpApp(tester, env);

      // Gasto neto: 200.00 - 50.00 de devoluciones.
      expect(amount(-15000, 'GTQ'), findsOneWidget);
      expect(amount(5000, 'GTQ'), findsWidgets);
      expect(find.text('Devoluciones'), findsOneWidget);
      expect(find.text('Ya restadas de los gastos'), findsOneWidget);
      expect(amount(1000, 'USD'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('se actualiza al registrar un movimiento', (tester) async {
      await env.cash(name: 'Caja', initial: 100000);
      await pumpApp(tester, env);
      expect(find.text('Sin ingresos ni gastos este mes.'), findsOneWidget);

      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      await enterAmount(tester, '25.50');
      await chooseAccount(tester, 'Caja');
      await tester.tap(find.text('Guardar gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Sin ingresos ni gastos este mes.'), findsNothing);
      expect(amount(-2550, 'GTQ'), findsOneWidget);
      expect(amount(97450, 'GTQ'), findsNWidgets(3)); // total, neto y la cuenta
      await unmountApp(tester);
    });

    testWidgets('sigue al mes en curso cuando cambia el día', (tester) async {
      env.clock.current = DateTime(2026, 9, 30, 23);
      await env.cash(name: 'Caja', initial: 100000);
      await pumpApp(tester, env);
      expect(find.text('Septiembre 2026'), findsOneWidget);

      env.clock.current = DateTime(2026, 10, 1, 0, 0, 5);
      await tester.pump(const Duration(hours: 1, seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('saldo, tarjetas y cuentas', () {
    testWidgets('muestra la deuda de tarjetas y el neto por moneda', (tester) async {
      await env.cash(name: 'Caja', initial: 100000);
      await env.cash(name: 'Dólares', currency: 'USD', initial: 5000);
      await env.card(initial: -30000);
      await pumpApp(tester, env);
      // Las cuentas quedan más abajo que la tarjeta de Próximos pagos.
      await tester.scrollUntilVisible(find.text('Dólares'), 300);

      expect(find.text('Deuda de tarjetas'), findsNWidgets(2)); // una por moneda
      expect(find.text('Neto'), findsNWidgets(2));
      expect(amount(30000, 'GTQ'), findsOneWidget); // deuda
      expect(amount(70000, 'GTQ'), findsOneWidget); // neto
      expect(amount(100000, 'GTQ'), findsNWidgets(2)); // total y la cuenta
      expect(amount(0, 'USD'), findsOneWidget); // sin deuda en dólares
      expect(amount(5000, 'USD'), findsNWidgets(3));
      await unmountApp(tester);
    });

    testWidgets('las cuentas llevan a su detalle y las archivadas no aparecen', (tester) async {
      await env.cash(name: 'Caja', initial: 100000);
      final old = await env.bank(name: 'Vieja', initial: 500);
      await env.accounts.update(old.id, isArchived: true);
      await pumpApp(tester, env);

      expect(find.text('Vieja'), findsNothing);
      await tester.ensureVisible(find.text('Caja'));
      await tester.tap(find.text('Caja'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailScreen), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('los espacios de próximos pagos y deudas están ocultos', (tester) async {
      await env.cash(name: 'Caja', initial: 100000);
      await pumpApp(tester, env);

      expect(find.text('PRÓXIMOS PAGOS'), findsNothing);
      expect(find.text('TE DEBEN / DEBES'), findsNothing);
      await unmountApp(tester);
    });
  });
}
