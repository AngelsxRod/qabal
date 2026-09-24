import 'package:flutter/services.dart';

import 'money.dart';

/// Formatea un monto mientras se escribe: agrupa los miles con coma y usa el
/// punto como decimal (`12,500.00`).
///
/// - El teclado puede producir `,` o `.`: el separador que se teclea (uno solo,
///   mientras no haya decimal) es el decimal, y se muestra siempre como `.`.
///   Las comas que ya están en pantalla son de miles.
/// - Al pegar texto: `1234,50` (coma con 1 o 2 dígitos) es decimal, `12,500`
///   son miles, `1,234.50` mezcla bien; el estilo europeo (`1.234,50`) se
///   rechaza (no se aplica el cambio).
/// - Máximo 12 dígitos enteros y 2 decimales.
/// - El cursor se conserva contando los dígitos (y el punto) que había a su
///   izquierda.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  static const _maxWhole = 12;

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final o = oldValue.text;
    final n = newValue.text;
    final cursor = newValue.selection.isValid
        ? newValue.selection.baseOffset.clamp(0, n.length)
        : n.length;

    String whole;
    String? decimals; // null = sin separador decimal
    int sig; // caracteres significativos (dígitos y punto) a la izquierda del cursor

    final typedSeparator = n.length == o.length + 1 &&
        cursor > 0 &&
        (n[cursor - 1] == ',' || n[cursor - 1] == '.') &&
        '${n.substring(0, cursor - 1)}${n.substring(cursor)}' == o;

    if (typedSeparator) {
      if (o.contains('.')) return oldValue; // ya hay decimal
      final left = _digits(n.substring(0, cursor - 1));
      whole = left;
      decimals = _digits(n.substring(cursor));
      sig = left.length + 1;
    } else if (n.contains('.')) {
      final lastDot = n.lastIndexOf('.');
      if (n.lastIndexOf(',') > lastDot) return oldValue; // 1.234,50
      final i = n.indexOf('.');
      whole = _digits(n.substring(0, i));
      decimals = _digits(n.substring(i + 1));
      sig = _digits(n.substring(0, cursor.clamp(0, n.length))).length +
          (cursor > i ? 1 : 0);
    } else if (n.contains(',')) {
      final ci = n.lastIndexOf(',');
      final after = n.substring(ci + 1);
      final pasted = n.length - o.length > 1 || o.isEmpty;
      final decimalComma = pasted &&
          RegExp(r'^\d{1,2}$').hasMatch(after) &&
          n.indexOf(',') == ci;
      if (decimalComma) {
        whole = _digits(n.substring(0, ci));
        decimals = after;
        sig = whole.length + 1 + decimals.length;
      } else {
        whole = _digits(n);
        sig = _digits(n.substring(0, cursor)).length;
      }
    } else {
      whole = _digits(n);
      sig = cursor;
    }

    if (whole.length > _maxWhole) return oldValue;
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (decimals != null) {
      if (decimals.length > 2) decimals = decimals.substring(0, 2);
      if (whole.isEmpty) {
        whole = '0';
        sig += 1; // el cero que se antepone queda a la izquierda del cursor
      }
    }

    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    if (decimals != null) out.write('.$decimals');
    final text = out.toString();

    var pos = 0;
    var seen = 0;
    while (pos < text.length && seen < sig) {
      if (text[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: pos));
  }
}

/// Lee el texto de un campo que usa [MoneyInputFormatter] (siempre en forma
/// canónica: comas de miles y punto decimal). Devuelve `null` si está vacío
/// o no es un monto. Un punto final (`12.`) cuenta como entero.
int? parseInputMinor(String text) {
  var s = text.trim().replaceAll(',', '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  if (s.isEmpty) return null;
  return parseMinor(s);
}

/// `123450` → `1,234.50` (agrupado, sin símbolo): valor inicial de un campo
/// de monto al editar.
String formatGrouped(int minor) => formatMoney(minor, '').trim();
