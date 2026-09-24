import 'package:finanzas/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  testWidgets('primer arranque: invita a crear la primera cuenta', (tester) async {
    await pumpApp(tester, env, location: '/cuentas');

    expect(find.text('Aún no tienes cuentas'), findsOneWidget);
    expect(find.text('Crear mi primera cuenta'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('crea una cuenta de efectivo con saldo inicial desde la invitación',
      (tester) async {
    await pumpApp(tester, env, location: '/cuentas');

    await tester.tap(find.text('Crear mi primera cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);

    await tester.enterText(field('Nombre'), 'Billetera');
    await tester.enterText(field('Saldo inicial'), '150.50');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Billetera'), findsOneWidget);
    expect(find.text('Q150.50'), findsOneWidget);
    expect(find.text('Aún no tienes cuentas'), findsNothing);

    final saved = (await env.accounts.list()).single;
    expect(saved.name, 'Billetera');
    expect(saved.type, AccountType.cash);
    expect(saved.currency, 'GTQ');
    expect(saved.initialBalanceMinor, 15050);
    await unmountApp(tester);
  });

  testWidgets('acepta la coma como decimal en el saldo inicial', (tester) async {
    await pumpApp(tester, env, location: '/cuentas/nueva');

    await tester.enterText(field('Nombre'), 'Banco');
    await tester.enterText(field('Saldo inicial'), '1234,50');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect((await env.accounts.list()).single.initialBalanceMinor, 123450);
    await unmountApp(tester);
  });

  testWidgets('el tipo tarjeta de crédito aparece deshabilitado como Próximamente',
      (tester) async {
    await pumpApp(tester, env, location: '/cuentas/nueva');

    await tester.tap(find.text('Efectivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta de crédito · Próximamente'));
    await tester.pumpAndSettle();

    // La opción deshabilitada no se elige: el menú sigue abierto.
    expect(find.text('Tarjeta de crédito · Próximamente'), findsOneWidget);

    // Se puede elegir otro tipo normal.
    await tester.tap(find.text('Cuenta bancaria'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombre'), 'Banrural');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect((await env.accounts.list()).single.type, AccountType.bank);
    await unmountApp(tester);
  });

  testWidgets('un error de dominio del nombre se muestra en el campo Nombre', (tester) async {
    await pumpApp(tester, env, location: '/cuentas/nueva');

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // El repositorio rechaza el nombre vacío; el error queda bajo "Nombre".
    expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    final nameField = tester.widget<TextField>(field('Nombre'));
    expect(nameField.decoration!.errorText, 'El nombre no puede estar vacío');
    expect(await env.accounts.list(), isEmpty);

    // Al escribir de nuevo, el error desaparece.
    await tester.enterText(field('Nombre'), 'Caja');
    await tester.pump();
    expect(find.text('El nombre no puede estar vacío'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('un saldo ambiguo se rechaza en el campo Saldo inicial', (tester) async {
    await pumpApp(tester, env, location: '/cuentas/nueva');

    await tester.enterText(field('Nombre'), 'Caja');
    await tester.enterText(field('Saldo inicial'), '1,234');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    final balance = tester.widget<TextField>(field('Saldo inicial'));
    expect(balance.decoration!.errorText, contains('Monto inválido'));
    expect(await env.accounts.list(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('edita el nombre y el saldo inicial de una cuenta', (tester) async {
    final account = await env.cash(name: 'Caja', initial: 1000);
    await pumpApp(tester, env, location: '/cuentas/${account.id}/editar');

    expect(tester.widget<TextField>(field('Nombre')).controller!.text, 'Caja');
    expect(tester.widget<TextField>(field('Saldo inicial')).controller!.text, '10.00');

    await tester.enterText(field('Nombre'), 'Caja chica');
    await tester.enterText(field('Saldo inicial'), '25');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final updated = (await env.accounts.get(account.id))!;
    expect(updated.name, 'Caja chica');
    expect(updated.initialBalanceMinor, 2500);
    await unmountApp(tester);
  });

  testWidgets('la lista muestra saldos por cuenta y oculta las archivadas', (tester) async {
    final cash = await env.cash(name: 'Mi billetera', initial: 5000);
    final old = await env.bank(name: 'Banco viejo');
    await env.expense(cash.id, 1250, DateTime(2026, 9, 1));
    await env.accounts.update(old.id, isArchived: true);
    await pumpApp(tester, env, location: '/cuentas');

    expect(find.text('Mi billetera'), findsOneWidget);
    expect(find.text('Q37.50'), findsOneWidget);
    expect(find.text('Banco viejo'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar archivadas'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Banco viejo'), findsOneWidget);
    expect(find.textContaining('Archivada'), findsOneWidget);
    await unmountApp(tester);
  });
}
