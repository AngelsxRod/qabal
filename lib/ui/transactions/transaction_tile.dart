import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../design/amount_text.dart';
import '../design/category_style.dart';
import '../design/tokens.dart';
import '../design/transaction_row.dart';
import 'transaction_labels.dart';

/// Efecto de un movimiento sobre el saldo, en la moneda que corresponde.
/// Devuelve `null` si no afecta la vista (transferencia en la lista general).
({int minor, String currency})? transactionEffect(
  Transaction tx,
  Map<String, Account> accounts,
  String? perspectiveAccountId,
) {
  final source = accounts[tx.accountId];
  final dest = tx.transferAccountId == null ? null : accounts[tx.transferAccountId];
  if (tx.type == TransactionType.transfer) {
    if (perspectiveAccountId == null) return null;
    if (tx.transferAccountId == perspectiveAccountId) {
      return (minor: tx.transferAmountMinor ?? tx.amountMinor, currency: dest?.currency ?? '');
    }
    return (minor: -tx.amountMinor, currency: source?.currency ?? '');
  }
  final signed = tx.type == TransactionType.income ? tx.amountMinor : -tx.amountMinor;
  return (minor: signed, currency: source?.currency ?? '');
}

/// Fila de un movimiento.
///
/// Sin [perspectiveAccountId] (lista general) los gastos restan, los ingresos
/// suman y las transferencias se muestran neutras como `Origen → Destino`.
/// Con una cuenta de perspectiva (detalle de cuenta) las transferencias se
/// ven desde esa cuenta: restan si salen de ella y suman si entran.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.categories,
    this.perspectiveAccountId,
    this.onTap,
  });

  final Transaction transaction;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final String? perspectiveAccountId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final source = accounts[tx.accountId];
    final dest = tx.transferAccountId == null ? null : accounts[tx.transferAccountId];
    final isTransfer = tx.type == TransactionType.transfer;
    final incoming =
        isTransfer && perspectiveAccountId != null && tx.transferAccountId == perspectiveAccountId;

    late final String title;
    late final IconData icon;
    late final Color iconColor;
    if (isTransfer) {
      title = 'Transferencia';
      icon = transferIcon;
      iconColor = c.transfer;
    } else if (tx.debtId != null) {
      title = 'Movimiento de deuda';
      icon = Icons.handshake_rounded;
      iconColor = c.textSecondary;
    } else {
      final category = categories[tx.categoryId];
      title = category == null ? 'Sin categoría' : categoryLabel(category, categories);
      final style = categoryStyleFor(category, brightness);
      icon = style.icon;
      iconColor = style.color;
    }

    final details = <String>[
      if (isTransfer && perspectiveAccountId == null)
        '${source?.name ?? '?'} → ${dest?.name ?? '?'}'
      else if (isTransfer)
        incoming ? 'De ${source?.name ?? '?'}' : 'A ${dest?.name ?? '?'}'
      else if (perspectiveAccountId == null)
        source?.name ?? '?',
      if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
    ];

    final Widget amount;
    if (isTransfer && perspectiveAccountId == null) {
      amount = AmountText(tx.amountMinor, source?.currency ?? '', color: c.transfer);
    } else {
      final effect = transactionEffect(tx, accounts, perspectiveAccountId)!;
      amount = AmountText(
        effect.minor,
        effect.currency,
        showPlus: effect.minor > 0,
        color: effect.minor > 0 ? c.income : null,
      );
    }

    return TransactionRow(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: details.isEmpty ? null : details.join(' · '),
      amount: amount,
      onTap: onTap,
    );
  }
}
