import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'models.dart';
import 'reactive.dart';
import 'transaction_repository.dart';
import 'validation.dart';

/// Deudas con personas (las tarjetas de crédito no van aquí).
///
/// Movimientos de una deuda (`Transactions.debtId`), según la dirección:
///
/// | Deuda                | Origen (nace la deuda)  | Abono                  |
/// |----------------------|-------------------------|------------------------|
/// | `owedToMe`           | `expense` desde mi cuenta | `income` a mi cuenta |
/// | `iOwe`               | `income` a mi cuenta      | `expense` desde mi cuenta |
///
/// Solo los abonos restan del saldo: `pendiente = principal − Σ abonos`.
class DebtRepository {
  DebtRepository(this._db, {this._now = DateTime.now})
      : _transactions = TransactionRepository(_db, now: _now);

  final AppDatabase _db;
  final Now _now;
  final TransactionRepository _transactions;

  /// Crea la deuda y, si se indica `originAccountId`, su movimiento de origen
  /// (por el monto del principal, sin categoría) en una sola transacción.
  /// Sin cuenta de origen sirve para deudas históricas.
  Future<Debt> create(DebtInput input, {String? originAccountId}) =>
      _db.transaction(() async {
        if (input.principalMinor <= 0) throw const InvalidAmountException();
        final description = requireText(input.description, 'La descripción', max: 200);
        final currency = normalizeCurrency(input.currency);
        final start = dateOnly(input.startDate);
        final due = input.dueDate == null ? null : dateOnly(input.dueDate!);
        if (due != null && due.isBefore(start)) {
          throw const InvalidInputException(
              'La fecha de vencimiento no puede ser anterior al inicio');
        }
        final contact = await (_db.select(_db.contacts)
              ..where((c) => c.id.equals(input.contactId)))
            .getSingleOrNull();
        if (contact == null) throw NotFoundException('Contacto', input.contactId);

        final n = _now();
        final debt = await _db.into(_db.debts).insertReturning(
              DebtsCompanion.insert(
                contactId: input.contactId,
                direction: input.direction,
                principalMinor: input.principalMinor,
                currency: currency,
                description: description,
                startDate: start,
                dueDate: Value(due),
                createdAt: Value(n),
                updatedAt: Value(n),
              ),
            );
        if (originAccountId != null) {
          await _transactions.create(TransactionInput(
            accountId: originAccountId,
            type: originTypeOf(input.direction),
            amountMinor: input.principalMinor,
            occurredAt: start,
            contactId: input.contactId,
            debtId: debt.id,
            note: description,
          ));
        }
        return debt;
      });

  Future<void> update(
    String id, {
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) async {
    final rows = await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        description: Value.absentIfNull(
            description == null ? null : requireText(description, 'La descripción', max: 200)),
        dueDate: clearDueDate
            ? const Value(null)
            : Value.absentIfNull(dueDate == null ? null : dateOnly(dueDate)),
        updatedAt: Value(_now()),
      ),
    );
    if (rows == 0) throw NotFoundException('Deuda', id);
  }

  /// Marca la deuda como saldada. Exige que no quede saldo pendiente; para
  /// cerrarla con saldo usar [forgive].
  Future<void> settle(String id) => _db.transaction(() async {
        final b = await balance(id);
        if (!b.isFullyPaid) {
          throw DebtNotFullyPaidException(
              'Quedan ${b.pendingMinor} por pagar de la deuda "$id"');
        }
        await _setStatus(id, DebtStatus.settled);
      });

  /// Cierra la deuda perdonando el saldo pendiente.
  Future<void> forgive(String id) => _setStatus(id, DebtStatus.forgiven);

  Future<void> reopen(String id) => _setStatus(id, DebtStatus.open);

  Future<void> setArchived(String id, bool archived) async {
    final rows = await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(isArchived: Value(archived), updatedAt: Value(_now())),
    );
    if (rows == 0) throw NotFoundException('Deuda', id);
  }

  Future<void> _setStatus(String id, DebtStatus status) async {
    final rows = await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(status: Value(status), updatedAt: Value(_now())),
    );
    if (rows == 0) throw NotFoundException('Deuda', id);
  }

  // -------------------------------------------------------------------------
  // Lectura
  // -------------------------------------------------------------------------

  Future<Debt?> get(String id) =>
      (_db.select(_db.debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<DebtBalance> balance(String id) async {
    final debt = await get(id) ?? (throw NotFoundException('Deuda', id));
    final paid = await _paidByDebt(id: id);
    return DebtBalance(debt: debt, paidMinor: paid[id] ?? 0);
  }

  Stream<DebtBalance> watchBalance(String id) =>
      watchComputed(_db, [_db.debts, _db.transactions], () => balance(id));

  Future<List<DebtBalance>> list({
    DebtDirection? direction,
    DebtStatus? status,
    bool includeArchived = false,
  }) async {
    final q = _db.select(_db.debts)..orderBy([(d) => OrderingTerm.desc(d.startDate)]);
    q.where((d) {
      Expression<bool> e = const Constant(true);
      if (direction != null) e = e & d.direction.equalsValue(direction);
      if (status != null) e = e & d.status.equalsValue(status);
      if (!includeArchived) e = e & d.isArchived.equals(false);
      return e;
    });
    final debts = await q.get();
    final paid = await _paidByDebt();
    return [for (final d in debts) DebtBalance(debt: d, paidMinor: paid[d.id] ?? 0)];
  }

  Stream<List<DebtBalance>> watch({
    DebtDirection? direction,
    DebtStatus? status,
    bool includeArchived = false,
  }) =>
      watchComputed(
        _db,
        [_db.debts, _db.transactions],
        () => list(direction: direction, status: status, includeArchived: includeArchived),
      );

  /// Abonos por deuda: movimientos con `debtId` cuyo tipo es el de abono para
  /// la dirección de la deuda (el de origen tiene el tipo contrario).
  Future<Map<String, int>> _paidByDebt({String? id}) async {
    final rows = await _db.customSelect(
      '''
SELECT d.id AS id, COALESCE(SUM(t.amount_minor), 0) AS paid
FROM debts d
LEFT JOIN transactions t ON t.debt_id = d.id
  AND t.type = CASE d.direction WHEN 'owedToMe' THEN 'income' ELSE 'expense' END
${id == null ? '' : 'WHERE d.id = ?'}
GROUP BY d.id''',
      variables: [if (id != null) Variable.withString(id)],
      readsFrom: {_db.debts, _db.transactions},
    ).get();
    return {for (final r in rows) r.read<String>('id'): r.read<int>('paid')};
  }
}
