import 'package:finanzas/ui/design/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  testWidgets('la app arranca con 4 pestañas y un botón central para registrar', (tester) async {
    await pumpApp(tester, env);

    for (final label in ['Inicio', 'Historial', 'Cuentas', 'Más']) {
      expect(navItem(label), findsOneWidget, reason: label);
    }
    expect(navItem('Deudas'), findsNothing);
    expect(find.byTooltip('Nuevo movimiento'), findsNothing);
    expect(find.bySemanticsLabel('Nuevo movimiento'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('navega entre las pestañas', (tester) async {
    await pumpApp(tester, env);

    await tester.tap(navItem('Historial'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);

    await tester.tap(navItem('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);

    await tester.tap(navItem('Más'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Más'), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
    await unmountApp(tester);
  });
}
