import 'package:finanzas/core/format/money.dart';
import 'package:finanzas/core/format/money_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula un campo de texto: cada acción edita el texto y pasa por el
/// formateador, como haría el teclado.
class _Field {
  static const _f = MoneyInputFormatter();
  TextEditingValue value = const TextEditingValue(selection: TextSelection.collapsed(offset: 0));

  String get text => value.text;
  int get cursor => value.selection.baseOffset;

  void _apply(String text, int cursor) {
    value = _f.formatEditUpdate(
      value,
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor)),
    );
  }

  /// Teclea [chars] uno a uno en la posición del cursor.
  _Field type(String chars) {
    for (final ch in chars.split('')) {
      final t = text;
      final c = cursor;
      _apply('${t.substring(0, c)}$ch${t.substring(c)}', c + 1);
    }
    return this;
  }

  _Field backspace() {
    final t = text;
    final c = cursor;
    if (c > 0) _apply('${t.substring(0, c - 1)}${t.substring(c)}', c - 1);
    return this;
  }

  _Field moveTo(int c) {
    value = value.copyWith(selection: TextSelection.collapsed(offset: c));
    return this;
  }

  /// Pega [chars] reemplazando todo el contenido.
  _Field paste(String chars) {
    value = const TextEditingValue(selection: TextSelection.collapsed(offset: 0));
    _apply(chars, chars.length);
    return this;
  }
}

void main() {
  group('agrupa los miles al teclear', () {
    test('cifras sueltas y grupos', () {
      expect(_Field().type('1').text, '1');
      expect(_Field().type('123').text, '123');
      expect(_Field().type('1234').text, '1,234');
      expect(_Field().type('12500').text, '12,500');
      expect(_Field().type('1234567').text, '1,234,567');
    });

    test('con decimales', () {
      expect(_Field().type('12500.5').text, '12,500.5');
      expect(_Field().type('12500.50').text, '12,500.50');
      expect(_Field().type('12500.507').text, '12,500.50'); // el tercero se descarta
    });

    test('la coma tecleada es el decimal y se muestra como punto', () {
      expect(_Field().type('1234,5').text, '1,234.5');
      expect(_Field().type('1234,50').text, '1,234.50');
      expect(_Field().type('12500,').text, '12,500.');
    });

    test('un segundo separador se ignora', () {
      expect(_Field().type('12.5.').text, '12.5');
      expect(_Field().type('12,5,').text, '12.5');
      expect(_Field().type('12.5,').text, '12.5');
    });

    test('empezar por separador o por cero', () {
      expect(_Field().type('.5').text, '0.5');
      expect(_Field().type(',5').text, '0.5');
      expect(_Field().type('0').text, '0');
      expect(_Field().type('05').text, '5');
      expect(_Field().type('0.05').text, '0.05');
    });

    test('rechaza más de 12 dígitos enteros', () {
      expect(_Field().type('1234567890123').text, '123,456,789,012');
    });
  });

  group('cursor', () {
    test('queda al final al escribir', () {
      final f = _Field().type('1234');
      expect(f.cursor, f.text.length);
    });

    test('al aparecer una coma de miles el cursor sigue tras el dígito tecleado', () {
      final f = _Field().type('123');
      expect(f.cursor, 3);
      f.type('4'); // 1,234
      expect(f.text, '1,234');
      expect(f.cursor, 5);
    });

    test('insertar en medio conserva la posición relativa', () {
      final f = _Field().type('1234'); // 1,234
      f.moveTo(1).type('5'); // 15,234 con el cursor tras el 5
      expect(f.text, '15,234');
      expect(f.cursor, 2);
      f.type('6'); // 156,234
      expect(f.text, '156,234');
      expect(f.cursor, 3);
    });

    test('borrar un dígito reagrupa sin mover el cursor de lugar', () {
      final f = _Field().type('12345'); // 12,345
      f.backspace(); // 1,234
      expect(f.text, '1,234');
      expect(f.cursor, 5);
      // Borrar la coma de miles no hace nada: el cursor solo pasa al otro lado.
      f.moveTo(2).backspace();
      expect(f.text, '1,234');
      expect(f.cursor, 1);
      f.backspace();
      expect(f.text, '234');
    });

    test('teclear el separador en medio del entero parte la cifra', () {
      final f = _Field().type('1234'); // 1,234
      f.moveTo(1).type(','); // 1 | 234 → 1.23 (2 decimales)
      expect(f.text, '1.23');
      expect(f.cursor, 2);
    });

    test('borrar el punto decimal une las cifras', () {
      final f = _Field().type('12.50');
      f.moveTo(3).backspace(); // borra el punto
      expect(f.text, '1,250');
    });
  });

  group('pegar', () {
    test('formatos válidos', () {
      expect(_Field().paste('1234.50').text, '1,234.50');
      expect(_Field().paste('1,234.50').text, '1,234.50');
      expect(_Field().paste('1234,50').text, '1,234.50');
      expect(_Field().paste('12,500').text, '12,500');
      expect(_Field().paste('1,234,567').text, '1,234,567');
    });

    test('el estilo europeo se rechaza', () {
      expect(_Field().paste('1.234,50').text, '');
    });

    test('las letras y símbolos se ignoran', () {
      expect(_Field().paste('Q 12a5').text, '125');
    });
  });

  group('parseInputMinor lee el formato en pantalla', () {
    const cases = {
      '1,234.50': 123450,
      '1,234': 123400, // aquí la coma es de miles: el formateador la puso
      '12,500.00': 1250000,
      '0.05': 5,
      '0.5': 50,
      '12.': 1200,
      '7': 700,
    };
    cases.forEach((text, minor) {
      test('"$text" → $minor', () => expect(parseInputMinor(text), minor));
    });

    test('vacío o inválido es nulo', () {
      expect(parseInputMinor(''), isNull);
      expect(parseInputMinor('  '), isNull);
      expect(parseInputMinor('.'), isNull);
    });

    test('lo que produce el formateador siempre se lee igual que lo tecleado', () {
      for (final typed in ['1234', '1234,50', '12500.5', '999999', '0,07', '1000000.99']) {
        final shown = _Field().type(typed).text;
        final expected = parseMinor(typed.replaceAll(',', '.'));
        expect(parseInputMinor(shown), expected, reason: '$typed → $shown');
      }
    });
  });

  test('formatGrouped', () {
    expect(formatGrouped(123450), '1,234.50');
    expect(formatGrouped(0), '0.00');
    expect(formatGrouped(1250000), '12,500.00');
  });
}
