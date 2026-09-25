import 'package:finanzas/app/router.dart';
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
}
