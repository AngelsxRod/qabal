import 'package:flutter/material.dart';

import '../design/amount_text.dart';
import '../design/app_card.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Saldo total, deuda de tarjetas y neto, uno por moneda (nunca se suman
/// monedas distintas).
class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({super.key, required this.totals, required this.cardDebts});

  /// Saldo de cuentas activas que no son tarjeta, por moneda.
  final Map<String, int> totals;

  /// Deuda de tarjetas (en positivo), por moneda.
  final Map<String, int> cardDebts;

  @override
  Widget build(BuildContext context) {
    final currencies = {...totals.keys, ...cardDebts.keys}.toList()..sort();
    if (currencies.isEmpty) currencies.add('GTQ');
    final c = context.colors;
    final t = context.text;

    Widget line(String label, int minor, String currency, {Color? color}) => Row(
      children: [
        Expanded(child: Text(label, style: t.caption)),
        AmountText(minor, currency, size: AmountSize.s, color: color),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo total', style: t.caption),
          for (var i = 0; i < currencies.length; i++) ...[
            if (i > 0) ...[const SizedBox(height: Space.lg), Divider(height: 1, color: c.border)],
            const SizedBox(height: Space.xs),
            Builder(
              builder: (_) {
                final cur = currencies[i];
                final total = totals[cur] ?? 0;
                final debt = cardDebts[cur] ?? 0;
                final net = total - debt;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AmountText(
                        total,
                        cur,
                        size: i == 0 ? AmountSize.xl : AmountSize.l,
                        color: total < 0 ? c.expense : null,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    line('Deuda de tarjetas', debt, cur, color: debt > 0 ? c.expense : null),
                    const SizedBox(height: Space.xs),
                    line('Neto', net, cur, color: net < 0 ? c.expense : null),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
