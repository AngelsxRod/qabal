import 'dart:async';

import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv(DateTime(2026, 9, 1, 10)));
  tearDown(() => env.close());

  group('create', () {
    test('normaliza nombre y moneda y usa el reloj inyectado', () async {
      final a = await env.accounts.create(const AccountInput(
          name: '  Efectivo ', type: AccountType.cash, currency: 'gtq'));
      expect(a.name, 'Efectivo');
      expect(a.currency, 'GTQ');
      expect(a.createdAt, DateTime(2026, 9, 1, 10));
      expect(a.updatedAt, DateTime(2026, 9, 1, 10));
    });

    test('rechaza nombre vacío y moneda inválida', () async {
      await expectLater(
          env.accounts.create(const AccountInput(name: ' ', type: AccountType.cash, currency: 'GTQ')),
          throwsA(isA<InvalidInputException>()));
      await expectLater(
          env.accounts.create(const AccountInput(name: 'x', type: AccountType.cash, currency: 'Q')),
          throwsA(isA<InvalidInputException>()));
    });

    test('una tarjeta se crea junto con sus detalles', () async {
      final c = await env.card(limit: 500000, statementDay: 21, dueDay: 15, minPaymentBp: 500);
      final d = (await env.accounts.cardSettings(c.id))!;
      expect(d.creditLimitMinor, 500000);
      expect(d.statementDay, 21);
      expect(d.dueDay, 15);
      expect(d.minPaymentBp, 500);
    });

    test('una tarjeta exige sus datos; las demás cuentas los prohíben', () async {
      await expectLater(
          env.accounts.create(const AccountInput(
              name: 'Visa', type: AccountType.creditCard, currency: 'GTQ')),
          throwsA(isA<InvalidInputException>()));
      await expectLater(
          env.accounts.create(
              const AccountInput(name: 'Caja', type: AccountType.cash, currency: 'GTQ'),
              card: const CreditCardSettings(
                  creditLimitMinor: 1000, statementDay: 21, dueDay: 15)),
          throwsA(isA<InvalidInputException>()));
      expect(await env.accounts.list(), isEmpty);
    });

    test('rechaza cortes y pagos que pueden coincidir y no crea nada', () async {
      await expectLater(env.card(statementDay: 30, dueDay: 31),
          throwsA(isA<InvalidCardScheduleException>()));
      expect(await env.accounts.list(), isEmpty);
    });

    test('rechaza límite <= 0 y minPaymentBp fuera de rango', () async {
      await expectLater(env.card(limit: 0), throwsA(isA<InvalidInputException>()));
      await expectLater(env.card(minPaymentBp: 10001), throwsA(isA<InvalidInputException>()));
    });
  });

  group('update', () {
    test('actualiza updatedAt automáticamente y conserva createdAt', () async {
      final a = await env.cash();
      env.clock.current = DateTime(2026, 9, 2, 8);
      await env.accounts.update(a.id, name: 'Caja chica');
      final u = (await env.accounts.get(a.id))!;
      expect(u.name, 'Caja chica');
      expect(u.createdAt, DateTime(2026, 9, 1, 10));
      expect(u.updatedAt, DateTime(2026, 9, 2, 8));
    });

    test('archivar oculta la cuenta del listado por defecto', () async {
      final a = await env.cash();
      await env.bank();
      await env.accounts.update(a.id, isArchived: true);
      expect((await env.accounts.list()).map((x) => x.name), ['Banco']);
      expect(await env.accounts.list(includeArchived: true), hasLength(2));
    });

    test('cuenta inexistente', () async {
      await expectLater(env.accounts.update('nope', name: 'x'), throwsA(isA<NotFoundException>()));
    });

    test('updateCardSettings: valida tipo y horario, y actualiza updatedAt', () async {
      final bank = await env.bank();
      final card = await env.card();
      const ok = CreditCardSettings(creditLimitMinor: 2000000, statementDay: 10, dueDay: 28);
      await expectLater(env.accounts.updateCardSettings(bank.id, ok),
          throwsA(isA<NotACreditCardException>()));
      await expectLater(
          env.accounts.updateCardSettings(card.id,
              const CreditCardSettings(creditLimitMinor: 1000, statementDay: 29, dueDay: 31)),
          throwsA(isA<InvalidCardScheduleException>()));
      env.clock.current = DateTime(2026, 9, 5);
      await env.accounts.updateCardSettings(card.id, ok);
      final d = (await env.accounts.cardSettings(card.id))!;
      expect(d.creditLimitMinor, 2000000);
      expect(d.statementDay, 10);
      expect(d.updatedAt, DateTime(2026, 9, 5));
    });
  });

  group('saldo de cuenta', () {
    test('inicial + ingresos − gastos − transferencias salientes + entrantes', () async {
      final a = await env.cash(initial: 100000);
      final b = await env.bank();
      final d = DateTime(2026, 9, 3);
      await env.income(a.id, 50000, d);
      await env.expense(a.id, 20000, d);
      await env.transfer(a.id, b.id, 30000, d); // sale de a, entra a b
      await env.transfer(b.id, a.id, 10000, d); // entra a a, sale de b
      // a: 100000 + 50000 − 20000 − 30000 + 10000 = 110000
      expect((await env.accounts.balance(a.id)).balanceMinor, 110000);
      // b: 0 + 30000 − 10000 = 20000
      expect((await env.accounts.balance(b.id)).balanceMinor, 20000);
    });

    test('con monedas distintas la entrada usa transferAmountMinor', () async {
      final gtq = await env.cash(initial: 100000);
      final usd = await env.bank(name: 'Dólares', currency: 'USD');
      await env.transfer(gtq.id, usd.id, 78000, DateTime(2026, 9, 3), destAmount: 10000);
      expect((await env.accounts.balance(gtq.id)).balanceMinor, 22000);
      expect((await env.accounts.balance(usd.id)).balanceMinor, 10000);
    });

    test('los movimientos de deuda también mueven el saldo', () async {
      final a = await env.cash(initial: 100000);
      final c = await env.contact();
      await env.debts.create(
        DebtInput(
            contactId: c.id,
            direction: DebtDirection.owedToMe,
            principalMinor: 50000,
            currency: 'GTQ',
            description: 'Préstamo',
            startDate: DateTime(2026, 9, 1)),
        originAccountId: a.id,
      );
      expect((await env.accounts.balance(a.id)).balanceMinor, 50000);
    });

    test('cuenta inexistente', () async {
      await expectLater(env.accounts.balance('nope'), throwsA(isA<NotFoundException>()));
    });

    test('watchBalance emite el saldo inicial y el nuevo tras un movimiento', () async {
      final a = await env.cash(initial: 1000);
      final it = StreamIterator(env.accounts.watchBalance(a.id).map((b) => b.balanceMinor));
      expect(await it.moveNext(), isTrue);
      expect(it.current, 1000);
      await env.income(a.id, 500, DateTime(2026, 9, 3));
      expect(await it.moveNext(), isTrue);
      expect(it.current, 1500);
      await it.cancel();
    });

    test('watchBalances lista todas las cuentas con su saldo y reacciona a cambios', () async {
      final a = await env.cash(initial: 100);
      final b = await env.bank(initial: 200);
      final it = StreamIterator(env.accounts.watchBalances());
      await it.moveNext();
      expect({for (final x in it.current) x.account.id: x.balanceMinor}, {a.id: 100, b.id: 200});
      await env.expense(a.id, 40, DateTime(2026, 9, 3));
      await it.moveNext();
      expect({for (final x in it.current) x.account.id: x.balanceMinor}, {a.id: 60, b.id: 200});
      await it.cancel();
    });
  });

  group('tarjeta: convención de signo', () {
    test('saldo inicial negativo = deuda previa; disponible = límite − deuda', () async {
      final c = await env.card(limit: 1000000, initial: -50000);
      final o = await env.cards.overview(c.id);
      expect(o.balanceMinor, -50000);
      expect(o.owedMinor, 50000);
      expect(o.availableCreditMinor, 950000);
    });

    test('con saldo a favor: no se debe nada y el disponible supera el límite', () async {
      final c = await env.card(limit: 1000000);
      final bank = await env.bank(initial: 100000);
      await env.transfer(bank.id, c.id, 30000, DateTime(2026, 9, 3), autoAssign: false);
      final o = await env.cards.overview(c.id);
      expect(o.balanceMinor, 30000);
      expect(o.owedMinor, 0);
      expect(o.availableCreditMinor, 1030000);
    });
  });
}
