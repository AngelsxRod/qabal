import 'package:finanzas/core/format/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDate usa mes abreviado en español', () {
    expect(formatDate(DateTime(2026, 9, 21)), '21 sep 2026');
    expect(formatDate(DateTime(2026, 1, 5)), '5 ene 2026');
    expect(formatDate(DateTime(2025, 12, 31, 23, 59)), '31 dic 2025');
  });

  group('formatDayHeader', () {
    final today = DateTime(2026, 9, 24, 15);

    test('hoy y ayer', () {
      expect(formatDayHeader(DateTime(2026, 9, 24, 1), today), 'Hoy');
      expect(formatDayHeader(DateTime(2026, 9, 23), today), 'Ayer');
    });

    test('otros días llevan día de la semana', () {
      expect(formatDayHeader(DateTime(2026, 9, 21), today), 'lunes 21 sep 2026');
      expect(formatDayHeader(DateTime(2026, 9, 27), today), 'domingo 27 sep 2026');
    });

    test('ayer cruza el cambio de mes y de año', () {
      expect(formatDayHeader(DateTime(2026, 8, 31), DateTime(2026, 9, 1)), 'Ayer');
      expect(formatDayHeader(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 'Ayer');
    });
  });
}
