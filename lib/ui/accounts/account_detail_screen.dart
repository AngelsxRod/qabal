import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/format/money.dart';
import '../common/async_body.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';
import '../transactions/transaction_list.dart';
import 'account_labels.dart';

/// Saldo de una cuenta y sus movimientos agrupados por día.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  Future<void> _setArchived(BuildContext context, WidgetRef ref, bool archived) async {
    if (archived) {
      final ok = await confirmAction(
        context,
        title: 'Archivar cuenta',
        message:
            'La cuenta dejará de ofrecerse para nuevos movimientos, pero conserva su '
            'historial y puedes restaurarla cuando quieras.',
        confirmLabel: 'Archivar',
      );
      if (!ok || !context.mounted) return;
    }
    try {
      await ref.read(accountRepositoryProvider).update(accountId, isArchived: archived);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

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
                  onTap: () => _setArchived(context, ref, !account.isArchived),
                  child: Text(account.isArchived ? 'Restaurar cuenta' : 'Archivar cuenta'),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: account == null || account.isArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.transactionNewFor(accountId: accountId)),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo movimiento'),
            ),
      body: AsyncBody(
        value: balance,
        data: (item) => TransactionList(
          filter: TransactionFilter(accountId: accountId),
          perspectiveAccountId: accountId,
          emptyMessage: 'Esta cuenta aún no tiene movimientos.',
          header: _BalanceHeader(item),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader(this.item);

  final AccountBalance item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = item.account;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${accountTypeLabel(a.type)} · ${a.currency}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(item.balanceMinor, a.currency),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: item.balanceMinor < 0
                      ? context.moneyColors.expense
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (a.isArchived) ...[
                const SizedBox(height: 8),
                Chip(
                  label: const Text('Archivada'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.archive_outlined, size: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
