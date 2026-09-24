import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/money.dart';
import 'tokens.dart';
import 'typography.dart';

/// Campo de monto protagonista: cifras grandes centradas, con el símbolo de
/// la moneda. Solo deja escribir dígitos, punto y coma; la interpretación es
/// de `parseMinor`.
class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.controller,
    required this.currency,
    this.label = 'Monto',
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    this.color,
  });

  final TextEditingController controller;
  final String? currency;
  final String label;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Color de las cifras (p. ej. el del tipo de movimiento).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final style = t.amountXL.copyWith(color: color ?? c.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: style,
            cursorColor: c.accent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: style.copyWith(color: c.textTertiary.withValues(alpha: 0.5)),
              prefixText: currency == null ? null : '${currencySymbol(currency!)} ',
              prefixStyle: style.copyWith(color: c.textTertiary),
              contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              errorText!,
              style: t.caption.copyWith(color: c.danger),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
