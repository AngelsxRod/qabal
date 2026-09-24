import 'dart:async';

import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late Account cash;
  late Contact ana;
  final start = DateTime(2026, 9, 1);
  final day = DateTime(2026, 9, 10);

  setUp(() async {
    env = TestEnv(DateTime(2026, 9, 1, 10));
    cash = await env.cash(initial: 100000);
    ana = await env.contact('Ana');
  });
  tearDown(() => env.close());

  DebtInput input({
    DebtDirection direction = DebtDirection.owedToMe,
    int principal = 50000,
    String currency = 'GTQ',
    DateTime? due,
    String? contactId,
  }) =>
      DebtInput(
        contactId: contactId ?? ana.id,
        direction: direction,
        principalMinor: principal,
        currency: currency,
        description: 'Préstamo',
        startDate: start,
        dueDate: due,
      );

  Future<int> cashBalance() async => (await env.accounts.balance(cash.id)).balanceMinor;

  group('origen de la deuda', () {
    test('me deben: sale dinero de mi cuenta y no cuenta como abono', () async {
      final d = await env.debts.create(input(), originAccountId: cash.id);
      final origin = (await env.transactions.list(TransactionFilter(debtId: d.id))).single;
      expect(origin.type, TransactionType.expense);
      expect(origin.amountMinor, 50000);
      expect(origin.categoryId, isNull);
      expect(origin.contactId, ana.id);
      expect(await cashBalance(), 50000);
      final b = await env.debts.balance(d.id);
      expect(b.paidMinor, 0);
      expect(b.pendingMinor, 50000);
    });

    test('yo debo: entra dinero a mi cuenta y no cuenta como abono', () async {
      final d = await env.debts
          .create(input(direction: DebtDirection.iOwe), originAccountId: cash.id);
      final origin = (await env.transactions.list(TransactionFilter(debtId: d.id))).single;
      expect(origin.type, TransactionType.income);
      expect(await cashBalance(), 150000);
      expect((await env.debts.balance(d.id)).pendingMinor, 50000);
    });

    test('sin cuenta de origen (deuda histórica) no crea movimientos', () async {
      final d = await env.debts.create(input());
      expect(await env.transactions.list(TransactionFilter(debtId: d.id)), isEmpty);
      expect(await cashBalance(), 100000);
    });

    test('si el origen falla se deshace también la deuda', () async {
      final usd = await env.cash(name: 'USD', currency: 'USD');
      await expectLater(env.debts.create(input(), originAccountId: usd.id),
          throwsA(isA<CurrencyMismatchException>()));
      await env.accounts.update(cash.id, isArchived: true);
      await expectLater(env.debts.create(input(), originAccountId: cash.id),
          throwsA(isA<ArchivedAccountException>()));
      expect(await env.debts.list(includeArchived: true), isEmpty);
    });
  });

  group('saldo pendiente', () {
    test('me deben: los abonos son ingresos', () async {
      final d = await env.debts.create(input(), originAccountId: cash.id);
      await env.income(cash.id, 20000, day, debtId: d.id);
      await env.income(cash.id, 5000, day, debtId: d.id);
      final b = await env.debts.balance(d.id);
      expect(b.paidMinor, 25000);
      expect(b.pendingMinor, 25000);
      expect(b.excessMinor, 0);
      expect(await cashBalance(), 75000);
    });

    test('yo debo: los abonos son gastos y el origen (ingreso) no cuenta', () async {
      final d = await env.debts
          .create(input(direction: DebtDirection.iOwe), originAccountId: cash.id);
      await env.expense(cash.id, 10000, day, debtId: d.id);
      final b = await env.debts.balance(d.id);
      expect(b.paidMinor, 10000);
      expect(b.pendingMinor, 40000);
    });

    test('pagar de más deja pendiente 0 y muestra el excedente', () async {
      final d = await env.debts.create(input(principal: 10000));
      await env.income(cash.id, 12500, day, debtId: d.id);
      final b = await env.debts.balance(d.id);
      expect(b.pendingMinor, 0);
      expect(b.excessMinor, 2500);
      expect(b.isFullyPaid, isTrue);
    });

    test('los movimientos de deuda no entran en los totales de ingresos y gastos', () async {
      final d = await env.debts.create(input(), originAccountId: cash.id);
      await env.income(cash.id, 20000, day, debtId: d.id);
      expect(
          await env.transactions
              .totals(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
          isEmpty);
    });
  });

  group('estados', () {
    test('settle exige saldo pendiente 0', () async {
      final d = await env.debts.create(input(principal: 10000));
      await expectLater(
          env.debts.settle(d.id), throwsA(isA<DebtNotFullyPaidException>()));
      await env.income(cash.id, 10000, day, debtId: d.id);
      env.clock.current = DateTime(2026, 9, 12);
      await env.debts.settle(d.id);
      final u = (await env.debts.get(d.id))!;
      expect(u.status, DebtStatus.settled);
      expect(u.updatedAt, DateTime(2026, 9, 12));
    });

    test('forgive cierra con saldo pendiente y reopen la reabre', () async {
      final d = await env.debts.create(input());
      await env.debts.forgive(d.id);
      expect((await env.debts.get(d.id))!.status, DebtStatus.forgiven);
      await env.debts.reopen(d.id);
      expect((await env.debts.get(d.id))!.status, DebtStatus.open);
    });

    test('inexistente', () async {
      await expectLater(env.debts.forgive('nope'), throwsA(isA<NotFoundException>()));
      await expectLater(env.debts.balance('nope'), throwsA(isA<NotFoundException>()));
      await expectLater(env.debts.setArchived('nope', true), throwsA(isA<NotFoundException>()));
    });

    test('update cambia descripción y vencimiento, y puede quitarlo', () async {
      final d = await env.debts.create(input(due: DateTime(2026, 12, 1)));
      env.clock.current = DateTime(2026, 9, 3);
      await env.debts.update(d.id, description: 'Moto', dueDate: DateTime(2026, 12, 31, 20));
      var u = (await env.debts.get(d.id))!;
      expect(u.description, 'Moto');
      expect(u.dueDate, DateTime(2026, 12, 31));
      expect(u.updatedAt, DateTime(2026, 9, 3));
      await env.debts.update(d.id, clearDueDate: true);
      u = (await env.debts.get(d.id))!;
      expect(u.dueDate, isNull);
    });
  });

  group('validaciones de creación', () {
    test('principal <= 0, contacto inexistente, vencimiento anterior al inicio', () async {
      await expectLater(env.debts.create(input(principal: 0)),
          throwsA(isA<InvalidAmountException>()));
      await expectLater(env.debts.create(input(contactId: 'nope')),
          throwsA(isA<NotFoundException>()));
      await expectLater(env.debts.create(input(due: DateTime(2026, 8, 1))),
          throwsA(isA<InvalidInputException>()));
    });

    test('moneda inválida', () async {
      await expectLater(env.debts.create(input(currency: 'Q')),
          throwsA(isA<InvalidInputException>()));
    });
  });

  group('listas', () {
    test('filtra por dirección y estado, y excluye archivadas', () async {
      final a = await env.debts.create(input());
      final b = await env.debts.create(input(direction: DebtDirection.iOwe));
      await env.debts.forgive(b.id);
      final c = await env.debts.create(input(principal: 1000));
      await env.debts.setArchived(c.id, true);
      expect((await env.debts.list()).map((x) => x.debt.id), unorderedEquals([a.id, b.id]));
      expect((await env.debts.list(direction: DebtDirection.iOwe)).single.debt.id, b.id);
      expect((await env.debts.list(status: DebtStatus.open)).single.debt.id, a.id);
      expect(await env.debts.list(includeArchived: true), hasLength(3));
    });

    test('list calcula el pendiente de cada deuda', () async {
      final a = await env.debts.create(input(principal: 10000));
      final b = await env.debts.create(input(principal: 20000));
      await env.income(cash.id, 4000, day, debtId: a.id);
      final byId = {for (final x in await env.debts.list()) x.debt.id: x.pendingMinor};
      expect(byId, {a.id: 6000, b.id: 20000});
    });

    test('watch y watchBalance emiten al registrar un abono', () async {
      final d = await env.debts.create(input(principal: 10000));
      final list = StreamIterator(env.debts.watch());
      final one = StreamIterator(env.debts.watchBalance(d.id));
      await list.moveNext();
      await one.moveNext();
      expect(list.current.single.pendingMinor, 10000);
      expect(one.current.pendingMinor, 10000);
      await env.income(cash.id, 3000, day, debtId: d.id);
      await list.moveNext();
      await one.moveNext();
      expect(list.current.single.pendingMinor, 7000);
      expect(one.current.pendingMinor, 7000);
      await list.cancel();
      await one.cancel();
    });
  });
}
