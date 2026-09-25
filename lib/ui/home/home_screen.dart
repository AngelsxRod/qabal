import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../accounts/account_labels.dart';
import '../accounts/account_row.dart';
import '../accounts/account_totals.dart';
import '../accounts/no_accounts_invite.dart';
import '../common/async_body.dart';
import '../design/app_card.dart';
import '../design/month_selector.dart';
import '../design/quick_action.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'balance_summary_card.dart';
import 'month_summary_section.dart';
import 'reserved_section.dart';
import 'upcoming_payments_section.dart';

/// Inicio: saldo total, deuda de tarjetas y neto por moneda, accesos rápidos,
/// resumen del mes elegido y cuentas con su saldo.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Primer día del mes elegido; `null` sigue al mes en curso (y cambia solo
  /// cuando cambia el día).
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(dayProvider);
    final current = DateTime(today.year, today.month);
    final month = _picked ?? current;
    void open(TransactionType type) => context.push(Routes.transactionNewFor(type: type));
    void moveMonth(int delta) {
      final next = DateTime(month.year, month.month + delta);
      setState(() => _picked = next == current ? null : next);
    }

    return Scaffold(
      appBar: tabAppBar(context, 'Inicio'),
      body: AsyncBody(
        value: ref.watch(accountBalancesProvider(true)),
        data: (all) {
          if (all.isEmpty) return const NoAccountsInvite();
          final cards = [
            for (final b in all)
              if (!b.account.isArchived && b.account.type == AccountType.creditCard) b.account,
          ];
          final active = all
              .where((b) => !b.account.isArchived && isPlainAccount(b.account))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              BalanceSummaryCard(totals: totalsByCurrency(all), cardDebts: cardDebtByCurrency(all)),
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
              const SizedBox(height: Space.xl),
              MonthSelector(
                month: month,
                onPrevious: () => moveMonth(-1),
                onNext: month == current ? null : () => moveMonth(1),
              ),
              const SizedBox(height: Space.sm),
              MonthSummarySection(month: month),
              ReservedSection(
                title: 'Próximos pagos',
                visible: cards.isNotEmpty,
                child: UpcomingPayments(cards: cards),
              ),
              const ReservedSection(title: 'Te deben / Debes'), // F4
              const SizedBox(height: Space.xl),
              Text('MIS CUENTAS', style: context.text.label),
              const SizedBox(height: Space.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < active.length; i++) ...[
                      if (i > 0) Divider(indent: 72, color: context.colors.border),
                      AccountRow(active[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
