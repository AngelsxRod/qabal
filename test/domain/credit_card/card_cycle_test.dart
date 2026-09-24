import 'package:finanzas/domain/credit_card/card_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

CardCycle cycle(DateTime purchase, int statementDay, int dueDay) =>
    cycleForPurchase(purchase, statementDay: statementDay, dueDay: dueDay);

CardCycle expected(DateTime start, DateTime closing, DateTime due) =>
    CardCycle(periodStart: start, closingDate: closing, dueDate: due);

void main() {
  group('corte 21, pago 15', () {
    final sep = expected(DateTime(2026, 8, 22), DateTime(2026, 9, 21), DateTime(2026, 10, 15));

    test('25 ago → corte 21 sep, pago 15 oct', () {
      expect(cycle(DateTime(2026, 8, 25), 21, 15), sep);
    });
    test('5 sep → corte 21 sep, pago 15 oct', () {
      expect(cycle(DateTime(2026, 9, 5), 21, 15), sep);
    });
    test('21 sep (día de corte, inclusive) → corte 21 sep', () {
      expect(cycle(DateTime(2026, 9, 21), 21, 15), sep);
      expect(cycle(DateTime(2026, 9, 21, 23, 59, 59), 21, 15), sep);
    });
    test('22 sep → corte 21 oct, pago 15 nov', () {
      expect(
        cycle(DateTime(2026, 9, 22), 21, 15),
        expected(DateTime(2026, 9, 22), DateTime(2026, 10, 21), DateTime(2026, 11, 15)),
      );
    });
    test('22 ago (primer día del período) → corte 21 sep', () {
      expect(cycle(DateTime(2026, 8, 22), 21, 15), sep);
    });
  });

  group('día de corte al final de mes', () {
    test('31 en febrero no bisiesto', () {
      expect(
        cycle(DateTime(2025, 2, 10), 31, 15),
        expected(DateTime(2025, 2, 1), DateTime(2025, 2, 28), DateTime(2025, 3, 15)),
      );
    });
    test('31 en febrero bisiesto', () {
      expect(
        cycle(DateTime(2024, 2, 10), 31, 15),
        expected(DateTime(2024, 2, 1), DateTime(2024, 2, 29), DateTime(2024, 3, 15)),
      );
    });
    test('30 en febrero: no bisiesto y bisiesto', () {
      expect(
        cycle(DateTime(2025, 2, 10), 30, 15),
        expected(DateTime(2025, 1, 31), DateTime(2025, 2, 28), DateTime(2025, 3, 15)),
      );
      expect(
        cycle(DateTime(2024, 2, 10), 30, 15),
        expected(DateTime(2024, 1, 31), DateTime(2024, 2, 29), DateTime(2024, 3, 15)),
      );
    });
    test('29 en febrero: no bisiesto y bisiesto', () {
      expect(
        cycle(DateTime(2025, 2, 10), 29, 15),
        expected(DateTime(2025, 1, 30), DateTime(2025, 2, 28), DateTime(2025, 3, 15)),
      );
      expect(
        cycle(DateTime(2024, 2, 10), 29, 15),
        expected(DateTime(2024, 1, 30), DateTime(2024, 2, 29), DateTime(2024, 3, 15)),
      );
    });
    test('compra el último día de febrero entra a ese corte', () {
      expect(cycle(DateTime(2025, 2, 28), 31, 15).closingDate, DateTime(2025, 2, 28));
      expect(cycle(DateTime(2025, 3, 1), 31, 15).closingDate, DateTime(2025, 3, 31));
      expect(cycle(DateTime(2025, 3, 1), 31, 15).periodStart, DateTime(2025, 3, 1));
    });
    test('31 en meses de 30 días', () {
      expect(
        cycle(DateTime(2026, 4, 15), 31, 10),
        expected(DateTime(2026, 4, 1), DateTime(2026, 4, 30), DateTime(2026, 5, 10)),
      );
      expect(
        cycle(DateTime(2026, 5, 15), 31, 10),
        expected(DateTime(2026, 5, 1), DateTime(2026, 5, 31), DateTime(2026, 6, 10)),
      );
    });
    test('30 en abril usa el 30; en mayo también', () {
      expect(cycle(DateTime(2026, 4, 30), 30, 15).closingDate, DateTime(2026, 4, 30));
      expect(cycle(DateTime(2026, 5, 1), 30, 15).closingDate, DateTime(2026, 5, 30));
    });
  });

  group('cambio de año', () {
    test('corte 21 dic → pago 15 ene', () {
      expect(
        cycle(DateTime(2026, 12, 21), 21, 15),
        expected(DateTime(2026, 11, 22), DateTime(2026, 12, 21), DateTime(2027, 1, 15)),
      );
    });
    test('22 dic → corte 21 ene, pago 15 feb', () {
      expect(
        cycle(DateTime(2026, 12, 22), 21, 15),
        expected(DateTime(2026, 12, 22), DateTime(2027, 1, 21), DateTime(2027, 2, 15)),
      );
    });
    test('5 ene → corte 21 ene con inicio en diciembre', () {
      expect(
        cycle(DateTime(2027, 1, 5), 21, 15),
        expected(DateTime(2026, 12, 22), DateTime(2027, 1, 21), DateTime(2027, 2, 15)),
      );
    });
  });

  group('pago en el mismo mes (dueDay > statementDay)', () {
    test('corte 5, pago 25', () {
      expect(
        cycle(DateTime(2026, 9, 3), 5, 25),
        expected(DateTime(2026, 8, 6), DateTime(2026, 9, 5), DateTime(2026, 9, 25)),
      );
      expect(
        cycle(DateTime(2026, 9, 6), 5, 25),
        expected(DateTime(2026, 9, 6), DateTime(2026, 10, 5), DateTime(2026, 10, 25)),
      );
    });
    test('cambio de año', () {
      expect(
        cycle(DateTime(2026, 12, 10), 5, 25),
        expected(DateTime(2026, 12, 6), DateTime(2027, 1, 5), DateTime(2027, 1, 25)),
      );
    });
  });

  group('zona horaria', () {
    test('usa la fecha local, no la UTC', () {
      // Medianoche local del 22 sep, expresada como instante UTC.
      final instant = DateTime(2026, 9, 22).toUtc();
      expect(cycle(instant, 21, 15).closingDate, DateTime(2026, 10, 21));
      // 23:59 local del 21 sep sigue en el corte del 21.
      final late = DateTime(2026, 9, 21, 23, 59).toUtc();
      expect(cycle(late, 21, 15).closingDate, DateTime(2026, 9, 21));
    });
  });

  group('cycleClosingOn', () {
    test('devuelve el ciclo que cierra en el mes indicado', () {
      expect(
        cycleClosingOn(2026, 9, statementDay: 21, dueDay: 15),
        expected(DateTime(2026, 8, 22), DateTime(2026, 9, 21), DateTime(2026, 10, 15)),
      );
    });
    test('ciclos consecutivos no se solapan ni dejan huecos', () {
      final a = cycleClosingOn(2025, 1, statementDay: 31, dueDay: 15);
      final b = cycleClosingOn(2025, 2, statementDay: 31, dueDay: 15);
      expect(b.periodStart, DateTime(a.closingDate.year, a.closingDate.month, a.closingDate.day + 1));
    });
  });

  test('rechaza días fuera de 1–31', () {
    expect(() => cycle(DateTime(2026, 9, 1), 0, 15), throwsArgumentError);
    expect(() => cycle(DateTime(2026, 9, 1), 21, 32), throwsArgumentError);
  });
}
