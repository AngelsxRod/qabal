import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../design/status_badge.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'card_labels.dart';

/// Fila de un estado de cuenta: corte, estado, saldo oficial, vencimiento y,
/// si el estimado de la app no coincide con el oficial, un aviso.
class StatementRow extends StatelessWidget {
  const StatementRow({super.key, required this.view, required this.currency, this.onTap});

  final StatementView view;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final s = view.statement;
    final diff = view.differenceMinor;
    final title = 'Corte ${formatDate(s.closingDate)}';
    final subtitle =
        'Saldo ${formatMoney(s.statementBalanceMinor, currency)} · '
        'vence ${formatDayMonth(s.dueDate)}';
    return Semantics(
      button: onTap != null,
      label: '$title, ${statementStatusLabel(view.status)}, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: t.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          StatusBadge(
                            label: statementStatusLabel(view.status),
                            tone: statementStatusTone(context, view.status),
                          ),
                        ],
                      ),
                      Text(subtitle, style: t.caption),
                      if (diff != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: c.expense),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'La app estimaba ${formatMoney(view.estimatedBalanceMinor, currency)}',
                                  style: t.caption.copyWith(color: c.expense),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
