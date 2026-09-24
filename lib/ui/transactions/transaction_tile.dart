import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format/money.dart';
import 'transaction_labels.dart';

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
    final theme = Theme.of(context);
    final colors = context.moneyColors;
    final source = accounts[tx.accountId];
    final dest = tx.transferAccountId == null ? null : accounts[tx.transferAccountId];
    final isTransfer = tx.type == TransactionType.transfer;
    final incoming =
        isTransfer && perspectiveAccountId != null && tx.transferAccountId == perspectiveAccountId;

    String title;
    if (isTransfer) {
      title = 'Transferencia';
    } else if (tx.debtId != null) {
      title = 'Movimiento de deuda';
    } else {
      final category = categories[tx.categoryId];
      title = category == null ? 'Sin categoría' : categoryLabel(category, categories);
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

    // Monto y color.
    final String amountText;
    final Color amountColor;
    if (isTransfer && perspectiveAccountId == null) {
      amountText = formatMoney(tx.amountMinor, source?.currency ?? '');
      amountColor = colors.transfer;
    } else if (incoming) {
      amountText = formatSignedMoney(
        tx.transferAmountMinor ?? tx.amountMinor,
        dest?.currency ?? '',
      );
      amountColor = colors.income;
    } else if (tx.type == TransactionType.income) {
      amountText = formatSignedMoney(tx.amountMinor, source?.currency ?? '');
      amountColor = colors.income;
    } else {
      amountText = formatSignedMoney(-tx.amountMinor, source?.currency ?? '');
      amountColor = colors.expense;
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: transactionTypeColor(context, tx.type).withValues(alpha: 0.15),
        child: Icon(
          incoming ? Icons.arrow_downward : transactionTypeIcon(tx.type),
          color: transactionTypeColor(context, tx.type),
          size: 20,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty
          ? null
          : Text(details.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(amountText, style: theme.textTheme.titleSmall?.copyWith(color: amountColor)),
    );
  }
}
