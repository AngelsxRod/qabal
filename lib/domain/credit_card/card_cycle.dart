import 'dart:math' as math;

/// Ciclo de facturación de una tarjeta. Las tres fechas son de calendario
/// (medianoche local); `closingDate` y `periodStart` son inclusivas.
class CardCycle {
  const CardCycle({
    required this.periodStart,
    required this.closingDate,
    required this.dueDate,
  });

  final DateTime periodStart;
  final DateTime closingDate;
  final DateTime dueDate;

  @override
  bool operator ==(Object other) =>
      other is CardCycle &&
      other.periodStart == periodStart &&
      other.closingDate == closingDate &&
      other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(periodStart, closingDate, dueDate);

  @override
  String toString() =>
      'CardCycle(inicio: $periodStart, corte: $closingDate, pago: $dueDate)';
}

/// Ciclo al que pertenece una compra hecha en `occurredAt` (se usa su fecha
/// local). Una compra el día de corte todavía entra a ese corte.
CardCycle cycleForPurchase(
  DateTime occurredAt, {
  required int statementDay,
  required int dueDay,
}) {
  _checkDay(statementDay, 'statementDay');
  _checkDay(dueDay, 'dueDay');
  final local = occurredAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final closingThisMonth = _dayIn(local.year, local.month, statementDay);
  final month = day.isAfter(closingThisMonth) ? local.month + 1 : local.month;
  final target = DateTime(local.year, month);
  return cycleClosingOn(
    target.year,
    target.month,
    statementDay: statementDay,
    dueDay: dueDay,
  );
}

/// Ciclo cuyo corte cae en el mes `month` del año `year`.
///
/// La fecha de pago es la primera ocurrencia de `dueDay` posterior al corte:
/// mes siguiente si `dueDay <= statementDay` (corte 21, pago 15) y el mismo
/// mes si `dueDay > statementDay` (corte 5, pago 25).
CardCycle cycleClosingOn(
  int year,
  int month, {
  required int statementDay,
  required int dueDay,
}) {
  _checkDay(statementDay, 'statementDay');
  _checkDay(dueDay, 'dueDay');
  final closing = _dayIn(year, month, statementDay);
  final previousClosing = _dayIn(year, month - 1, statementDay);
  final start = DateTime(
    previousClosing.year,
    previousClosing.month,
    previousClosing.day + 1,
  );
  final dueMonth = dueDay > statementDay ? month : month + 1;
  return CardCycle(
    periodStart: start,
    closingDate: closing,
    dueDate: _dayIn(year, dueMonth, dueDay),
  );
}

/// Día `day` del mes indicado (el mes puede desbordar: 0 = diciembre del año
/// anterior, 13 = enero del siguiente). Si el mes es más corto, último día.
DateTime _dayIn(int year, int month, int day) {
  final first = DateTime(year, month);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, math.min(day, lastDay));
}

void _checkDay(int day, String name) {
  if (day < 1 || day > 31) {
    throw ArgumentError.value(day, name, 'debe estar entre 1 y 31');
  }
}
