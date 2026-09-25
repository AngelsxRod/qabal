import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../../domain/credit_card/card_cycle.dart';
import '../../domain/credit_card/statement_status.dart';
import '../design/tokens.dart';

/// Días de calendario de [from] a [to] (negativo si [to] ya pasó).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String statementStatusLabel(StatementStatus status) => switch (status) {
  StatementStatus.paid => 'Pagado',
  StatementStatus.minimumCovered => 'Mínimo cubierto',
  StatementStatus.pending => 'Pendiente',
  StatementStatus.overdue => 'Vencido',
};

Color statementStatusTone(BuildContext context, StatementStatus status) {
  final c = context.colors;
  return switch (status) {
    StatementStatus.paid => c.income,
    StatementStatus.minimumCovered => c.accent,
    StatementStatus.pending => c.textSecondary,
    StatementStatus.overdue => c.expense,
  };
}

/// "Faltan 3 días", "Falta 1 día", "Hoy" o "Hace 2 días" según [days].
String daysLabel(int days) {
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Falta 1 día';
  if (days > 1) return 'Faltan $days días';
  if (days == -1) return 'Hace 1 día';
  return 'Hace ${-days} días';
}

/// Corte anterior a [closing] (que debe ser un día de corte).
DateTime previousClosing(DateTime closing, {required int statementDay, required int dueDay}) {
  final start = cycleForPurchase(closing, statementDay: statementDay, dueDay: dueDay).periodStart;
  return DateTime(start.year, start.month, start.day - 1);
}

/// Último corte de la tarjeta que ya ocurrió (hoy incluido), según su día de
/// corte.
DateTime lastClosingOnOrBefore(DateTime today, {required int statementDay, required int dueDay}) {
  final cycle = cycleForPurchase(today, statementDay: statementDay, dueDay: dueDay);
  if (!cycle.closingDate.isAfter(today)) return cycle.closingDate;
  return previousClosing(cycle.closingDate, statementDay: statementDay, dueDay: dueDay);
}

/// Corte por defecto al registrar un estado de cuenta: el más reciente ya
/// ocurrido que aún no tiene estado registrado (hasta 12 cortes atrás; si
/// todos lo tienen, el más reciente).
DateTime defaultStatementClosing(
  DateTime today,
  CreditCardDetail settings,
  Set<DateTime> registeredClosings,
) {
  final latest = lastClosingOnOrBefore(
    today,
    statementDay: settings.statementDay,
    dueDay: settings.dueDay,
  );
  var closing = latest;
  for (var i = 0; i < 12; i++) {
    if (!registeredClosings.contains(closing)) return closing;
    closing = previousClosing(
      closing,
      statementDay: settings.statementDay,
      dueDay: settings.dueDay,
    );
  }
  return latest;
}
