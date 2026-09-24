import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/format/money.dart';
import '../common/async_body.dart';
import 'account_labels.dart';
import 'no_accounts_invite.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(accountBalancesProvider(true));
    final hasAny = balances.value?.any((b) => isPlainAccount(b.account)) ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              CheckedPopupMenuItem<void>(
                checked: _showArchived,
                onTap: () => setState(() => _showArchived = !_showArchived),
                child: const Text('Mostrar archivadas'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: hasAny
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.accountNew),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cuenta'),
            )
          : null,
      body: AsyncBody(
        value: balances,
        data: (all) {
          final plain = all.where((b) => isPlainAccount(b.account)).toList();
          if (plain.isEmpty) return const NoAccountsInvite();
          final visible =
              plain.where((b) => _showArchived || !b.account.isArchived).toList();
          if (visible.isEmpty) {
            return const Center(child: Text('Todas tus cuentas están archivadas.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _AccountTile(visible[i]),
          );
        },
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile(this.item);

  final AccountBalance item;

  @override
  Widget build(BuildContext context) {
    final a = item.account;
    final theme = Theme.of(context);
    final negative = item.balanceMinor < 0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(accountTypeIcon(a.type), color: theme.colorScheme.onSecondaryContainer),
      ),
      title: Text(a.name),
      subtitle: Text(
        a.isArchived ? '${accountTypeLabel(a.type)} · Archivada' : accountTypeLabel(a.type),
      ),
      trailing: Text(
        formatMoney(item.balanceMinor, a.currency),
        style: theme.textTheme.titleMedium?.copyWith(
          color: negative ? context.moneyColors.expense : null,
        ),
      ),
      onTap: () => context.push(Routes.accountDetail(a.id)),
    );
  }
}
