import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../accounts/account_labels.dart';
import '../accounts/account_totals.dart';
import '../accounts/no_accounts_invite.dart';
import '../accounts/total_balance_card.dart';
import '../common/async_body.dart';
import '../design/quick_action.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Pantalla de inicio provisional: saldo total y acceso rápido a registrar.
/// El resumen completo llega en la fase siguiente.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(TransactionType type) => context.push(Routes.transactionNewFor(type: type));
    return Scaffold(
      appBar: tabAppBar(context, 'Inicio'),
      body: AsyncBody(
        value: ref.watch(accountBalancesProvider(true)),
        data: (all) {
          final plain = all.where((b) => isPlainAccount(b.account)).toList();
          if (plain.isEmpty) return const NoAccountsInvite();
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              TotalBalanceCard(totals: totalsByCurrency(plain)),
              const SizedBox(height: Space.xl),
              Text('REGISTRAR', style: context.text.label),
              const SizedBox(height: Space.sm),
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
          );
        },
      ),
    );
  }
}
