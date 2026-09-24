/// Formatos y lectura de montos en centavos, sin `intl`.
///
/// Todas las monedas se tratan con 2 decimales.
library;

const _symbols = {
  'GTQ': 'Q',
  'USD': r'US$',
  'EUR': '€',
  'MXN': r'MX$',
};

/// Símbolo de la moneda; para las desconocidas, el propio código.
String currencySymbol(String currency) => _symbols[currency] ?? currency;

String _groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String _split(int minor, {required bool grouped}) {
  final abs = minor.abs();
  final whole = (abs ~/ 100).toString();
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${grouped ? _groupThousands(whole) : whole}.$cents';
}

/// `123450` con GTQ → `Q1,234.50`; los negativos llevan el signo delante
/// del símbolo (`-Q1,234.50`). Las monedas sin símbolo conocido se separan
/// con un espacio (`CHF 1,234.50`).
String formatMoney(int minor, String currency) {
  final symbol = currencySymbol(currency);
  final sep = symbol == currency ? ' ' : '';
  return '${minor < 0 ? '-' : ''}$symbol$sep${_split(minor, grouped: true)}';
}

/// Igual que [formatMoney] pero forzando el signo (`+Q10.00`); el cero no
/// lleva signo.
String formatSignedMoney(int minor, String currency) =>
    minor > 0 ? '+${formatMoney(minor, currency)}' : formatMoney(minor, currency);

/// Número sin símbolo ni miles, con punto decimal: `123450` → `1234.50`.
/// Es lo que se muestra al editar un monto en un campo de texto.
String formatPlain(int minor) => '${minor < 0 ? '-' : ''}${_split(minor, grouped: false)}';

/// Máximo de dígitos enteros aceptados (evita desbordar un `int` de 64 bits
/// al pasar a centavos y montos absurdos).
const _maxWholeDigits = 12;

final _thousandsWithDot = RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$');
final _plainWithDot = RegExp(r'^\d*(\.\d{1,2})?$');
final _plainWithComma = RegExp(r'^\d*(,\d{1,2})?$');
final _thousandsOnly = RegExp(r'^\d{1,3}(,\d{3})+$');

/// Lee un monto escrito por el usuario y lo devuelve en centavos, o `null`
/// si es inválido o ambiguo. Nunca acepta signo (los montos son positivos).
///
/// - `1234`, `1234.5`, `1234.50` → punto decimal.
/// - `1234,50` → la coma es decimal cuando es el único separador y va
///   seguida de 1 o 2 dígitos.
/// - `1,234.50` y `1,234,567` → la coma separa miles (grupos de 3).
/// - Se rechaza lo ambiguo o mal formado: `1,234` (¿1.234 o 1234?), `1.234`
///   (3 decimales), `1.234,50`, `1.234.567`, `1,2,3`, `12.`, letras, vacío.
int? parseMinor(String input) {
  final s = input.trim().replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty || s == '.' || s == ',') return null;

  final hasDot = s.contains('.');
  final hasComma = s.contains(',');
  String normalized;
  if (hasDot && hasComma) {
    if (!_thousandsWithDot.hasMatch(s)) return null;
    normalized = s.replaceAll(',', '');
  } else if (hasDot) {
    if (!_plainWithDot.hasMatch(s)) return null;
    normalized = s;
  } else if (hasComma) {
    if (_thousandsOnly.hasMatch(s)) {
      // `1,234,567` es inequívoco, pero `1,234` no: una sola coma seguida de
      // exactamente 3 dígitos podría ser decimal mal escrito.
      if (s.split(',').length == 2) return null;
      normalized = s.replaceAll(',', '');
    } else if (_plainWithComma.hasMatch(s)) {
      normalized = s.replaceAll(',', '.');
    } else {
      return null;
    }
  } else {
    if (!RegExp(r'^\d+$').hasMatch(s)) return null;
    normalized = s;
  }

  final parts = normalized.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  if (whole.replaceFirst(RegExp(r'^0+(?=\d)'), '').length > _maxWholeDigits) return null;
  final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return int.parse(whole) * 100 + int.parse(fraction);
}
