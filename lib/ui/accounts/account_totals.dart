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

/// Deuda de tarjetas por moneda (tarjetas activas): lo que se debe, en
/// positivo. Hasta que las tarjetas puedan crearse desde la interfaz es cero.
Map<String, int> cardDebtByCurrency(Iterable<AccountBalance> balances) {
  final debts = <String, int>{};
  for (final b in balances) {
    if (b.account.isArchived || b.account.type != AccountType.creditCard) continue;
    debts[b.account.currency] = (debts[b.account.currency] ?? 0) - b.balanceMinor;
  }
  return debts;
}
