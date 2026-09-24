import 'package:flutter/material.dart';

import '../design/amount_text.dart';
import '../design/app_card.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Saldo total, uno por moneda (nunca se suman monedas distintas).
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({super.key, required this.totals, this.label = 'Saldo total'});

  final Map<String, int> totals;
  final String label;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.caption),
          const SizedBox(height: Space.xs),
          if (entries.isEmpty) const AmountText(0, 'GTQ', size: AmountSize.xl),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Space.sm),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AmountText(
                  entries[i].value,
                  entries[i].key,
                  size: i == 0 ? AmountSize.xl : AmountSize.l,
                  color: entries[i].value < 0 ? c.expense : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
