import 'package:drift/drift.dart';

import '../../domain/credit_card/statement_status.dart';
import '../database/app_database.dart';
import '../database/date_only_converter.dart';
import '../database/seed.dart';
import 'models.dart';

/// Consultas de saldos y sumas compartidas por varios repositorios.
///
/// Los rangos de tiempo son instantes locales: `[start, end)`.
class LedgerQueries {
  LedgerQueries(this._db);

  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // Saldos
  // -------------------------------------------------------------------------

  /// Saldo por cuenta:
  ///
  /// ```
  /// initialBalance
  ///   + Σ income − Σ expense − Σ transfer saliente        (accountId = a)
  ///   + Σ COALESCE(transferAmountMinor, amount)            (transferAccountId = a)
  /// ```
  /// `before` limita a movimientos con `occurredAt < before`.
  Selectable<QueryRow> _balanceSelect({DateTime? before, String? accountId}) {
    final cut = before == null ? '' : ' AND t.occurred_at < ?';
    final sql = '''
SELECT a.id AS id,
  a.initial_balance_minor
  + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount_minor ELSE -t.amount_minor END)
              FROM transactions t WHERE t.account_id = a.id$cut), 0)
  + COALESCE((SELECT SUM(COALESCE(t.transfer_amount_minor, t.amount_minor))
              FROM transactions t WHERE t.transfer_account_id = a.id$cut), 0) AS balance
FROM accounts a${accountId == null ? '' : ' WHERE a.id = ?'}''';
    return _db.customSelect(
      sql,
      variables: [
        if (before != null) Variable.withDateTime(before),
        if (before != null) Variable.withDateTime(before),
        if (accountId != null) Variable.withString(accountId),
      ],
      readsFrom: {_db.accounts, _db.transactions},
    );
  }

  Map<String, int> _toMap(List<QueryRow> rows) =>
      {for (final r in rows) r.read<String>('id'): r.read<int>('balance')};

  Future<Map<String, int>> balances({DateTime? before}) async =>
      _toMap(await _balanceSelect(before: before).get());

  Stream<Map<String, int>> watchBalances() =>
      _balanceSelect().watch().map(_toMap);

  Future<int> balanceOf(String accountId, {DateTime? before}) async {
    final rows = await _balanceSelect(before: before, accountId: accountId).get();
    return rows.isEmpty ? 0 : rows.single.read<int>('balance');
  }

  // -------------------------------------------------------------------------
  // Tarjetas
  // -------------------------------------------------------------------------

  /// Movimientos de la tarjeta en `[start, end)`. `openingDebtMinor` es la
  /// deuda justo antes de `start`.
  Future<CycleMovements> cycleMovements(
    String cardId,
    DateTime start,
    DateTime end,
  ) async {
    final opening = -await balanceOf(cardId, before: start);
    final rows = await _db.customSelect(
      '''
SELECT
  COALESCE(SUM(CASE WHEN t.account_id = ? AND t.type = 'expense'
                     AND COALESCE(t.category_id, '') <> ? THEN t.amount_minor END), 0) AS purchases,
  COALESCE(SUM(CASE WHEN t.account_id = ? AND t.type = 'expense'
                     AND t.category_id = ? THEN t.amount_minor END), 0) AS interest,
  COALESCE(SUM(CASE WHEN t.account_id = ? AND t.type = 'transfer'
                     THEN t.amount_minor END), 0) AS advances,
  COALESCE(SUM(CASE WHEN t.account_id = ? AND t.type = 'income'
                     AND t.category_id = ? THEN t.amount_minor END), 0) AS refunds,
  COALESCE(SUM(CASE WHEN t.account_id = ? AND t.type = 'income'
                     AND COALESCE(t.category_id, '') <> ? THEN t.amount_minor END), 0) AS other_credits,
  COALESCE(SUM(CASE WHEN t.transfer_account_id = ?
                     THEN COALESCE(t.transfer_amount_minor, t.amount_minor) END), 0) AS payments
FROM transactions t
WHERE (t.account_id = ? OR t.transfer_account_id = ?)
  AND t.occurred_at >= ? AND t.occurred_at < ?''',
      variables: [
        Variable.withString(cardId), Variable.withString(kInterestFeesCategoryId),
        Variable.withString(cardId), Variable.withString(kInterestFeesCategoryId),
        Variable.withString(cardId),
        Variable.withString(cardId), Variable.withString(kRefundsCategoryId),
        Variable.withString(cardId), Variable.withString(kRefundsCategoryId),
        Variable.withString(cardId),
        Variable.withString(cardId), Variable.withString(cardId),
        Variable.withDateTime(start), Variable.withDateTime(end),
      ],
      readsFrom: {_db.transactions},
    ).getSingle();
    return CycleMovements(
      openingDebtMinor: opening,
      purchasesMinor: rows.read<int>('purchases'),
      interestMinor: rows.read<int>('interest'),
      cashAdvancesMinor: rows.read<int>('advances'),
      refundsMinor: rows.read<int>('refunds'),
      otherCreditsMinor: rows.read<int>('other_credits'),
      paymentsMinor: rows.read<int>('payments'),
    );
  }

  /// Suma de pagos vinculados (`statementId`) a cada estado de cuenta.
  Future<Map<String, int>> paidByStatement(Iterable<String> statementIds) async {
    final ids = statementIds.toList();
    if (ids.isEmpty) return {};
    final marks = List.filled(ids.length, '?').join(',');
    final rows = await _db.customSelect(
      '''
SELECT statement_id AS id, SUM(COALESCE(transfer_amount_minor, amount_minor)) AS paid
FROM transactions WHERE statement_id IN ($marks) GROUP BY statement_id''',
      variables: [for (final id in ids) Variable.withString(id)],
      readsFrom: {_db.transactions},
    ).get();
    return {
      for (final r in rows) r.read<String>('id'): r.read<int>('paid'),
    };
  }

  StatementStatus statusOf(CreditCardStatement s, int paid, DateTime today) =>
      statementStatus(
        balanceMinor: s.statementBalanceMinor,
        minimumMinor: s.minimumPaymentMinor,
        paidMinor: paid,
        dueDate: s.dueDate,
        today: today,
      );

  /// Estado de cuenta al que conviene asignar un pago nuevo: el no archivado y
  /// no pagado por completo con fecha de pago más antigua.
  Future<String?> suggestStatementForPayment(String cardId, DateTime today) async {
    final statements = await (_db.select(_db.creditCardStatements)
          ..where((s) => s.accountId.equals(cardId) & s.isArchived.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.dueDate)]))
        .get();
    final paid = await paidByStatement(statements.map((s) => s.id));
    for (final s in statements) {
      if (statusOf(s, paid[s.id] ?? 0, today) != StatementStatus.paid) return s.id;
    }
    return null;
  }

  /// Representación de fecha de calendario usada en columnas `DateOnly`.
  static String dateKey(DateTime d) => const DateOnlyConverter().toSql(d);
}
