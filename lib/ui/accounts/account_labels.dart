import 'package:flutter/material.dart';

import '../../app/providers.dart';

String accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Efectivo',
  AccountType.bank => 'Cuenta bancaria',
  AccountType.savings => 'Ahorros',
  AccountType.other => 'Otra',
  AccountType.creditCard => 'Tarjeta de crédito',
};

IconData accountTypeIcon(AccountType type) => switch (type) {
  AccountType.cash => Icons.payments_outlined,
  AccountType.bank => Icons.account_balance_outlined,
  AccountType.savings => Icons.savings_outlined,
  AccountType.other => Icons.wallet_outlined,
  AccountType.creditCard => Icons.credit_card,
};

/// Cuentas que se manejan como saldo a favor. Las tarjetas de crédito llevan
/// su deuda aparte: no entran en el saldo total, sino en la deuda de tarjetas.
bool isPlainAccount(Account a) => a.type != AccountType.creditCard;

/// Monedas que se ofrecen al crear una cuenta.
const accountCurrencies = ['GTQ', 'USD', 'EUR', 'MXN'];
