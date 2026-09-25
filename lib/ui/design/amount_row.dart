import 'package:flutter/material.dart';

import 'amount_text.dart';
import 'tokens.dart';
import 'typography.dart';

/// Línea de un desglose: etiqueta (con nota opcional debajo) y monto a la
/// derecha.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.minor,
    required this.currency,
    this.note,
    this.color,
    this.showPlus = false,
    this.strong = false,
  });

  final String label;
  final int minor;
  final String currency;
  final String? note;
  final Color? color;
  final bool showPlus;

  /// Destaca la línea (totales).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: strong ? t.bodyStrong : t.body),
                if (note != null) Text(note!, style: t.caption),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          AmountText(
            minor,
            currency,
            size: strong ? AmountSize.m : AmountSize.s,
            color: color,
            showPlus: showPlus,
          ),
        ],
      ),
    );
  }
}
