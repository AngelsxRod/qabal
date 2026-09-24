import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../common/async_body.dart';
import '../design/amount_text.dart';
import '../design/app_button.dart';
import '../design/app_card.dart';
import '../design/category_avatar.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'account_labels.dart';
import 'account_totals.dart';
import 'no_accounts_invite.dart';
import 'total_balance_card.dart';

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
    return Scaffold(
      appBar: tabAppBar(
        context,
        'Cuentas',
        actions: [
          IconButton(
            tooltip: 'Nueva cuenta',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(Routes.accountNew),
          ),
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
      body: AsyncBody(
        value: balances,
        data: (all) {
          final plain = all.where((b) => isPlainAccount(b.account)).toList();
          if (plain.isEmpty) return const NoAccountsInvite();
          final visible = plain.where((b) => _showArchived || !b.account.isArchived).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              TotalBalanceCard(totals: totalsByCurrency(plain)),
              const SizedBox(height: Space.xl),
              Text('MIS CUENTAS', style: context.text.label),
              const SizedBox(height: Space.sm),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.lg),
                  child: Text('Todas tus cuentas están archivadas.', style: context.text.caption),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) Divider(indent: 72, color: context.colors.border),
                        _AccountRow(visible[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: Space.xl),
              AppButton(
                label: 'Nueva cuenta',
                kind: AppButtonKind.secondary,
                icon: Icons.add_rounded,
                onPressed: () => context.push(Routes.accountNew),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow(this.item);

  final AccountBalance item;

  @override
  Widget build(BuildContext context) {
    final a = item.account;
    final c = context.colors;
    final t = context.text;
    return InkWell(
      onTap: () => context.push(Routes.accountDetail(a.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Row(
            children: [
              CategoryAvatar(icon: accountTypeIcon(a.type), color: c.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      a.isArchived
                          ? '${accountTypeLabel(a.type)} · Archivada'
                          : accountTypeLabel(a.type),
                      style: t.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              AmountText(
                item.balanceMinor,
                a.currency,
                color: item.balanceMinor < 0 ? c.expense : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
