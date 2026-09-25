import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../common/async_body.dart';
import '../design/amount_text.dart';
import '../design/app_card.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Ingresos y gastos netos del mes que empieza en [month], por moneda. Las
/// devoluciones se muestran aparte cuando las hay (ya están restadas de los
/// gastos).
class MonthSummarySection extends ConsumerWidget {
  const MonthSummarySection({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    return AsyncBody(
      value: ref.watch(monthTotalsProvider(month)),
      data: (all) {
        final totals =
            all
                .where((x) => x.incomeMinor != 0 || x.expenseMinor != 0 || x.refundsMinor != 0)
                .toList()
              ..sort((a, b) => a.currency.compareTo(b.currency));
        if (totals.isEmpty) {
          return AppCard(
            child: Center(child: Text('Sin ingresos ni gastos este mes.', style: t.caption)),
          );
        }
        return AppCard(
          child: Column(
            children: [
              for (var i = 0; i < totals.length; i++) ...[
                if (i > 0) Divider(height: Space.xl, color: context.colors.border),
                _CurrencyTotals(totals[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyTotals extends StatelessWidget {
  const _CurrencyTotals(this.totals);

  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final cur = totals.currency;
    Widget line(String label, Widget amount, {String? note}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodyStrong),
              if (note != null) Text(note, style: t.caption),
            ],
          ),
        ),
        amount,
      ],
    );

    return Column(
      children: [
        line(
          'Ingresos',
          AmountText(
            totals.incomeMinor,
            cur,
            showPlus: true,
            color: totals.incomeMinor > 0 ? c.income : null,
          ),
        ),
        const SizedBox(height: Space.md),
        line(
          'Gastos',
          AmountText(-totals.expenseMinor, cur, color: totals.expenseMinor > 0 ? c.expense : null),
        ),
        if (totals.refundsMinor > 0) ...[
          const SizedBox(height: Space.md),
          line(
            'Devoluciones',
            AmountText(totals.refundsMinor, cur, showPlus: true, color: c.income),
            note: 'Ya restadas de los gastos',
          ),
        ],
      ],
    );
  }
}
