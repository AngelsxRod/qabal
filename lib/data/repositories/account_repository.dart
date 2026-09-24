import 'package:drift/drift.dart';

import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../database/app_database.dart';
import 'ledger_queries.dart';
import 'models.dart';
import 'reactive.dart';
import 'validation.dart';

class AccountRepository {
  AccountRepository(this._db, {this._now = DateTime.now}) : _ledger = LedgerQueries(_db);

  final AppDatabase _db;
  final Now _now;
  final LedgerQueries _ledger;

  /// Crea una cuenta. Una cuenta `creditCard` exige `card` (y se crea junto con
  /// sus `CreditCardDetails` en una sola transacción); las demás lo prohíben.
  ///
  /// CONVENCIÓN DE SIGNO: en tarjetas `input.initialBalanceMinor` es
  /// **negativo** si ya hay deuda (deuda 500.00 → `-50000`). La UI debe
  /// convertir desde un valor de "deuda actual" positivo.
  Future<Account> create(AccountInput input, {CreditCardSettings? card}) {
    final name = requireText(input.name, 'El nombre');
    final currency = normalizeCurrency(input.currency);
    final isCard = input.type == AccountType.creditCard;
    if (isCard && card == null) {
      throw const InvalidInputException(
          'Una tarjeta de crédito requiere sus datos de tarjeta');
    }
    if (!isCard && card != null) {
      throw const InvalidInputException(
          'Solo las tarjetas de crédito llevan datos de tarjeta');
    }
    if (card != null) validateCardSettings(card);

    return _db.transaction(() async {
      final n = _now();
      final account = await _db.into(_db.accounts).insertReturning(
            AccountsCompanion.insert(
              name: name,
              type: input.type,
              currency: currency,
              initialBalanceMinor: Value(input.initialBalanceMinor),
              createdAt: Value(n),
              updatedAt: Value(n),
            ),
          );
      if (card != null) {
        await _db.into(_db.creditCardDetails).insert(
              CreditCardDetailsCompanion.insert(
                accountId: account.id,
                creditLimitMinor: card.creditLimitMinor,
                statementDay: card.statementDay,
                dueDay: card.dueDay,
                minPaymentBp: Value(card.minPaymentBp),
                createdAt: Value(n),
                updatedAt: Value(n),
              ),
            );
      }
      return account;
    });
  }

  /// `type` y `currency` no se pueden cambiar.
  Future<void> update(
    String id, {
    String? name,
    bool? isArchived,
    int? initialBalanceMinor,
  }) async {
    final rows = await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value.absentIfNull(name == null ? null : requireText(name, 'El nombre')),
        isArchived: Value.absentIfNull(isArchived),
        initialBalanceMinor: Value.absentIfNull(initialBalanceMinor),
        updatedAt: Value(_now()),
      ),
    );
    if (rows == 0) throw NotFoundException('Cuenta', id);
  }

  Future<void> updateCardSettings(String accountId, CreditCardSettings s) async {
    final account = await _require(accountId);
    if (account.type != AccountType.creditCard) {
      throw NotACreditCardException(accountId);
    }
    validateCardSettings(s);
    final rows = await (_db.update(_db.creditCardDetails)
          ..where((d) => d.accountId.equals(accountId)))
        .write(
      CreditCardDetailsCompanion(
        creditLimitMinor: Value(s.creditLimitMinor),
        statementDay: Value(s.statementDay),
        dueDay: Value(s.dueDay),
        minPaymentBp: Value(s.minPaymentBp),
        updatedAt: Value(_now()),
      ),
    );
    if (rows == 0) throw NotFoundException('Detalles de tarjeta', accountId);
  }

  Future<Account?> get(String id) =>
      (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<CreditCardDetail?> cardSettings(String accountId) =>
      (_db.select(_db.creditCardDetails)..where((d) => d.accountId.equals(accountId)))
          .getSingleOrNull();

  Future<List<Account>> list({bool includeArchived = false}) {
    final q = _db.select(_db.accounts)
      ..orderBy([(a) => OrderingTerm.asc(a.name)]);
    if (!includeArchived) q.where((a) => a.isArchived.equals(false));
    return q.get();
  }

  Future<AccountBalance> balance(String id) async {
    final account = await _require(id);
    return AccountBalance(account, await _ledger.balanceOf(id));
  }

  Stream<AccountBalance> watchBalance(String id) =>
      watchComputed(_db, [_db.accounts, _db.transactions], () => balance(id));

  Stream<List<AccountBalance>> watchBalances({bool includeArchived = false}) =>
      watchComputed(_db, [_db.accounts, _db.transactions], () async {
        final accounts = await list(includeArchived: includeArchived);
        final balances = await _ledger.balances();
        return [for (final a in accounts) AccountBalance(a, balances[a.id] ?? 0)];
      });

  Future<Account> _require(String id) async =>
      await get(id) ?? (throw NotFoundException('Cuenta', id));
}
