import 'package:finanzas/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('agrupa miles y siempre lleva 2 decimales', () {
      expect(formatMoney(123450, 'GTQ'), 'Q1,234.50');
      expect(formatMoney(0, 'GTQ'), 'Q0.00');
      expect(formatMoney(5, 'GTQ'), 'Q0.05');
      expect(formatMoney(100, 'GTQ'), 'Q1.00');
      expect(formatMoney(100000000, 'GTQ'), 'Q1,000,000.00');
      expect(formatMoney(99999, 'GTQ'), 'Q999.99');
    });

    test('el signo va delante del símbolo', () {
      expect(formatMoney(-123450, 'GTQ'), '-Q1,234.50');
      expect(formatMoney(-1, 'GTQ'), '-Q0.01');
    });

    test('usa el símbolo de la moneda o el código separado', () {
      expect(formatMoney(1050, 'USD'), r'US$10.50');
      expect(formatMoney(1050, 'EUR'), '€10.50');
      expect(formatMoney(1050, 'CHF'), 'CHF 10.50');
    });

    test('formatSignedMoney marca los positivos', () {
      expect(formatSignedMoney(1000, 'GTQ'), '+Q10.00');
      expect(formatSignedMoney(-1000, 'GTQ'), '-Q10.00');
      expect(formatSignedMoney(0, 'GTQ'), 'Q0.00');
    });
  });

  group('formatPlain', () {
    test('sin miles ni símbolo, con punto decimal', () {
      expect(formatPlain(123450), '1234.50');
      expect(formatPlain(100000000), '1000000.00');
      expect(formatPlain(7), '0.07');
      expect(formatPlain(0), '0.00');
      expect(formatPlain(-250), '-2.50');
    });

    test('es reversible con parseMinor', () {
      for (final v in [0, 1, 99, 100, 123450, 99999999999]) {
        expect(parseMinor(formatPlain(v)), v);
      }
    });
  });

  group('parseMinor válidos', () {
    const cases = <String, int>{
      '0': 0,
      '5': 500,
      '1234': 123400,
      '1234.5': 123450,
      '1234.50': 123450,
      '0.05': 5,
      '.5': 50,
      '007': 700,
      // La coma es decimal cuando es el único separador y hay 1 o 2 dígitos.
      '1234,50': 123450,
      '1234,5': 123450,
      '0,05': 5,
      ',5': 50,
      // Con ambos separadores, la coma son miles y el punto el decimal.
      '1,234.50': 123450,
      '1,234.5': 123450,
      '12,345.67': 1234567,
      '1,234,567': 123456700,
      '1,234,567.89': 123456789,
      // Espacios alrededor o en medio se ignoran.
      ' 12.50 ': 1250,
      '1 234.50': 123450,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () => expect(parseMinor(input), expected));
    });
  });

  group('parseMinor rechaza lo ambiguo o inválido', () {
    const invalid = [
      '',
      '   ',
      '.',
      ',',
      'abc',
      '12a',
      '-5',
      '+5',
      '1e3',
      // Coma seguida de 3 dígitos: ¿decimal o miles?
      '1,234',
      '12,345',
      // Más de 2 decimales.
      '1.234',
      '1.2345',
      '1234,567',
      '1234,5678',
      // Separador al final o dobles.
      '12.',
      '12,',
      '1..5',
      '1,,5',
      // Estilo europeo (punto de miles, coma decimal) y otros mixtos.
      '1.234,50',
      '1.234.567',
      '1.234.567,89',
      // Agrupación de miles mal formada.
      '1,23,456.00',
      '1234,567.00',
      '12,3.45',
      '1,2,3',
      // Demasiado grande.
      '1234567890123',
    ];
    for (final input in invalid) {
      test('"$input" → null', () => expect(parseMinor(input), isNull));
    }
  });
}
