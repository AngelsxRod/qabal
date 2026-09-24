import 'package:finanzas/app/app.dart';
import 'package:finanzas/app/providers.dart';
import 'package:finanzas/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_env.dart';

/// Monta la app completa sobre la base en memoria y el reloj falso de [env].
Future<void> pumpApp(WidgetTester tester, TestEnv env, {String location = Routes.home}) async {
  // Pantalla de teléfono, para que los formularios largos quepan sin desplazar
  // más de lo que haría un usuario real.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        nowProvider.overrideWithValue(env.clock.call),
        routerProvider.overrideWith((ref) {
          final router = buildRouter(initialLocation: location);
          ref.onDispose(router.dispose);
          return router;
        }),
      ],
      retry: (_, _) => null,
      child: const FinanzasApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Desmonta la app para que Drift y Riverpod liberen sus temporizadores antes
/// de que `testWidgets` compruebe que no quedan pendientes.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

Finder field(String label) => find.widgetWithText(TextField, label);

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Abre [location] encima de la pantalla actual, como al navegar desde otra
/// pantalla (así el formulario tiene a dónde volver al guardar).
Future<void> pushRoute(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push<void>(location);
  await tester.pumpAndSettle();
}

/// El selector desplegable cuya etiqueta es [label].
Finder dropdown(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
);

/// Elige [option] en el selector [label].
Future<void> pick(WidgetTester tester, String label, String option) async {
  await tester.tap(dropdown(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Texto de error que un campo muestra ahora mismo (nulo si no tiene).
String? errorOf(WidgetTester tester, String label) {
  final decorator = find.ancestor(of: find.text(label), matching: find.byType(InputDecorator));
  return tester.widget<InputDecorator>(decorator.first).decoration.errorText;
}
