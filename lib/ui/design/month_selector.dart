import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import 'tokens.dart';
import 'typography.dart';

/// Selector de mes con flechas a los lados. Con [onNext] nulo la flecha
/// derecha queda apagada (no se navega más allá del mes en curso).
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.month, required this.onPrevious, this.onNext});

  /// Cualquier día del mes que se muestra.
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: c.textPrimary,
        ),
        Expanded(
          child: Text(formatMonth(month), textAlign: TextAlign.center, style: context.text.heading),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: c.textPrimary,
          disabledColor: c.textTertiary.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
