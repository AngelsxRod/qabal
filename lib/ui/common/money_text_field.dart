import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/money.dart';

/// Campo de texto para montos: teclado numérico con decimales.
///
/// Solo deja escribir dígitos, punto y coma (el separador que produce el
/// teclado depende del dispositivo); la interpretación y la validación las
/// hace `parseMinor`. El error se pasa desde fuera para poder mostrar
/// tanto la validación del formulario como errores de dominio.
class MoneyTextField extends StatelessWidget {
  const MoneyTextField({
    super.key,
    required this.controller,
    required this.label,
    this.currency,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? currency;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: currency == null ? null : '${currencySymbol(currency!)} ',
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 2,
      ),
    );
  }
}

/// Mensaje para un monto que `parseMinor` no entendió.
const invalidAmountMessage = 'Monto inválido. Escribe por ejemplo 1234.50';
