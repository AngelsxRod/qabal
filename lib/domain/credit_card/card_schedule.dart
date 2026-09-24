import '../errors.dart';
import 'card_cycle.dart';

/// Valida la combinación de día de corte y día de pago de una tarjeta.
///
/// Se rechaza si en algún mes (de un año bisiesto y uno no bisiesto) la fecha
/// de pago no queda estrictamente después del corte. En la práctica ocurre con
/// `dueDay > statementDay` y `statementDay >= 28` (ej. corte 30, pago 31 en
/// febrero).
void validateCardSchedule({required int statementDay, required int dueDay}) {
  for (final (name, day) in [('statementDay', statementDay), ('dueDay', dueDay)]) {
    if (day < 1 || day > 31) {
      throw InvalidInputException('$name debe estar entre 1 y 31 (recibido $day)');
    }
  }
  for (final year in [2024, 2025]) {
    for (var month = 1; month <= 12; month++) {
      final c = cycleClosingOn(year, month,
          statementDay: statementDay, dueDay: dueDay);
      if (!c.dueDate.isAfter(c.closingDate)) {
        throw InvalidCardScheduleException(
          'Con corte $statementDay y pago $dueDay, en $year-$month el pago '
          '(${c.dueDate.day}) cae el mismo día del corte o antes',
        );
      }
    }
  }
}
