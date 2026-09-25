import 'package:finanzas/core/format/dates.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/ui/cards/card_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final settings = CreditCardDetail(
    accountId: 'c',
    creditLimitMinor: 1000000,
    statementDay: 21,
    dueDay: 15,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('formatDayMonth omite el año', () {
    expect(formatDayMonth(DateTime(2026, 10, 21)), '21 oct');
  });

  test('daysBetween cuenta días de calendario, también sobre cambios de mes', () {
    expect(daysBetween(DateTime(2026, 9, 30, 23), DateTime(2026, 10, 1)), 1);
    expect(daysBetween(DateTime(2026, 10, 16), DateTime(2026, 10, 15)), -1);
    expect(daysBetween(DateTime(2026, 9, 30), DateTime(2026, 9, 30)), 0);
  });

  test('daysLabel', () {
    expect(daysLabel(0), 'Hoy');
    expect(daysLabel(1), 'Falta 1 día');
    expect(daysLabel(21), 'Faltan 21 días');
    expect(daysLabel(-2), 'Hace 2 días');
  });

  group('último corte ocurrido', () {
    test('antes, en y después del día de corte', () {
      DateTime last(DateTime d) => lastClosingOnOrBefore(d, statementDay: 21, dueDay: 15);
      expect(last(DateTime(2026, 9, 30)), DateTime(2026, 9, 21));
      expect(last(DateTime(2026, 9, 21)), DateTime(2026, 9, 21));
      expect(last(DateTime(2026, 9, 20)), DateTime(2026, 8, 21));
      expect(last(DateTime(2026, 1, 10)), DateTime(2025, 12, 21));
    });

    test('previousClosing retrocede un corte', () {
      expect(
        previousClosing(DateTime(2026, 9, 21), statementDay: 21, dueDay: 15),
        DateTime(2026, 8, 21),
      );
      expect(
        previousClosing(DateTime(2026, 1, 21), statementDay: 21, dueDay: 15),
        DateTime(2025, 12, 21),
      );
    });
  });

  group('corte por defecto al registrar un estado', () {
    test('es el último sin registrar', () {
      final today = DateTime(2026, 9, 30);
      expect(defaultStatementClosing(today, settings, {}), DateTime(2026, 9, 21));
      expect(
        defaultStatementClosing(today, settings, {DateTime(2026, 9, 21)}),
        DateTime(2026, 8, 21),
      );
      expect(
        defaultStatementClosing(today, settings, {DateTime(2026, 9, 21), DateTime(2026, 8, 21)}),
        DateTime(2026, 7, 21),
      );
    });

    test('si todos están registrados, el más reciente', () {
      final all = {for (var i = 0; i < 24; i++) DateTime(2026, 9 - i, 21)};
      expect(defaultStatementClosing(DateTime(2026, 9, 30), settings, all), DateTime(2026, 9, 21));
    });
  });
}
