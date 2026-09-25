import 'dart:async';

import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/database/seed.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/domain/credit_card/statement_status.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Escenario real: corte el 21, pago el 15. Montos en centavos (Q1 = 100).
void main() {
  late TestEnv env;
  late Account bank;
  late Account visa;

  setUp(() async {
    env = TestEnv(DateTime(2026, 9, 30, 9));
    bank = await env.bank(initial: 500000);
    visa = await env.card(limit: 1000000, statementDay: 21, dueDay: 15, minPaymentBp: 1000);
  });
  tearDown(() => env.close());

  /// Compras: Q100 (25 ago), Q300 (5 sep), Q200 (18 sep), Q150 (21 sep, último
  /// minuto del corte) y Q400 (22 sep, ya del siguiente ciclo).
  Future<void> purchases() async {
    await env.expense(visa.id, 10000, DateTime(2026, 8, 25, 14));
    await env.expense(visa.id, 30000, DateTime(2026, 9, 5, 10));
    await env.expense(visa.id, 20000, DateTime(2026, 9, 18, 19));
    await env.expense(visa.id, 15000, DateTime(2026, 9, 21, 23, 59));
    await env.expense(visa.id, 40000, DateTime(2026, 9, 22, 0, 1));
  }

  Future<CreditCardStatement> officialSeptember({int balance = 75000, int minimum = 7500}) =>
      env.cards.registerStatement(StatementInput(
          accountId: visa.id,
          closingDate: DateTime(2026, 9, 21),
          statementBalanceMinor: balance,
          minimumPaymentMinor: minimum));

  group('ciclos con las compras del escenario', () {
    test('las compras hasta el 21 sep entran al corte del 21; la del 22 al siguiente', () async {
      await purchases();
      final sept = await env.cards.cycleSummary(visa.id, forDate: DateTime(2026, 9, 21));
      expect(sept.cycle.periodStart, DateTime(2026, 8, 22));
      expect(sept.cycle.closingDate, DateTime(2026, 9, 21));
      expect(sept.cycle.dueDate, DateTime(2026, 10, 15));
      expect(sept.movements.purchasesMinor, 75000); // 100 + 300 + 200 + 150
      expect(sept.movements.openingDebtMinor, 0);
      expect(sept.estimatedClosingMinor, 75000);

      final oct = await env.cards.cycleSummary(visa.id, forDate: DateTime(2026, 9, 22));
      expect(oct.cycle.closingDate, DateTime(2026, 10, 21));
      expect(oct.cycle.dueDate, DateTime(2026, 11, 15));
      expect(oct.movements.purchasesMinor, 40000);
      expect(oct.movements.openingDebtMinor, 75000);
    });

    test('registrar el estado deriva inicio y pago del horario', () async {
      await purchases();
      final s = await officialSeptember();
      expect(s.periodStart, DateTime(2026, 8, 22));
      expect(s.closingDate, DateTime(2026, 9, 21));
      expect(s.dueDate, DateTime(2026, 10, 15));
    });
  });

  group('estimado vs oficial', () {
    test('coinciden: diferencia 0', () async {
      await purchases();
      final s = await officialSeptember();
      final v = await env.cards.statementView(s.id);
      expect(v.estimatedBalanceMinor, 75000);
      expect(v.differenceMinor, 0);
      expect(v.movements.purchasesMinor, 75000);
    });

    test('si el banco reporta más, la diferencia es positiva', () async {
      await purchases();
      final s = await officialSeptember(balance: 80000, minimum: 8000);
      final v = await env.cards.statementView(s.id);
      expect(v.differenceMinor, 5000);
    });

    test('si el banco reporta menos, la diferencia es negativa', () async {
      await purchases();
      final s = await officialSeptember(balance: 70000, minimum: 7000);
      expect((await env.cards.statementView(s.id)).differenceMinor, -5000);
    });

    test('el estimado incluye pagos hechos antes del corte y deuda previa', () async {
      await env.accounts.update(visa.id, initialBalanceMinor: -20000); // deuda previa Q200
      await purchases();
      await env.transfer(bank.id, visa.id, 10000, DateTime(2026, 9, 10), autoAssign: false);
      final s = await officialSeptember(balance: 85000, minimum: 8500);
      final v = await env.cards.statementView(s.id);
      // 200 (previa) + 750 (compras) − 100 (pago) = 850
      expect(v.estimatedBalanceMinor, 85000);
      expect(v.differenceMinor, 0);
      expect(v.movements.openingDebtMinor, 20000);
      expect(v.movements.paymentsMinor, 10000);
    });
  });

  group('estado del estado de cuenta (oficial Q750, mínimo Q75, pago hasta el 15 oct)', () {
    late CreditCardStatement sept;

    setUp(() async {
      await purchases();
      sept = await officialSeptember();
    });

    Future<StatementStatus> statusAt(DateTime today) async {
      env.clock.current = today;
      return (await env.cards.statementView(sept.id)).status;
    }

    test('pago completo → pagado (antes y después de la fecha)', () async {
      final pay = await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 10, 10));
      expect(pay.statementId, sept.id);
      expect(await statusAt(DateTime(2026, 10, 12)), StatementStatus.paid);
      expect(await statusAt(DateTime(2026, 10, 30)), StatementStatus.paid);
      expect((await env.cards.statementView(sept.id)).paidMinor, 75000);
    });

    test('pagos parciales que suman el total → pagado', () async {
      await env.transfer(bank.id, visa.id, 40000, DateTime(2026, 10, 5));
      await env.transfer(bank.id, visa.id, 35000, DateTime(2026, 10, 6));
      expect(await statusAt(DateTime(2026, 10, 7)), StatementStatus.paid);
    });

    test('solo el mínimo → mínimo cubierto (también vencida la fecha)', () async {
      await env.transfer(bank.id, visa.id, 7500, DateTime(2026, 10, 10));
      expect(await statusAt(DateTime(2026, 10, 12)), StatementStatus.minimumCovered);
      expect(await statusAt(DateTime(2026, 10, 20)), StatementStatus.minimumCovered);
    });

    test('sin pago: pendiente hasta el 15 oct (inclusive) y vencido después', () async {
      expect(await statusAt(DateTime(2026, 10, 1)), StatementStatus.pending);
      expect(await statusAt(DateTime(2026, 10, 15, 23, 59)), StatementStatus.pending);
      expect(await statusAt(DateTime(2026, 10, 16)), StatementStatus.overdue);
    });

    test('un pago menor al mínimo sigue pendiente y luego vencido', () async {
      await env.transfer(bank.id, visa.id, 5000, DateTime(2026, 10, 10));
      expect(await statusAt(DateTime(2026, 10, 12)), StatementStatus.pending);
      expect(await statusAt(DateTime(2026, 10, 20)), StatementStatus.overdue);
    });

    test('un pago sin vincular (autoAssign desactivado) no cuenta para el estado', () async {
      env.clock.current = DateTime(2026, 10, 10);
      await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 10, 10), autoAssign: false);
      expect(await statusAt(DateTime(2026, 10, 20)), StatementStatus.overdue);
    });

    test('watchStatements cambia de estado cuando se registra el pago', () async {
      env.clock.current = DateTime(2026, 10, 12);
      final it = StreamIterator(env.cards.watchStatements(visa.id));
      await it.moveNext();
      expect(it.current.single.status, StatementStatus.pending);
      await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 10, 10));
      await it.moveNext();
      expect(it.current.single.status, StatementStatus.paid);
      await it.cancel();
    });
  });

  group('ciclo en curso (1 oct): arrastre del saldo no pagado', () {
    late CreditCardStatement sept;

    setUp(() async {
      await purchases();
      sept = await officialSeptember();
      env.clock.current = DateTime(2026, 10, 1);
    });

    test('sin pagos: estimado = 750 arrastrados + 400 del ciclo', () async {
      final s = await env.cards.cycleSummary(visa.id);
      expect(s.cycle.periodStart, DateTime(2026, 9, 22));
      expect(s.cycle.closingDate, DateTime(2026, 10, 21));
      expect(s.movements.openingDebtMinor, 75000);
      expect(s.movements.purchasesMinor, 40000);
      expect(s.movements.paymentsMinor, 0);
      expect(s.estimatedClosingMinor, 115000);
      expect(s.estimatedMinimumMinor, 11500); // 10 % de 1150
      expect(s.previousStatementPendingMinor, 75000);
    });

    test('con el pago completo del estado anterior baja a 400', () async {
      await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 10, 1));
      final s = await env.cards.cycleSummary(visa.id);
      expect(s.movements.paymentsMinor, 75000);
      expect(s.estimatedClosingMinor, 40000);
      expect(s.previousStatementPendingMinor, 0);
      expect((await env.cards.statementView(sept.id)).paidMinor, 75000);
    });

    test('con solo el mínimo queda pendiente del estado anterior el resto', () async {
      await env.transfer(bank.id, visa.id, 7500, DateTime(2026, 10, 1));
      final s = await env.cards.cycleSummary(visa.id);
      expect(s.previousStatementPendingMinor, 67500);
      expect(s.estimatedClosingMinor, 67500 + 40000); // 675 sin pagar + 400 del ciclo
    });

    test('resumen general: cuánto debo y crédito disponible', () async {
      final o = await env.cards.overview(visa.id);
      expect(o.balanceMinor, -115000);
      expect(o.owedMinor, 115000);
      expect(o.availableCreditMinor, 885000);
    });

    test('sin minPaymentBp no hay mínimo estimado', () async {
      await env.accounts.updateCardSettings(
          visa.id,
          const CreditCardSettings(
              creditLimitMinor: 1000000, statementDay: 21, dueDay: 15));
      expect((await env.cards.cycleSummary(visa.id)).estimatedMinimumMinor, isNull);
    });
  });

  group('devoluciones, intereses y avances', () {
    test('se separan por categoría del sistema y cuadran con el saldo', () async {
      final d = DateTime(2026, 9, 10);
      await env.expense(visa.id, 50000, d, categoryId: 'default:shopping');
      await env.expense(visa.id, 5000, d, categoryId: kInterestFeesCategoryId);
      await env.income(visa.id, 3000, d, categoryId: kRefundsCategoryId);
      await env.income(visa.id, 1000, d); // otro crédito
      await env.transfer(visa.id, bank.id, 2000, d); // avance
      await env.transfer(bank.id, visa.id, 10000, d, autoAssign: false);
      final m = (await env.cards.cycleSummary(visa.id, forDate: DateTime(2026, 9, 15))).movements;
      expect(m.purchasesMinor, 50000);
      expect(m.interestMinor, 5000);
      expect(m.refundsMinor, 3000);
      expect(m.otherCreditsMinor, 1000);
      expect(m.cashAdvancesMinor, 2000);
      expect(m.paymentsMinor, 10000);
      // 50000 + 5000 + 2000 − 3000 − 1000 − 10000
      expect(m.closingDebtMinor, 43000);
      expect(-(await env.accounts.balance(visa.id)).balanceMinor, 43000);
    });

    test('en los totales de gastos las devoluciones restan', () async {
      final d = DateTime(2026, 9, 10);
      await env.expense(visa.id, 50000, d, categoryId: 'default:shopping');
      await env.income(visa.id, 3000, d, categoryId: kRefundsCategoryId);
      final t = (await env.transactions
              .totals(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))
          .single;
      expect(t.incomeMinor, 0);
      expect(t.refundsMinor, 3000);
      expect(t.expenseMinor, 47000);
    });
  });

  group('registro de estados de cuenta: validaciones', () {
    StatementInput input({
      String? accountId,
      DateTime? closing,
      int balance = 75000,
      int minimum = 7500,
      DateTime? start,
      DateTime? due,
    }) =>
        StatementInput(
            accountId: accountId ?? visa.id,
            closingDate: closing ?? DateTime(2026, 9, 21),
            statementBalanceMinor: balance,
            minimumPaymentMinor: minimum,
            periodStart: start,
            dueDate: due);

    test('solo para tarjetas de crédito', () async {
      await expectLater(env.cards.registerStatement(input(accountId: bank.id)),
          throwsA(isA<NotACreditCardException>()));
      await expectLater(env.cards.registerStatement(input(accountId: 'nope')),
          throwsA(isA<NotFoundException>()));
      await expectLater(env.cards.cycleSummary(bank.id), throwsA(isA<NotACreditCardException>()));
      await expectLater(env.cards.statements(bank.id), throwsA(isA<NotACreditCardException>()));
    });

    test('corte duplicado y períodos solapados', () async {
      await env.cards.registerStatement(input());
      await expectLater(env.cards.registerStatement(input()),
          throwsA(isA<DuplicateStatementException>()));
      await expectLater(
          env.cards.registerStatement(
              input(closing: DateTime(2026, 10, 21), start: DateTime(2026, 9, 10))),
          throwsA(isA<StatementOverlapException>()));
      // Siguiente ciclo contiguo: válido.
      await env.cards.registerStatement(input(closing: DateTime(2026, 10, 21)));
    });

    test('montos y fechas coherentes', () async {
      await expectLater(env.cards.registerStatement(input(minimum: 80000)),
          throwsA(isA<InvalidInputException>()));
      await expectLater(env.cards.registerStatement(input(balance: -1, minimum: 0)),
          throwsA(isA<InvalidInputException>()));
      await expectLater(
          env.cards.registerStatement(input(due: DateTime(2026, 9, 21))),
          throwsA(isA<InvalidInputException>()));
      await expectLater(
          env.cards.registerStatement(input(start: DateTime(2026, 9, 22))),
          throwsA(isA<InvalidInputException>()));
    });

    test('el banco puede fijar otra fecha de pago', () async {
      final s = await env.cards.registerStatement(input(due: DateTime(2026, 10, 16)));
      expect(s.dueDate, DateTime(2026, 10, 16));
    });

    test('un estado con saldo cero es válido y queda pagado', () async {
      final s = await env.cards.registerStatement(input(balance: 0, minimum: 0));
      env.clock.current = DateTime(2026, 11, 1);
      expect((await env.cards.statementView(s.id)).status, StatementStatus.paid);
    });
  });

  group('edición y archivo de estados de cuenta', () {
    test('updateStatement corrige montos, revalida y toca updatedAt', () async {
      await purchases();
      final s = await officialSeptember();
      env.clock.current = DateTime(2026, 10, 2);
      await env.cards.updateStatement(s.id,
          balanceMinor: 80000, minimumMinor: 8000, note: 'Corregido');
      final u = (await env.cards.statementView(s.id)).statement;
      expect(u.statementBalanceMinor, 80000);
      expect(u.note, 'Corregido');
      expect(u.updatedAt, DateTime(2026, 10, 2));
      expect(u.createdAt, DateTime(2026, 9, 30, 9));
      await expectLater(env.cards.updateStatement(s.id, minimumMinor: 90000),
          throwsA(isA<InvalidInputException>()));
      await expectLater(env.cards.updateStatement(s.id, dueDate: DateTime(2026, 9, 1)),
          throwsA(isA<InvalidInputException>()));
      await expectLater(env.cards.updateStatement('nope', balanceMinor: 1),
          throwsA(isA<NotFoundException>()));
    });

    test('archivar oculta el estado de la lista', () async {
      final s = await officialSeptember();
      await env.cards.setStatementArchived(s.id, true);
      expect(await env.cards.statements(visa.id), isEmpty);
      expect(await env.cards.statements(visa.id, includeArchived: true), hasLength(1));
    });

    test('statements devuelve del corte más reciente al más antiguo', () async {
      await officialSeptember();
      await env.cards.registerStatement(StatementInput(
          accountId: visa.id,
          closingDate: DateTime(2026, 10, 21),
          statementBalanceMinor: 1000,
          minimumPaymentMinor: 100));
      final list = await env.cards.statements(visa.id);
      expect(list.map((v) => v.statement.closingDate),
          [DateTime(2026, 10, 21), DateTime(2026, 9, 21)]);
    });
  });

  group('sugerencia de estado de cuenta para un pago', () {
    test('ninguno, el más antiguo sin pagar, y salta los pagados', () async {
      expect(await env.cards.suggestStatementForPayment(visa.id), isNull);
      env.clock.current = DateTime(2026, 10, 1);
      final sept = await officialSeptember();
      final oct = await env.cards.registerStatement(StatementInput(
          accountId: visa.id,
          closingDate: DateTime(2026, 10, 21),
          statementBalanceMinor: 50000,
          minimumPaymentMinor: 5000));
      expect(await env.cards.suggestStatementForPayment(visa.id), sept.id);
      await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 10, 2), statementId: sept.id);
      expect(await env.cards.suggestStatementForPayment(visa.id), oct.id);
    });

    test('solo para tarjetas', () async {
      await expectLater(env.cards.suggestStatementForPayment(bank.id),
          throwsA(isA<NotACreditCardException>()));
    });
  });

  test('watchOverview refleja nuevas compras', () async {
    env.clock.current = DateTime(2026, 9, 30);
    final it = StreamIterator(env.cards.watchOverview(visa.id));
    await it.moveNext();
    expect(it.current.owedMinor, 0);
    await env.expense(visa.id, 12000, DateTime(2026, 9, 30));
    await it.moveNext();
    expect(it.current.owedMinor, 12000);
    expect(it.current.availableCreditMinor, 988000);
    await it.cancel();
  });

  group('estimatedBalanceAt', () {
    test('devuelve la deuda al final del día de corte, sin las compras posteriores', () async {
      await purchases();
      expect(await env.cards.estimatedBalanceAt(visa.id, DateTime(2026, 9, 21)), 75000);
      expect(await env.cards.estimatedBalanceAt(visa.id, DateTime(2026, 9, 20)), 60000);
      expect(await env.cards.estimatedBalanceAt(visa.id, DateTime(2026, 9, 22)), 115000);
      expect(await env.cards.estimatedBalanceAt(visa.id, DateTime(2026, 8, 21)), 0);
    });

    test('incluye la deuda inicial y descuenta pagos', () async {
      final other = await env.card(name: 'Master', initial: -20000);
      await env.expense(other.id, 5000, DateTime(2026, 9, 10));
      await env.transfer(bank.id, other.id, 8000, DateTime(2026, 9, 15));
      expect(await env.cards.estimatedBalanceAt(other.id, DateTime(2026, 9, 21)), 17000);
    });

    test('falla si la cuenta no es una tarjeta', () async {
      await expectLater(
          env.cards.estimatedBalanceAt(bank.id, DateTime(2026, 9, 21)),
          throwsA(isA<NotACreditCardException>()));
    });

    test('coincide con el estimado de statementView', () async {
      await purchases();
      final s = await officialSeptember();
      expect((await env.cards.statementView(s.id)).estimatedBalanceMinor,
          await env.cards.estimatedBalanceAt(visa.id, s.closingDate));
    });
  });

  group('pendingStatements', () {
    Future<CreditCardStatement> statementFor(Account card, DateTime closing, int balance) =>
        env.cards.registerStatement(StatementInput(
            accountId: card.id,
            closingDate: closing,
            statementBalanceMinor: balance,
            minimumPaymentMinor: balance ~/ 10));

    test('lista los no pagados de todas las tarjetas por fecha de pago', () async {
      final master = await env.card(name: 'Master', statementDay: 5, dueDay: 25);
      await purchases();
      await officialSeptember(); // pago 15 oct
      await statementFor(master, DateTime(2026, 9, 5), 30000); // pago 25 sep

      final pending = await env.cards.pendingStatements();
      expect(pending.map((p) => p.card.name), ['Master', 'Visa']);
      expect(pending.first.pendingMinor, 30000);
      expect(pending.last.pendingMinor, 75000);
      expect(pending.last.minimumPendingMinor, 7500);
    });

    test('sale de la lista al pagarse por completo y descuenta lo pagado', () async {
      await purchases();
      final s = await officialSeptember();
      await env.transfer(bank.id, visa.id, 7500, DateTime(2026, 9, 30));
      var pending = await env.cards.pendingStatements();
      expect(pending.single.status, StatementStatus.minimumCovered);
      expect(pending.single.pendingMinor, 67500);
      expect(pending.single.minimumPendingMinor, 0);

      await env.transfer(bank.id, visa.id, 67500, DateTime(2026, 9, 30));
      pending = await env.cards.pendingStatements();
      expect(pending, isEmpty);
      expect((await env.cards.statementView(s.id)).status, StatementStatus.paid);
    });

    test('ignora estados archivados y tarjetas archivadas; marca los vencidos', () async {
      await purchases();
      final s = await officialSeptember();
      env.clock.current = DateTime(2026, 10, 16, 9);
      expect((await env.cards.pendingStatements()).single.status, StatementStatus.overdue);

      await env.cards.setStatementArchived(s.id, true);
      expect(await env.cards.pendingStatements(), isEmpty);
      await env.cards.setStatementArchived(s.id, false);
      await env.accounts.update(visa.id, isArchived: true);
      expect(await env.cards.pendingStatements(), isEmpty);
    });

    test('watchPendingStatements emite al registrar y al pagar', () async {
      await purchases();
      final it = StreamIterator(env.cards.watchPendingStatements());
      await it.moveNext();
      expect(it.current, isEmpty);
      await officialSeptember();
      await it.moveNext();
      expect(it.current, hasLength(1));
      await env.transfer(bank.id, visa.id, 75000, DateTime(2026, 9, 30));
      await it.moveNext();
      expect(it.current, isEmpty);
      await it.cancel();
    });
  });
}
