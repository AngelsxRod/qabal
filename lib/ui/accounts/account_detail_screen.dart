import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../common/async_body.dart';
import '../design/amount_text.dart';
import '../design/quick_action.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../transactions/transaction_list.dart';
import 'account_archive.dart';
import 'account_labels.dart';

/// Saldo de una cuenta y sus movimientos agrupados por día.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(accountId));
    final account = balance.value?.account;
    return Scaffold(
      appBar: AppBar(
        title: Text(account?.name ?? 'Cuenta'),
        actions: [
          if (account != null) ...[
            IconButton(
              tooltip: 'Editar cuenta',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.accountEdit(accountId)),
            ),
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => setAccountArchived(context, ref, accountId, !account.isArchived),
                  child: Text(account.isArchived ? 'Restaurar cuenta' : 'Archivar cuenta'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: AsyncBody(
        value: balance,
        data: (item) => TransactionList(
          filter: TransactionFilter(accountId: accountId),
          perspectiveAccountId: accountId,
          emptyMessage: 'Esta cuenta aún no tiene movimientos.',
          emptyHint: 'Cuando registres uno, aparecerá aquí.',
          header: _Header(item),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.item);

  final AccountBalance item;

  @override
  Widget build(BuildContext context) {
    final a = item.account;
    final c = context.colors;
    final t = context.text;
    void open(TransactionType type) =>
        context.push(Routes.transactionNewFor(accountId: a.id, type: type));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${accountTypeLabel(a.type)} · ${a.currency}', style: t.caption),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
              item.balanceMinor,
              a.currency,
              size: AmountSize.xl,
              color: item.balanceMinor < 0 ? c.expense : null,
            ),
          ),
          if (a.isArchived) ...[
            const SizedBox(height: Space.sm),
            Chip(
              label: const Text('Archivada'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.archive_outlined, size: 16),
            ),
          ] else ...[
            const SizedBox(height: Space.lg),
            QuickActions(
              children: [
                QuickAction(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Gasto',
                  onTap: () => open(TransactionType.expense),
                ),
                QuickAction(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Ingreso',
                  onTap: () => open(TransactionType.income),
                ),
                QuickAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transferir',
                  onTap: () => open(TransactionType.transfer),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
