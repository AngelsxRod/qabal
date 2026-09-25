import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/credit_card/card_cycle.dart';
import '../../domain/credit_card/statement_status.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'ledger_queries.dart';
import 'models.dart';
import 'reactive.dart';

/// Ciclos y estados de cuenta de tarjetas de crédito.
///
/// Convención: el saldo de una tarjeta es negativo cuando se debe;
/// `deuda = −saldo`. Todo lo "del ciclo" se calcula a partir de los
/// movimientos; el valor oficial es el que se registra del banco en
/// [registerStatement].
class CreditCardRepository {
  CreditCardRepository(this._db, {this._now = DateTime.now}) : _ledger = LedgerQueries(_db);

  final AppDatabase _db;
  final Now _now;
  final LedgerQueries _ledger;

  /// Medianoche local del día siguiente: fin exclusivo de una ventana que
  /// incluye `d`.
  static DateTime _dayAfter(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  Future<(Account, CreditCardDetail)> _card(String accountId) async {
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId)))
            .getSingleOrNull() ??
        (throw NotFoundException('Cuenta', accountId));
    if (account.type != AccountType.creditCard) throw NotACreditCardException(accountId);
    final details = await (_db.select(_db.creditCardDetails)
              ..where((d) => d.accountId.equals(accountId)))
            .getSingleOrNull() ??
        (throw NotFoundException('Detalles de tarjeta', accountId));
    return (account, details);
  }

  // -------------------------------------------------------------------------
  // Resumen del ciclo
  // -------------------------------------------------------------------------

  Future<CardOverview> overview(String accountId) async {
    final (account, details) = await _card(accountId);
    return CardOverview(
      account: account,
      settings: details,
      balanceMinor: await _ledger.balanceOf(accountId),
      summary: await cycleSummary(accountId),
    );
  }

  Stream<CardOverview> watchOverview(String accountId) => watchComputed(
        _db,
        [_db.accounts, _db.transactions, _db.creditCardDetails, _db.creditCardStatements],
        () => overview(accountId),
      );

  /// Ciclo al que pertenece `forDate` (por defecto hoy), con sus movimientos
  /// y el saldo estimado al corte. La deuda no pagada de ciclos anteriores no
  /// se reinicia: entra en `openingDebtMinor` y por tanto en el estimado.
  Future<CardCycleSummary> cycleSummary(String accountId, {DateTime? forDate}) async {
    final (_, details) = await _card(accountId);
    final cycle = cycleForPurchase(
      forDate ?? _now(),
      statementDay: details.statementDay,
      dueDay: details.dueDay,
    );
    final movements = await _ledger.cycleMovements(
        accountId, cycle.periodStart, _dayAfter(cycle.closingDate));

    final closing = movements.closingDebtMinor;
    final bp = details.minPaymentBp;
    final estimatedMinimum = (bp != null && closing > 0) ? (closing * bp + 9999) ~/ 10000 : null;

    final previous = await (_db.select(_db.creditCardStatements)
          ..where((s) =>
              s.accountId.equals(accountId) &
              s.isArchived.equals(false) &
              s.closingDate.isSmallerThanValue(LedgerQueries.dateKey(cycle.periodStart)))
          ..orderBy([(s) => OrderingTerm.desc(s.closingDate)])
          ..limit(1))
        .getSingleOrNull();
    int? previousPending;
    if (previous != null) {
      final paid = (await _ledger.paidByStatement([previous.id]))[previous.id] ?? 0;
      final pending = previous.statementBalanceMinor - paid;
      previousPending = pending > 0 ? pending : 0;
    }

    return CardCycleSummary(
      cycle: cycle,
      movements: movements,
      estimatedMinimumMinor: estimatedMinimum,
      previousStatementPendingMinor: previousPending,
    );
  }

  // -------------------------------------------------------------------------
  // Estados de cuenta
  // -------------------------------------------------------------------------

  /// Registra un estado de cuenta con los valores del banco. `periodStart` y
  /// `dueDate` se derivan del horario de la tarjeta si no se indican.
  Future<CreditCardStatement> registerStatement(StatementInput input) =>
      _db.transaction(() async {
        final (_, details) = await _card(input.accountId);
        final closing = dateOnly(input.closingDate);
        final derived = cycleClosingOn(closing.year, closing.month,
            statementDay: details.statementDay, dueDay: details.dueDay);
        final start = dateOnly(input.periodStart ?? derived.periodStart);
        final due = dateOnly(input.dueDate ?? derived.dueDate);

        _validateAmounts(input.statementBalanceMinor, input.minimumPaymentMinor);
        _validateDates(start, closing, due);

        final closingKey = LedgerQueries.dateKey(closing);
        final startKey = LedgerQueries.dateKey(start);
        final duplicate = await (_db.select(_db.creditCardStatements)
              ..where((s) => s.accountId.equals(input.accountId) & s.closingDate.equals(closingKey)))
            .getSingleOrNull();
        if (duplicate != null) {
          throw DuplicateStatementException(
              'Ya hay un estado de cuenta con corte $closingKey para esta tarjeta');
        }
        final overlapping = await (_db.select(_db.creditCardStatements)
              ..where((s) =>
                  s.accountId.equals(input.accountId) &
                  s.isArchived.equals(false) &
                  s.closingDate.isBiggerOrEqualValue(startKey) &
                  s.periodStart.isSmallerOrEqualValue(closingKey))
              ..limit(1))
            .getSingleOrNull();
        if (overlapping != null) {
          throw StatementOverlapException(
              'El período $startKey – $closingKey se solapa con otro estado de cuenta');
        }

        final n = _now();
        return _db.into(_db.creditCardStatements).insertReturning(
              CreditCardStatementsCompanion.insert(
                accountId: input.accountId,
                periodStart: start,
                closingDate: closing,
                dueDate: due,
                statementBalanceMinor: input.statementBalanceMinor,
                minimumPaymentMinor: input.minimumPaymentMinor,
                note: Value(input.note),
                createdAt: Value(n),
                updatedAt: Value(n),
              ),
            );
      });

  Future<void> updateStatement(
    String id, {
    int? balanceMinor,
    int? minimumMinor,
    DateTime? dueDate,
    String? note,
  }) =>
      _db.transaction(() async {
        final s = await _statement(id);
        final balance = balanceMinor ?? s.statementBalanceMinor;
        final minimum = minimumMinor ?? s.minimumPaymentMinor;
        final due = dueDate == null ? s.dueDate : dateOnly(dueDate);
        _validateAmounts(balance, minimum);
        _validateDates(s.periodStart, s.closingDate, due);
        await (_db.update(_db.creditCardStatements)..where((x) => x.id.equals(id))).write(
          CreditCardStatementsCompanion(
            statementBalanceMinor: Value(balance),
            minimumPaymentMinor: Value(minimum),
            dueDate: Value(due),
            note: Value.absentIfNull(note),
            updatedAt: Value(_now()),
          ),
        );
      });

  Future<void> setStatementArchived(String id, bool archived) async {
    final rows = await (_db.update(_db.creditCardStatements)..where((s) => s.id.equals(id)))
        .write(CreditCardStatementsCompanion(
      isArchived: Value(archived),
      updatedAt: Value(_now()),
    ));
    if (rows == 0) throw NotFoundException('Estado de cuenta', id);
  }

  Future<StatementView> statementView(String id) async {
    final s = await _statement(id);
    final paid = (await _ledger.paidByStatement([id]))[id] ?? 0;
    return _view(s, paid, _now());
  }

  /// Estados de cuenta de la tarjeta, del corte más reciente al más antiguo.
  Future<List<StatementView>> statements(String cardId, {bool includeArchived = false}) async {
    await _card(cardId);
    final q = _db.select(_db.creditCardStatements)
      ..where((s) => s.accountId.equals(cardId))
      ..orderBy([(s) => OrderingTerm.desc(s.closingDate)]);
    if (!includeArchived) q.where((s) => s.isArchived.equals(false));
    final list = await q.get();
    final paid = await _ledger.paidByStatement(list.map((s) => s.id));
    final today = _now();
    return [for (final s in list) await _view(s, paid[s.id] ?? 0, today)];
  }

  Stream<List<StatementView>> watchStatements(String cardId, {bool includeArchived = false}) =>
      watchComputed(
        _db,
        [_db.transactions, _db.creditCardStatements, _db.accounts],
        () => statements(cardId, includeArchived: includeArchived),
      );

  /// Deuda estimada por la app al final del día `closingDate` (positiva si se
  /// debe): lo que debería decir el estado de cuenta de ese corte.
  Future<int> estimatedBalanceAt(String cardId, DateTime closingDate) async {
    await _card(cardId);
    return -await _ledger.balanceOf(cardId, before: _dayAfter(dateOnly(closingDate)));
  }

  /// Estados de cuenta no archivados de tarjetas activas que no están pagados
  /// por completo, de la fecha de pago más próxima a la más lejana.
  Future<List<PendingStatement>> pendingStatements() async {
    final rows = await (_db.select(_db.creditCardStatements).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.creditCardStatements.accountId)),
    ])
          ..where(_db.creditCardStatements.isArchived.equals(false) &
              _db.accounts.isArchived.equals(false))
          ..orderBy([
            OrderingTerm.asc(_db.creditCardStatements.dueDate),
            OrderingTerm.asc(_db.creditCardStatements.closingDate),
          ]))
        .get();
    final items = [
      for (final r in rows) (r.readTable(_db.accounts), r.readTable(_db.creditCardStatements)),
    ];
    final paid = await _ledger.paidByStatement(items.map((i) => i.$2.id));
    final today = _now();
    return [
      for (final (card, s) in items)
        if (_ledger.statusOf(s, paid[s.id] ?? 0, today) != StatementStatus.paid)
          PendingStatement(
            card: card,
            statement: s,
            paidMinor: paid[s.id] ?? 0,
            status: _ledger.statusOf(s, paid[s.id] ?? 0, today),
          ),
    ];
  }

  Stream<List<PendingStatement>> watchPendingStatements() => watchComputed(
        _db,
        [_db.transactions, _db.creditCardStatements, _db.accounts],
        pendingStatements,
      );

  /// Estado de cuenta al que asignar un pago nuevo: el no archivado y no
  /// pagado por completo con fecha de pago más antigua (incluye los que solo
  /// tienen el mínimo cubierto).
  Future<String?> suggestStatementForPayment(String cardId) async {
    await _card(cardId);
    return _ledger.suggestStatementForPayment(cardId, _now());
  }

  // -------------------------------------------------------------------------

  Future<CreditCardStatement> _statement(String id) async =>
      await (_db.select(_db.creditCardStatements)..where((s) => s.id.equals(id)))
          .getSingleOrNull() ??
      (throw NotFoundException('Estado de cuenta', id));

  Future<StatementView> _view(CreditCardStatement s, int paid, DateTime today) async {
    final end = _dayAfter(s.closingDate);
    return StatementView(
      statement: s,
      paidMinor: paid,
      status: _ledger.statusOf(s, paid, today),
      estimatedBalanceMinor: await estimatedBalanceAt(s.accountId, s.closingDate),
      movements: await _ledger.cycleMovements(s.accountId, s.periodStart, end),
    );
  }

  void _validateAmounts(int balance, int minimum) {
    if (balance < 0 || minimum < 0) {
      throw const InvalidInputException('Los montos del estado de cuenta no pueden ser negativos');
    }
    if (minimum > balance) {
      throw const InvalidInputException('El pago mínimo no puede superar el saldo del estado de cuenta');
    }
  }

  void _validateDates(DateTime start, DateTime closing, DateTime due) {
    if (start.isAfter(closing)) {
      throw const InvalidInputException('El inicio del período no puede ser posterior al corte');
    }
    if (!due.isAfter(closing)) {
      throw const InvalidInputException('La fecha de pago debe ser posterior al corte');
    }
  }
}
