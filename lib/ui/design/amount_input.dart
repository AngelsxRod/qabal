import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import 'tokens.dart';
import 'typography.dart';

/// Campo de monto protagonista: cifras grandes centradas, con el símbolo de
/// la moneda y separador de miles en vivo (`12,500.00`). Se lee con
/// `parseInputMinor`.
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
    this.large = true,
  });

  final TextEditingController controller;
  final String? currency;
  final String label;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Color de las cifras (p. ej. el del tipo de movimiento).
  final Color? color;

  /// Cifras de 40 sp (el monto principal) o de 28 sp (montos secundarios).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final style = (large ? t.amountXL : t.amountL).copyWith(color: color ?? c.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          textField: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (currency != null)
                ExcludeSemantics(
                  child: Text(
                    currencySymbol(currency!),
                    style: style.copyWith(color: c.textTertiary),
                  ),
                ),
              if (currency != null) const SizedBox(width: Space.sm),
              // El ancho sigue al texto para que el símbolo quede pegado a las
              // cifras mientras se escribe.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 96, maxWidth: 240),
                child: IntrinsicWidth(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    textAlign: TextAlign.center,
                    style: style,
                    cursorColor: c.accent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [MoneyInputFormatter()],
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: style.copyWith(color: c.textTertiary.withValues(alpha: 0.5)),
                      contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
                    ),
                  ),
                ),
              ),
            ],
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
