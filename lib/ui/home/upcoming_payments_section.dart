import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/credit_card/statement_status.dart';
import '../cards/card_labels.dart';
import '../design/amount_text.dart';
import '../design/app_card.dart';
import '../design/status_badge.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// "Próximos pagos": estados de cuenta sin pagar por fecha de pago, con los
/// días que faltan (o "Vencido"), y un mini resumen por tarjeta con el estimado
/// al corte y los días que faltan para él.
class UpcomingPayments extends ConsumerWidget {
  const UpcomingPayments({super.key, required this.cards});

  /// Tarjetas activas.
  final List<Account> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pending = ref.watch(pendingStatementsProvider).value ?? const <PendingStatement>[];
    final rows = <Widget>[
      for (final p in pending) _PendingRow(p),
      for (final card in cards) _CardSummaryRow(card),
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(color: c.border), rows[i]],
        ],
      ),
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow(this.item);

  final PendingStatement item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final today = ref.watch(dayProvider);
    final s = item.statement;
    final overdue = item.status == StatementStatus.overdue;
    final days = daysBetween(today, s.dueDate);
    final when = overdue
        ? 'Venció el ${formatDayMonth(s.dueDate)}'
        : item.status == StatementStatus.minimumCovered && days < 0
        ? 'Pasó la fecha, mínimo cubierto'
        : 'Pago hasta ${formatDayMonth(s.dueDate)} · ${daysLabel(days)}';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${item.card.name}, corte ${formatDate(s.closingDate)}, '
          'pendiente ${formatMoney(item.pendingMinor, item.card.currency)}, $when',
      child: InkWell(
        onTap: () => context.push(Routes.statementDetail(item.card.id, s.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.card.name} · corte ${formatDayMonth(s.closingDate)}',
                        style: t.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(when, style: t.caption.copyWith(color: overdue ? c.expense : null)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(item.pendingMinor, item.card.currency),
                    if (overdue)
                      StatusBadge(label: statementStatusLabel(item.status), tone: c.expense),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardSummaryRow extends ConsumerWidget {
  const _CardSummaryRow(this.card);

  final Account card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final today = ref.watch(dayProvider);
    final overview = ref.watch(cardOverviewProvider(card.id)).value;
    final summary = overview?.summary;
    final caption = summary == null
        ? ''
        : 'Estimado al corte ${formatMoney(summary.estimatedClosingMinor, card.currency)} · '
              '${daysLabel(daysBetween(today, summary.cycle.closingDate)).toLowerCase()}';
    return InkWell(
      onTap: () => context.push(Routes.accountDetail(card.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Row(
            children: [
              Icon(Icons.credit_card_rounded, color: c.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: t.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (caption.isNotEmpty) Text(caption, style: t.caption),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
