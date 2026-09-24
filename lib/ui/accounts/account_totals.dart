import '../../app/providers.dart';
import 'account_labels.dart';

/// Saldo total por moneda: cuentas activas que no son tarjeta.
Map<String, int> totalsByCurrency(Iterable<AccountBalance> balances) {
  final totals = <String, int>{};
  for (final b in balances) {
    if (b.account.isArchived || !isPlainAccount(b.account)) continue;
    totals[b.account.currency] = (totals[b.account.currency] ?? 0) + b.balanceMinor;
  }
  return totals;
}
