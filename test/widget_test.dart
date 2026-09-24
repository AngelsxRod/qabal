import 'package:finanzas/app/app.dart';
import 'package:finanzas/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  testWidgets('la app arranca con la barra de 5 pestañas y navega entre ellas', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        nowProvider.overrideWithValue(env.clock.call),
      ],
      retry: (_, _) => null,
      child: const FinanzasApp(),
    ));
    await tester.pumpAndSettle();

    for (final label in ['Inicio', 'Movimientos', 'Cuentas', 'Deudas', 'Más']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
          findsOneWidget);
    }

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Deudas')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Deudas'), findsOneWidget);
  });
}
