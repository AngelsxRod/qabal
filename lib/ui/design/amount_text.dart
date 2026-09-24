import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import 'tokens.dart';
import 'typography.dart';

enum AmountSize { xl, l, m, s }

/// Monto formateado con cifras tabulares. En los tamaños grandes los
/// centavos se muestran más pequeños para que la parte entera domine.
class AmountText extends StatelessWidget {
  const AmountText(
    this.minor,
    this.currency, {
    super.key,
    this.size = AmountSize.m,
    this.color,
    this.showPlus = false,
    this.textAlign,
  });

  final int minor;
  final String currency;
  final AmountSize size;

  /// Por defecto, el color de texto principal.
  final Color? color;

  /// Antepone `+` a los positivos (los negativos siempre llevan `-`).
  final bool showPlus;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final base = switch (size) {
      AmountSize.xl => t.amountXL,
      AmountSize.l => t.amountL,
      AmountSize.m => t.amountM,
      AmountSize.s => t.amountS,
    };
    final style = color == null ? base : base.copyWith(color: color);
    final full = showPlus ? formatSignedMoney(minor, currency) : formatMoney(minor, currency);
    final dot = full.lastIndexOf('.');
    final big = size == AmountSize.xl || size == AmountSize.l;

    return Semantics(
      label: full,
      excludeSemantics: true,
      child: big && dot > 0
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: full.substring(0, dot)),
                  TextSpan(
                    text: full.substring(dot),
                    style: style.copyWith(
                      fontSize: (style.fontSize ?? 28) * 0.6,
                      color: (color ?? context.colors.textPrimary).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              style: style,
              textAlign: textAlign,
              maxLines: 1,
            )
          : Text(
              full,
              style: style,
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
