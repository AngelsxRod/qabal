import 'package:finanzas/domain/credit_card/card_schedule.dart';
import 'package:finanzas/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('horarios válidos', () {
    for (final (s, d) in [(21, 15), (5, 25), (31, 15), (28, 15), (27, 28), (1, 31), (15, 15)]) {
      test('corte $s, pago $d', () {
        expect(() => validateCardSchedule(statementDay: s, dueDay: d), returnsNormally);
      });
    }
  });

  group('corte y pago que pueden coincidir', () {
    for (final (s, d) in [(30, 31), (28, 29), (29, 30), (29, 31), (28, 31)]) {
      test('corte $s, pago $d', () {
        expect(
          () => validateCardSchedule(statementDay: s, dueDay: d),
          throwsA(isA<InvalidCardScheduleException>()),
        );
      });
    }
  });

  test('días fuera de 1–31', () {
    expect(() => validateCardSchedule(statementDay: 0, dueDay: 15),
        throwsA(isA<InvalidInputException>()));
    expect(() => validateCardSchedule(statementDay: 21, dueDay: 32),
        throwsA(isA<InvalidInputException>()));
  });
}
