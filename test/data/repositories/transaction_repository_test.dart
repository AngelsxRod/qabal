import 'dart:async';

import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/database/seed.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late Account cash;
  late Account bank;
  final day = DateTime(2026, 9, 10, 12);

  setUp(() async {
    env = TestEnv(DateTime(2026, 9, 1, 10));
    cash = await env.cash(initial: 100000);
    bank = await env.bank(initial: 100000);
  });
  tearDown(() => env.close());

  TransactionInput input({
    TransactionType type = TransactionType.expense,
    int amount = 1000,
    String? accountId,
    String? categoryId,
    String? transferTo,
    int? transferAmount,
    String? statementId,
    String? debtId,
    String? contactId,
  }) =>
      TransactionInput(
        accountId: accountId ?? cash.id,
        type: type,
        amountMinor: amount,
        occurredAt: day,
        categoryId: categoryId,
        transferAccountId: transferTo,
        transferAmountMinor: transferAmount,
        statementId: statementId,
        debtId: debtId,
        contactId: contactId,
      );

  Future<Debt> debt({String currency = 'GTQ'}) async {
    final c = await env.contact('Amigo');
    return env.debts.create(DebtInput(
        contactId: c.id,
        direction: DebtDirection.owedToMe,
        principalMinor: 50000,
        currency: currency,
        description: 'Préstamo',
        startDate: DateTime(2026, 9, 1)));
  }

  group('validaciones', () {
    test('monto <= 0', () async {
      await expectLater(env.transactions.create(input(amount: 0)),
          throwsA(isA<InvalidAmountException>()));
      await expectLater(env.transactions.create(input(amount: -5)),
          throwsA(isA<InvalidAmountException>()));
    });

    test('caso válido básico', () async {
      final tx = await env.transactions.create(input(categoryId: 'default:food'));
      expect(tx.amountMinor, 1000);
      expect(tx.createdAt, DateTime(2026, 9, 1, 10));
    });

    group('transferencias', () {
      test('requiere destino, distinto del origen', () async {
        await expectLater(env.transactions.create(input(type: TransactionType.transfer)),
            throwsA(isA<InvalidTransferException>()));
        await expectLater(
            env.transactions
                .create(input(type: TransactionType.transfer, transferTo: cash.id)),
            throwsA(isA<InvalidTransferException>()));
      });

      test('los demás tipos no llevan destino ni monto de destino', () async {
        await expectLater(env.transactions.create(input(transferTo: bank.id)),
            throwsA(isA<InvalidTransferException>()));
        await expectLater(env.transactions.create(input(transferAmount: 500)),
            throwsA(isA<InvalidTransferException>()));
      });

      test('misma moneda: no admite monto de destino; válida sin él', () async {
        await expectLater(
            env.transactions.create(input(
                type: TransactionType.transfer, transferTo: bank.id, transferAmount: 900)),
            throwsA(isA<InvalidTransferException>()));
        await env.transactions
            .create(input(type: TransactionType.transfer, transferTo: bank.id));
      });

      test('monedas distintas: exige monto de destino positivo', () async {
        final usd = await env.bank(name: 'USD', currency: 'USD');
        await expectLater(
            env.transactions.create(input(type: TransactionType.transfer, transferTo: usd.id)),
            throwsA(isA<InvalidTransferException>()));
        await expectLater(
            env.transactions.create(input(
                type: TransactionType.transfer, transferTo: usd.id, transferAmount: 0)),
            throwsA(isA<InvalidTransferException>()));
        await env.transactions.create(input(
            type: TransactionType.transfer, transferTo: usd.id, transferAmount: 130));
      });

      test('las transferencias no llevan categoría', () async {
        await expectLater(
            env.transactions.create(input(
                type: TransactionType.transfer,
                transferTo: bank.id,
                categoryId: 'default:food')),
            throwsA(isA<InvalidTransferException>()));
      });

      test('cuentas inexistentes', () async {
        await expectLater(env.transactions.create(input(accountId: 'nope')),
            throwsA(isA<NotFoundException>()));
        await expectLater(
            env.transactions
                .create(input(type: TransactionType.transfer, transferTo: 'nope')),
            throwsA(isA<NotFoundException>()));
      });
    });

    group('categoría', () {
      test('debe coincidir con el tipo', () async {
        await env.transactions.create(input(categoryId: 'default:food'));
        await env.transactions.create(
            input(type: TransactionType.income, categoryId: 'default:salary'));
        await expectLater(env.transactions.create(input(categoryId: 'default:salary')),
            throwsA(isA<CategoryKindMismatchException>()));
        await expectLater(
            env.transactions
                .create(input(type: TransactionType.income, categoryId: 'default:food')),
            throwsA(isA<CategoryKindMismatchException>()));
      });

      test('sin categoría es válido; categoría inexistente no', () async {
        await env.transactions.create(input());
        await expectLater(env.transactions.create(input(categoryId: 'nope')),
            throwsA(isA<NotFoundException>()));
      });

      test('un movimiento con debtId no lleva categoría', () async {
        final d = await debt();
        await expectLater(
            env.transactions.create(input(debtId: d.id, categoryId: 'default:food')),
            throwsA(isA<DebtMovementCategoryException>()));
        await env.transactions.create(input(debtId: d.id));
      });
    });

    group('deuda', () {
      test('la cuenta debe tener la moneda de la deuda', () async {
        final usd = await env.cash(name: 'Dólares', currency: 'USD');
        final d = await debt();
        await expectLater(
            env.transactions.create(input(accountId: usd.id, debtId: d.id)),
            throwsA(isA<CurrencyMismatchException>()));
        await env.transactions.create(input(debtId: d.id));
      });

      test('una transferencia no puede ser movimiento de deuda', () async {
        final d = await debt();
        await expectLater(
            env.transactions.create(input(
                type: TransactionType.transfer, transferTo: bank.id, debtId: d.id)),
            throwsA(isA<InvalidInputException>()));
      });

      test('deuda o contacto inexistentes', () async {
        await expectLater(env.transactions.create(input(debtId: 'nope')),
            throwsA(isA<NotFoundException>()));
        await expectLater(env.transactions.create(input(contactId: 'nope')),
            throwsA(isA<NotFoundException>()));
      });
    });

    group('vínculo con estado de cuenta', () {
      late Account card;
      late CreditCardStatement statement;

      setUp(() async {
        card = await env.card();
        statement = await env.cards.registerStatement(StatementInput(
            accountId: card.id,
            closingDate: DateTime(2026, 9, 21),
            statementBalanceMinor: 75000,
            minimumPaymentMinor: 7500));
      });

      test('válido: transferencia hacia esa tarjeta', () async {
        final tx = await env.transfer(bank.id, card.id, 7500, day, statementId: statement.id);
        expect(tx.statementId, statement.id);
      });

      test('rechaza si no es transferencia', () async {
        await expectLater(
            env.transactions.create(input(accountId: card.id, statementId: statement.id)),
            throwsA(isA<InvalidStatementLinkException>()));
      });

      test('rechaza si el destino es otra cuenta/tarjeta', () async {
        final other = await env.card(name: 'Mastercard');
        await expectLater(
            env.transfer(bank.id, other.id, 7500, day, statementId: statement.id),
            throwsA(isA<InvalidStatementLinkException>()));
        await expectLater(
            env.transfer(cash.id, bank.id, 7500, day, statementId: statement.id),
            throwsA(isA<InvalidStatementLinkException>()));
      });

      test('estado de cuenta inexistente', () async {
        await expectLater(env.transfer(bank.id, card.id, 100, day, statementId: 'nope'),
            throwsA(isA<NotFoundException>()));
      });
    });

    group('cuentas archivadas', () {
      test('no se crean movimientos nuevos (origen ni destino)', () async {
        await env.accounts.update(cash.id, isArchived: true);
        await expectLater(env.transactions.create(input()),
            throwsA(isA<ArchivedAccountException>()));
        await expectLater(
            env.transactions
                .create(input(type: TransactionType.transfer, accountId: bank.id, transferTo: cash.id)),
            throwsA(isA<ArchivedAccountException>()));
      });

      test('editar sin cambiar de cuenta sí se permite; moverlo a una archivada no', () async {
        final tx = await env.transactions.create(input());
        await env.accounts.update(cash.id, isArchived: true);
        await env.transactions.update(tx.id, input(amount: 2500));
        expect((await env.transactions.get(tx.id))!.amountMinor, 2500);
        final tx2 = await env.transactions.create(input(accountId: bank.id));
        await expectLater(env.transactions.update(tx2.id, input(amount: 10)),
            throwsA(isA<ArchivedAccountException>()));
      });
    });
  });

  group('escritura', () {
    test('update reemplaza los campos y actualiza updatedAt sin tocar createdAt', () async {
      final tx = await env.transactions.create(input(categoryId: 'default:food'));
      env.clock.current = DateTime(2026, 9, 5, 9);
      await env.transactions.update(tx.id, input(amount: 4200, categoryId: 'default:groceries'));
      final u = (await env.transactions.get(tx.id))!;
      expect(u.amountMinor, 4200);
      expect(u.categoryId, 'default:groceries');
      expect(u.createdAt, DateTime(2026, 9, 1, 10));
      expect(u.updatedAt, DateTime(2026, 9, 5, 9));
    });

    test('update puede dejar la categoría en nulo', () async {
      final tx = await env.transactions.create(input(categoryId: 'default:food'));
      await env.transactions.update(tx.id, input());
      expect((await env.transactions.get(tx.id))!.categoryId, isNull);
    });

    test('update inexistente y datos inválidos no escriben', () async {
      await expectLater(env.transactions.update('nope', input()),
          throwsA(isA<NotFoundException>()));
      final tx = await env.transactions.create(input());
      await expectLater(env.transactions.update(tx.id, input(amount: 0)),
          throwsA(isA<InvalidAmountException>()));
      expect((await env.transactions.get(tx.id))!.amountMinor, 1000);
    });

    test('crear con etiquetas es atómico: una etiqueta inexistente deshace todo', () async {
      final tag = await env.tags.create('Casa');
      await expectLater(env.transactions.create(input(), tagIds: {tag.id, 'nope'}),
          throwsA(isA<NotFoundException>()));
      expect(await env.transactions.list(const TransactionFilter()), isEmpty);
    });

    test('update con tagIds reemplaza las etiquetas; nulo las conserva', () async {
      final a = await env.tags.create('A');
      final b = await env.tags.create('B');
      final tx = await env.transactions.create(input(), tagIds: {a.id});
      await env.transactions.update(tx.id, input(amount: 5));
      expect((await env.tags.tagsOf(tx.id)).map((t) => t.name), ['A']);
      await env.transactions.update(tx.id, input(amount: 6), tagIds: {b.id});
      expect((await env.tags.tagsOf(tx.id)).map((t) => t.name), ['B']);
    });

    test('setTags actualiza updatedAt', () async {
      final a = await env.tags.create('A');
      final tx = await env.transactions.create(input());
      env.clock.current = DateTime(2026, 9, 7);
      await env.transactions.setTags(tx.id, {a.id});
      expect((await env.transactions.get(tx.id))!.updatedAt, DateTime(2026, 9, 7));
      expect(await env.tags.tagsOf(tx.id), hasLength(1));
    });

    test('delete borra de verdad, con sus etiquetas, y falla si no existe', () async {
      final a = await env.tags.create('A');
      final tx = await env.transactions.create(input(), tagIds: {a.id});
      await env.transactions.delete(tx.id);
      expect(await env.transactions.get(tx.id), isNull);
      expect(await env.db.select(env.db.transactionTags).get(), isEmpty);
      await expectLater(env.transactions.delete(tx.id), throwsA(isA<NotFoundException>()));
      expect((await env.accounts.balance(cash.id)).balanceMinor, 100000);
    });
  });

  group('lectura', () {
    test('filtra por cuenta (incluye transferencias entrantes), tipo, fechas y etiqueta', () async {
      final tag = await env.tags.create('Viaje');
      await env.expense(cash.id, 100, DateTime(2026, 9, 1), categoryId: 'default:food');
      await env.income(cash.id, 200, DateTime(2026, 9, 5), categoryId: 'default:salary');
      await env.transfer(bank.id, cash.id, 300, DateTime(2026, 9, 8));
      final tagged = await env.transactions.create(
          input(accountId: bank.id, amount: 400), tagIds: {tag.id});

      final ofCash = await env.transactions.list(TransactionFilter(accountId: cash.id));
      expect(ofCash.map((t) => t.amountMinor), [300, 200, 100]);

      final onlyIncome =
          await env.transactions.list(const TransactionFilter(type: TransactionType.income));
      expect(onlyIncome.map((t) => t.amountMinor), [200]);

      final range = await env.transactions.list(
          TransactionFilter(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 9)));
      expect(range.map((t) => t.amountMinor), [300, 200]);

      final byTag = await env.transactions.list(TransactionFilter(tagId: tag.id));
      expect(byTag.single.id, tagged.id);

      final page = await env.transactions
          .list(TransactionFilter(accountId: cash.id, limit: 1, offset: 1));
      expect(page.single.amountMinor, 200);
    });

    test('ordena por día descendente y, dentro del día, el último registrado arriba', () async {
      await env.expense(cash.id, 100, DateTime(2026, 9, 5));
      env.clock.current = DateTime(2026, 9, 1, 10, 0, 1);
      await env.expense(cash.id, 200, DateTime(2026, 9, 5));
      env.clock.current = DateTime(2026, 9, 1, 10, 0, 2);
      await env.expense(cash.id, 300, DateTime(2026, 9, 8));
      env.clock.current = DateTime(2026, 9, 1, 10, 0, 3);
      await env.expense(cash.id, 400, DateTime(2026, 9, 5));

      final all = await env.transactions.list(const TransactionFilter());
      expect(all.map((t) => t.amountMinor), [300, 400, 200, 100]);
      final ofCash = await env.transactions.list(TransactionFilter(accountId: cash.id));
      expect(ofCash.map((t) => t.amountMinor), [300, 400, 200, 100]);
    });

    test('con el mismo instante de registro, el insertado después va arriba', () async {
      await env.expense(cash.id, 100, DateTime(2026, 9, 5));
      await env.expense(cash.id, 200, DateTime(2026, 9, 5));
      await env.expense(cash.id, 300, DateTime(2026, 9, 5));

      final all = await env.transactions.list(const TransactionFilter());
      expect(all.map((t) => t.amountMinor), [300, 200, 100]);
    });

    test('watch emite al insertar y al borrar', () async {
      final it = StreamIterator(env.transactions.watch(const TransactionFilter()));
      await it.moveNext();
      expect(it.current, isEmpty);
      final tx = await env.transactions.create(input());
      await it.moveNext();
      expect(it.current.map((t) => t.id), [tx.id]);
      await env.transactions.delete(tx.id);
      await it.moveNext();
      expect(it.current, isEmpty);
      await it.cancel();
    });
  });

  group('pagos a tarjeta: asignación automática de estado de cuenta', () {
    late Account card;

    setUp(() async {
      card = await env.card();
      env.clock.current = DateTime(2026, 10, 1);
    });

    Future<CreditCardStatement> statement(DateTime closing, int balance, int minimum) =>
        env.cards.registerStatement(StatementInput(
            accountId: card.id,
            closingDate: closing,
            statementBalanceMinor: balance,
            minimumPaymentMinor: minimum));

    test('sin estados de cuenta queda sin vincular', () async {
      final tx = await env.transfer(bank.id, card.id, 5000, day);
      expect(tx.statementId, isNull);
    });

    test('se asigna el pendiente más antiguo', () async {
      final sep = await statement(DateTime(2026, 9, 21), 75000, 7500);
      await statement(DateTime(2026, 10, 21), 50000, 5000);
      final tx = await env.transfer(bank.id, card.id, 5000, DateTime(2026, 10, 1));
      expect(tx.statementId, sep.id);
    });

    test('con autoAssign desactivado no se vincula (pago adelantado del ciclo en curso)', () async {
      await statement(DateTime(2026, 9, 21), 75000, 7500);
      final tx = await env.transfer(bank.id, card.id, 5000, DateTime(2026, 10, 1),
          autoAssign: false);
      expect(tx.statementId, isNull);
    });

    test('salta los estados ya pagados por completo', () async {
      final sep = await statement(DateTime(2026, 9, 21), 75000, 7500);
      final oct = await statement(DateTime(2026, 10, 21), 50000, 5000);
      final paySep = await env.transfer(bank.id, card.id, 75000, DateTime(2026, 10, 2));
      expect(paySep.statementId, sep.id);
      final next = await env.transfer(bank.id, card.id, 1000, DateTime(2026, 10, 3));
      expect(next.statementId, oct.id);
    });

    test('un estado con solo el mínimo cubierto sigue siendo candidato', () async {
      final sep = await statement(DateTime(2026, 9, 21), 75000, 7500);
      await env.transfer(bank.id, card.id, 7500, DateTime(2026, 10, 2));
      final rest = await env.transfer(bank.id, card.id, 10000, DateTime(2026, 10, 3));
      expect(rest.statementId, sep.id);
    });

    test('un statementId explícito se respeta', () async {
      await statement(DateTime(2026, 9, 21), 75000, 7500);
      final oct = await statement(DateTime(2026, 10, 21), 50000, 5000);
      final tx = await env.transfer(bank.id, card.id, 5000, DateTime(2026, 10, 3),
          statementId: oct.id);
      expect(tx.statementId, oct.id);
    });

    test('las transferencias a cuentas que no son tarjeta no se vinculan', () async {
      await statement(DateTime(2026, 9, 21), 75000, 7500);
      final tx = await env.transfer(cash.id, bank.id, 500, day);
      expect(tx.statementId, isNull);
    });

    test('un estado archivado no se sugiere', () async {
      final sep = await statement(DateTime(2026, 9, 21), 75000, 7500);
      await env.cards.setStatementArchived(sep.id, true);
      final tx = await env.transfer(bank.id, card.id, 500, day);
      expect(tx.statementId, isNull);
    });
  });

  group('totales', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 10, 1);

    Future<void> seedMovements() async {
      final d = DateTime(2026, 9, 10);
      await env.income(cash.id, 300000, d, categoryId: 'default:salary');
      await env.income(cash.id, 10000, d); // sin categoría
      await env.expense(cash.id, 50000, d, categoryId: 'default:food');
      await env.expense(cash.id, 20000, d, categoryId: 'default:transport');
      await env.income(cash.id, 5000, d, categoryId: kRefundsCategoryId);
      // Fuera del período
      await env.expense(cash.id, 999, DateTime(2026, 8, 31, 23));
      await env.expense(cash.id, 999, DateTime(2026, 10, 1));
      // Excluidos: transferencia y movimientos de deuda.
      await env.transfer(cash.id, bank.id, 12345, d);
      final debt = await env.debts.create(
        DebtInput(
            contactId: (await env.contact('Ana')).id,
            direction: DebtDirection.owedToMe,
            principalMinor: 80000,
            currency: 'GTQ',
            description: 'Préstamo',
            startDate: d),
        originAccountId: cash.id,
      );
      await env.income(cash.id, 30000, d, debtId: debt.id);
    }

    test('excluye transferencias y deudas; las devoluciones restan de los gastos', () async {
      await seedMovements();
      final t = (await env.transactions.totals(from: from, to: to)).single;
      expect(t.currency, 'GTQ');
      expect(t.incomeMinor, 310000); // sueldo + sin categoría, sin devoluciones
      expect(t.refundsMinor, 5000);
      expect(t.expenseMinor, 65000); // 50000 + 20000 − 5000
      expect(t.grossExpenseMinor, 70000);
    });

    test('separa por moneda y filtra por cuentas', () async {
      await seedMovements();
      final usd = await env.cash(name: 'USD', currency: 'USD');
      await env.expense(usd.id, 700, DateTime(2026, 9, 12));
      final all = await env.transactions.totals(from: from, to: to);
      expect(all.map((t) => t.currency), ['GTQ', 'USD']);
      expect(all.last.expenseMinor, 700);
      final onlyUsd = await env.transactions.totals(from: from, to: to, accountIds: {usd.id});
      expect(onlyUsd.single.currency, 'USD');
      expect(await env.transactions.totals(from: from, to: to, accountIds: {}), isEmpty);
    });

    test('totalsByCategory de gastos: ordenado, con línea negativa de devoluciones', () async {
      await seedMovements();
      final rows = await env.transactions
          .totalsByCategory(from: from, to: to, kind: CategoryKind.expense);
      expect(rows.map((r) => (r.categoryId, r.totalMinor)), [
        ('default:food', 50000),
        ('default:transport', 20000),
        (kRefundsCategoryId, -5000),
      ]);
    });

    test('totalsByCategory de ingresos: sin devoluciones y con "sin categoría"', () async {
      await seedMovements();
      final rows = await env.transactions
          .totalsByCategory(from: from, to: to, kind: CategoryKind.income);
      expect(rows.map((r) => (r.categoryId, r.totalMinor)), [
        ('default:salary', 300000),
        (null, 10000),
      ]);
    });

    test('totalsByCategory filtra por moneda', () async {
      await seedMovements();
      final usd = await env.cash(name: 'USD', currency: 'USD');
      await env.expense(usd.id, 700, DateTime(2026, 9, 12), categoryId: 'default:food');
      final rows = await env.transactions.totalsByCategory(
          from: from, to: to, kind: CategoryKind.expense, currency: 'USD');
      expect(rows.single.totalMinor, 700);
    });

    test('watchTotals reacciona a nuevos movimientos', () async {
      final it = StreamIterator(env.transactions.watchTotals(from: from, to: to));
      await it.moveNext();
      expect(it.current, isEmpty);
      await env.expense(cash.id, 1500, DateTime(2026, 9, 12));
      await it.moveNext();
      expect(it.current.single.expenseMinor, 1500);
      await it.cancel();
    });
  });
}
