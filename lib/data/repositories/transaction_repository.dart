import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import '../database/seed.dart';
import 'ledger_queries.dart';
import 'models.dart';
import 'reactive.dart';

class TransactionRepository {
  TransactionRepository(this._db, {this._now = DateTime.now}) : _ledger = LedgerQueries(_db);

  final AppDatabase _db;
  final Now _now;
  final LedgerQueries _ledger;

  // -------------------------------------------------------------------------
  // Escritura
  // -------------------------------------------------------------------------

  /// Crea un movimiento (y sus etiquetas) en una sola transacción.
  ///
  /// Si es una transferencia hacia una tarjeta de crédito sin `statementId` y
  /// `autoAssignStatement` es verdadero, se vincula al estado de cuenta que
  /// devuelve `suggestStatementForPayment` (si existe). Pasar `false` para,
  /// por ejemplo, un pago adelantado del ciclo en curso.
  Future<Transaction> create(
    TransactionInput input, {
    Set<String> tagIds = const {},
    bool autoAssignStatement = true,
  }) =>
      _db.transaction(() async {
        var i = input;
        if (autoAssignStatement &&
            i.type == TransactionType.transfer &&
            i.statementId == null &&
            i.transferAccountId != null) {
          final dest = await _account(i.transferAccountId!);
          if (dest != null && dest.type == AccountType.creditCard) {
            i = i.withStatement(await _ledger.suggestStatementForPayment(dest.id, _now()));
          }
        }
        await _validate(i);
        final n = _now();
        final tx = await _db.into(_db.transactions).insertReturning(
              TransactionsCompanion.insert(
                accountId: i.accountId,
                type: i.type,
                amountMinor: i.amountMinor,
                occurredAt: i.occurredAt,
                categoryId: Value(i.categoryId),
                transferAccountId: Value(i.transferAccountId),
                transferAmountMinor: Value(i.transferAmountMinor),
                contactId: Value(i.contactId),
                debtId: Value(i.debtId),
                statementId: Value(i.statementId),
                note: Value(i.note),
                receiptPath: Value(i.receiptPath),
                createdAt: Value(n),
                updatedAt: Value(n),
              ),
            );
        await _replaceTags(tx.id, tagIds);
        return tx;
      });

  /// Reemplaza todos los campos del movimiento. `tagIds` nulo = no tocar las
  /// etiquetas. No se asigna estado de cuenta automáticamente.
  Future<void> update(String id, TransactionInput input, {Set<String>? tagIds}) =>
      _db.transaction(() async {
        final existing = await get(id) ?? (throw NotFoundException('Movimiento', id));
        await _validate(input, existing: existing);
        await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            accountId: Value(input.accountId),
            type: Value(input.type),
            amountMinor: Value(input.amountMinor),
            occurredAt: Value(input.occurredAt),
            categoryId: Value(input.categoryId),
            transferAccountId: Value(input.transferAccountId),
            transferAmountMinor: Value(input.transferAmountMinor),
            contactId: Value(input.contactId),
            debtId: Value(input.debtId),
            statementId: Value(input.statementId),
            note: Value(input.note),
            receiptPath: Value(input.receiptPath),
            updatedAt: Value(_now()),
          ),
        );
        if (tagIds != null) await _replaceTags(id, tagIds);
      });

  /// Reemplaza solo las etiquetas de un movimiento (y actualiza su `updatedAt`).
  Future<void> setTags(String id, Set<String> tagIds) => _db.transaction(() async {
        if (await get(id) == null) throw NotFoundException('Movimiento', id);
        await _replaceTags(id, tagIds);
        await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
            .write(TransactionsCompanion(updatedAt: Value(_now())));
      });

  /// Borrado real (los movimientos no se archivan). Las etiquetas asociadas
  /// se eliminan en cascada.
  Future<void> delete(String id) async {
    final rows = await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    if (rows == 0) throw NotFoundException('Movimiento', id);
  }

  // -------------------------------------------------------------------------
  // Lectura
  // -------------------------------------------------------------------------

  Future<Transaction?> get(String id) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Transaction>> list(TransactionFilter filter) => _query(filter).get();

  Stream<List<Transaction>> watch(TransactionFilter filter) => _query(filter).watch();

  SimpleSelectStatement<$TransactionsTable, Transaction> _query(TransactionFilter f) {
    final q = _db.select(_db.transactions);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (f.accountId != null) {
        e = e & (t.accountId.equals(f.accountId!) | t.transferAccountId.equals(f.accountId!));
      }
      if (f.categoryId != null) e = e & t.categoryId.equals(f.categoryId!);
      if (f.contactId != null) e = e & t.contactId.equals(f.contactId!);
      if (f.debtId != null) e = e & t.debtId.equals(f.debtId!);
      if (f.statementId != null) e = e & t.statementId.equals(f.statementId!);
      if (f.type != null) e = e & t.type.equalsValue(f.type!);
      if (f.from != null) e = e & t.occurredAt.isBiggerOrEqualValue(f.from!);
      if (f.to != null) e = e & t.occurredAt.isSmallerThanValue(f.to!);
      if (f.tagId != null) {
        final tagged = _db.selectOnly(_db.transactionTags)
          ..addColumns([_db.transactionTags.transactionId])
          ..where(_db.transactionTags.tagId.equals(f.tagId!));
        e = e & t.id.isInQuery(tagged);
      }
      return e;
    });
    q.orderBy([
      (t) => OrderingTerm.desc(t.occurredAt),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    if (f.limit != null) q.limit(f.limit!, offset: f.offset);
    return q;
  }

  // -------------------------------------------------------------------------
  // Totales (excluyen transferencias y movimientos con debtId)
  // -------------------------------------------------------------------------

  /// Totales por moneda en `[from, to)`.
  ///
  /// - `incomeMinor`: ingresos sin la categoría del sistema "Devoluciones".
  /// - `refundsMinor`: ingresos con esa categoría.
  /// - `expenseMinor`: gastos − devoluciones (neto).
  Future<List<PeriodTotals>> totals({
    required DateTime from,
    required DateTime to,
    Set<String>? accountIds,
  }) async {
    if (accountIds != null && accountIds.isEmpty) return [];
    final accountClause = accountIds == null
        ? ''
        : ' AND t.account_id IN (${List.filled(accountIds.length, '?').join(',')})';
    final rows = await _db.customSelect(
      '''
SELECT a.currency AS currency,
  COALESCE(SUM(CASE WHEN t.type = 'income' AND COALESCE(t.category_id, '') <> ?
                    THEN t.amount_minor END), 0) AS income,
  COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount_minor END), 0) AS gross_expense,
  COALESCE(SUM(CASE WHEN t.type = 'income' AND t.category_id = ?
                    THEN t.amount_minor END), 0) AS refunds
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.debt_id IS NULL AND t.type IN ('income', 'expense')
  AND t.occurred_at >= ? AND t.occurred_at < ?$accountClause
GROUP BY a.currency ORDER BY a.currency''',
      variables: [
        Variable.withString(kRefundsCategoryId),
        Variable.withString(kRefundsCategoryId),
        Variable.withDateTime(from),
        Variable.withDateTime(to),
        if (accountIds != null) ...accountIds.map(Variable.withString),
      ],
      readsFrom: {_db.transactions, _db.accounts},
    ).get();
    return [
      for (final r in rows)
        PeriodTotals(
          currency: r.read<String>('currency'),
          incomeMinor: r.read<int>('income'),
          expenseMinor: r.read<int>('gross_expense') - r.read<int>('refunds'),
          refundsMinor: r.read<int>('refunds'),
        ),
    ];
  }

  Stream<List<PeriodTotals>> watchTotals({
    required DateTime from,
    required DateTime to,
    Set<String>? accountIds,
  }) =>
      watchComputed(_db, [_db.transactions, _db.accounts],
          () => totals(from: from, to: to, accountIds: accountIds));

  /// Totales por (moneda, categoría) en `[from, to)`, de mayor a menor dentro
  /// de cada moneda. En gastos se añade una línea **negativa** con las
  /// devoluciones (`system:refunds`); en ingresos las devoluciones no aparecen.
  Future<List<CategoryTotal>> totalsByCategory({
    required DateTime from,
    required DateTime to,
    required CategoryKind kind,
    String? currency,
  }) async {
    Future<List<QueryRow>> query(String type, {required bool refunds}) {
      final categoryClause =
          refunds ? 't.category_id = ?' : "COALESCE(t.category_id, '') <> ?";
      return _db.customSelect(
        '''
SELECT a.currency AS currency, t.category_id AS category_id, SUM(t.amount_minor) AS total
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.debt_id IS NULL AND t.type = ? AND $categoryClause
  AND t.occurred_at >= ? AND t.occurred_at < ?${currency == null ? '' : ' AND a.currency = ?'}
GROUP BY a.currency, t.category_id''',
        variables: [
          Variable.withString(type),
          Variable.withString(kRefundsCategoryId),
          Variable.withDateTime(from),
          Variable.withDateTime(to),
          if (currency != null) Variable.withString(currency),
        ],
        readsFrom: {_db.transactions, _db.accounts},
      ).get();
    }

    final isExpense = kind == CategoryKind.expense;
    final main = await query(isExpense ? 'expense' : 'income', refunds: false);
    final refundRows = isExpense ? await query('income', refunds: true) : <QueryRow>[];
    final result = [
      for (final r in main)
        CategoryTotal(
          currency: r.read<String>('currency'),
          categoryId: r.read<String?>('category_id'),
          totalMinor: r.read<int>('total'),
        ),
      for (final r in refundRows)
        CategoryTotal(
          currency: r.read<String>('currency'),
          categoryId: kRefundsCategoryId,
          totalMinor: -r.read<int>('total'),
        ),
    ]..sort((a, b) {
        final byCurrency = a.currency.compareTo(b.currency);
        return byCurrency != 0 ? byCurrency : b.totalMinor.compareTo(a.totalMinor);
      });
    return result;
  }

  // -------------------------------------------------------------------------
  // Validación
  // -------------------------------------------------------------------------

  Future<Account?> _account(String id) =>
      (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> _validate(TransactionInput i, {Transaction? existing}) async {
    if (i.amountMinor <= 0) throw const InvalidAmountException();

    final isTransfer = i.type == TransactionType.transfer;
    if (isTransfer) {
      if (i.transferAccountId == null) {
        throw const InvalidTransferException('Una transferencia requiere cuenta destino');
      }
      if (i.transferAccountId == i.accountId) {
        throw const InvalidTransferException('El origen y el destino deben ser distintos');
      }
    } else if (i.transferAccountId != null || i.transferAmountMinor != null) {
      throw const InvalidTransferException(
          'Solo las transferencias llevan cuenta y monto de destino');
    }

    final source = await _account(i.accountId) ??
        (throw NotFoundException('Cuenta', i.accountId));
    final dest = isTransfer
        ? await _account(i.transferAccountId!) ??
            (throw NotFoundException('Cuenta', i.transferAccountId!))
        : null;

    // No se aceptan movimientos nuevos en cuentas archivadas; al editar se
    // permite conservar la cuenta que ya tenía el movimiento.
    if (source.isArchived && existing?.accountId != source.id) {
      throw ArchivedAccountException(source.id);
    }
    if (dest != null && dest.isArchived && existing?.transferAccountId != dest.id) {
      throw ArchivedAccountException(dest.id);
    }

    if (dest != null) {
      final differs = source.currency != dest.currency;
      final destAmount = i.transferAmountMinor;
      if (differs && (destAmount == null || destAmount <= 0)) {
        throw const InvalidTransferException(
            'Las cuentas tienen monedas distintas: indica el monto de destino');
      }
      if (!differs && destAmount != null) {
        throw const InvalidTransferException(
            'Las cuentas tienen la misma moneda: no lleva monto de destino');
      }
    }

    if (i.categoryId != null) {
      if (isTransfer) {
        throw const InvalidTransferException('Las transferencias no llevan categoría');
      }
      if (i.debtId != null) {
        throw const DebtMovementCategoryException(
            'Los movimientos de deuda no llevan categoría');
      }
      final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(i.categoryId!)))
          .getSingleOrNull() ??
          (throw NotFoundException('Categoría', i.categoryId!));
      final expected = i.type == TransactionType.income
          ? CategoryKind.income
          : CategoryKind.expense;
      if (category.kind != expected) {
        throw CategoryKindMismatchException(
            'La categoría "${category.name}" es de ${category.kind.name} y el '
            'movimiento es de ${i.type.name}');
      }
    }

    if (i.statementId != null) {
      if (!isTransfer) {
        throw const InvalidStatementLinkException(
            'Solo una transferencia puede vincularse a un estado de cuenta');
      }
      final statement = await (_db.select(_db.creditCardStatements)
            ..where((s) => s.id.equals(i.statementId!)))
          .getSingleOrNull() ??
          (throw NotFoundException('Estado de cuenta', i.statementId!));
      if (statement.accountId != i.transferAccountId) {
        throw const InvalidStatementLinkException(
            'El destino del pago debe ser la tarjeta del estado de cuenta');
      }
    }

    if (i.debtId != null) {
      if (isTransfer) {
        throw const InvalidInputException(
            'Una transferencia no puede ser un movimiento de deuda');
      }
      final debt = await (_db.select(_db.debts)..where((d) => d.id.equals(i.debtId!)))
              .getSingleOrNull() ??
          (throw NotFoundException('Deuda', i.debtId!));
      if (debt.currency != source.currency) {
        throw CurrencyMismatchException(
            'La deuda es en ${debt.currency} y la cuenta en ${source.currency}');
      }
    }

    if (i.contactId != null) {
      final contact = await (_db.select(_db.contacts)
            ..where((c) => c.id.equals(i.contactId!)))
          .getSingleOrNull();
      if (contact == null) throw NotFoundException('Contacto', i.contactId!);
    }
  }

  Future<void> _replaceTags(String transactionId, Set<String> tagIds) async {
    if (tagIds.isNotEmpty) {
      final found = await (_db.select(_db.tags)..where((t) => t.id.isIn(tagIds))).get();
      final missing = tagIds.difference(found.map((t) => t.id).toSet());
      if (missing.isNotEmpty) throw NotFoundException('Etiqueta', missing.first);
    }
    await (_db.delete(_db.transactionTags)
          ..where((t) => t.transactionId.equals(transactionId)))
        .go();
    for (final tagId in tagIds) {
      await _db.into(_db.transactionTags).insert(
            TransactionTagsCompanion.insert(transactionId: transactionId, tagId: tagId),
          );
    }
  }
}
