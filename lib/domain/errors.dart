/// Errores de dominio: reglas de negocio que la capa de datos rechaza.
/// Se lanzan como excepciones; dentro de `db.transaction` provocan rollback.
sealed class DomainException implements Exception {
  const DomainException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// El registro referenciado no existe.
final class NotFoundException extends DomainException {
  NotFoundException(this.entity, this.id) : super('$entity "$id" no existe');

  final String entity;
  final String id;
}

/// Dato de entrada inválido (campo vacío, valor fuera de rango, combinación
/// no permitida).
final class InvalidInputException extends DomainException {
  const InvalidInputException(super.message);
}

final class InvalidAmountException extends DomainException {
  const InvalidAmountException() : super('El monto debe ser mayor que cero');
}

/// Transferencia mal formada (sin destino, mismo origen y destino, monto de
/// destino faltante o sobrante).
final class InvalidTransferException extends DomainException {
  const InvalidTransferException(super.message);
}

/// Detalles de tarjeta o estado de cuenta sobre una cuenta que no es
/// `creditCard`.
final class NotACreditCardException extends DomainException {
  NotACreditCardException(this.accountId)
      : super('La cuenta "$accountId" no es una tarjeta de crédito');

  final String accountId;
}

/// `statementId` solo puede venir de una transferencia hacia la tarjeta a la
/// que pertenece el estado de cuenta.
final class InvalidStatementLinkException extends DomainException {
  const InvalidStatementLinkException(super.message);
}

/// Moneda de la cuenta distinta de la de la deuda.
final class CurrencyMismatchException extends DomainException {
  const CurrencyMismatchException(super.message);
}

/// Un movimiento con `debtId` (o una transferencia) no lleva categoría.
final class DebtMovementCategoryException extends DomainException {
  const DebtMovementCategoryException(super.message);
}

final class CategoryKindMismatchException extends DomainException {
  const CategoryKindMismatchException(super.message);
}

final class ArchivedAccountException extends DomainException {
  ArchivedAccountException(this.accountId)
      : super('La cuenta "$accountId" está archivada');

  final String accountId;
}

/// Combinación de día de corte y día de pago que puede hacer coincidir ambas
/// fechas.
final class InvalidCardScheduleException extends DomainException {
  const InvalidCardScheduleException(super.message);
}

final class DuplicateStatementException extends DomainException {
  const DuplicateStatementException(super.message);
}

final class StatementOverlapException extends DomainException {
  const StatementOverlapException(super.message);
}

final class DuplicateNameException extends DomainException {
  DuplicateNameException(this.name) : super('Ya existe "$name"');

  final String name;
}

/// Se intentó saldar una deuda con saldo pendiente.
final class DebtNotFullyPaidException extends DomainException {
  const DebtNotFullyPaidException(super.message);
}

/// Se intentó registrar un abono en una deuda `settled` o `forgiven`. Hay que
/// reabrirla primero.
final class DebtClosedException extends DomainException {
  DebtClosedException(this.debtId, this.status)
      : super('La deuda "$debtId" está ${status == 'settled' ? 'saldada' : 'perdonada'}; '
            'reábrela para registrar abonos');

  final String debtId;
  final String status;
}
