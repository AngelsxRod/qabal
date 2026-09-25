import 'package:flutter/material.dart';

import 'tokens.dart';

/// Barra de uso (por ejemplo, del crédito de una tarjeta). [fraction] va de 0
/// a 1; por encima del [warnAt] se pinta con el color de gasto.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.fraction, this.warnAt = 0.9, this.semanticLabel});

  final double fraction;
  final double warnAt;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = fraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel ?? 'Uso ${(value * 100).round()} %',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: c.surfaceAlt,
          color: value >= warnAt ? c.expense : c.accent,
        ),
      ),
    );
  }
}
