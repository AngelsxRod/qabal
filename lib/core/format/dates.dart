/// Formatos de fecha en español, sin `intl`.
library;

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', //
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

const _weekdays = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo', //
];

/// `2026-09-21` → `21 sep 2026`.
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// `2026-10-21` → `21 oct`.
String formatDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// `2026-09-21` → `Septiembre 2026`.
String formatMonth(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// Encabezado de un grupo de movimientos: `Hoy`, `Ayer` o
/// `lunes 21 sep 2026`.
String formatDayHeader(DateTime d, DateTime today) {
  final day = DateTime(d.year, d.month, d.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = DateTime.utc(t.year, t.month, t.day)
      .difference(DateTime.utc(day.year, day.month, day.day))
      .inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${_weekdays[day.weekday - 1]} ${formatDate(day)}';
}
