import '../../domain/credit_card/card_schedule.dart';
import '../../domain/errors.dart';
import 'models.dart';

/// Texto no vacío (sin espacios en los extremos).
String requireText(String value, String field, {int max = 80}) {
  final v = value.trim();
  if (v.isEmpty) throw InvalidInputException('$field no puede estar vacío');
  if (v.length > max) {
    throw InvalidInputException('$field no puede pasar de $max caracteres');
  }
  return v;
}

/// Código de moneda de 3 letras en mayúsculas.
String normalizeCurrency(String value) {
  final v = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(v)) {
    throw InvalidInputException('Moneda inválida "$value" (se esperan 3 letras)');
  }
  return v;
}

void validateCardSettings(CreditCardSettings s) {
  if (s.creditLimitMinor <= 0) {
    throw const InvalidInputException('El límite de crédito debe ser mayor que cero');
  }
  final bp = s.minPaymentBp;
  if (bp != null && (bp < 0 || bp > 10000)) {
    throw const InvalidInputException('minPaymentBp debe estar entre 0 y 10000');
  }
  validateCardSchedule(statementDay: s.statementDay, dueDay: s.dueDay);
}
