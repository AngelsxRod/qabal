import '../../domain/errors.dart';

/// Texto en español para mostrar al usuario cuando algo falla.
///
/// El `switch` es exhaustivo sobre `DomainException` (es `sealed`): al agregar
/// un error nuevo, el compilador obliga a decidir cómo se comunica.
String describeError(Object error) {
  if (error is! DomainException) return 'Ocurrió un error inesperado. Intenta de nuevo.';
  return switch (error) {
    NotFoundException(:final entity) => '$entity ya no existe. Puede que se haya eliminado.',
    InvalidInputException(:final message) => message,
    InvalidAmountException(:final message) => message,
    InvalidTransferException(:final message) => message,
    NotACreditCardException() => 'La cuenta no es una tarjeta de crédito.',
    InvalidStatementLinkException(:final message) => message,
    CurrencyMismatchException(:final message) => message,
    DebtMovementCategoryException(:final message) => message,
    CategoryKindMismatchException(:final message) => message,
    ArchivedAccountException() =>
      'La cuenta está archivada. Restáurala o elige otra cuenta.',
    InvalidCardScheduleException(:final message) => message,
    DuplicateStatementException(:final message) => message,
    StatementOverlapException(:final message) => message,
    DuplicateNameException(:final name) => 'Ya existe "$name".',
    DebtNotFullyPaidException(:final message) => message,
    DebtClosedException(:final message) => message,
  };
}

/// Campo de un formulario al que pertenece un error de dominio.
enum ErrorField {
  name,
  amount,
  transferAmount,
  account,
  destination,
  category,
  cardSchedule,
  general,
}

/// Decide en qué campo mostrar [error]. Lo que no pertenece a un campo
/// concreto cae en [ErrorField.general] (se muestra como aviso del formulario).
///
/// [sourceAccountId] y [destinationAccountId] permiten distinguir a cuál de
/// las dos cuentas del movimiento se refiere un error de cuenta archivada.
ErrorField errorFieldOf(
  Object error, {
  String? sourceAccountId,
  String? destinationAccountId,
}) {
  if (error is! DomainException) return ErrorField.general;
  return switch (error) {
    InvalidAmountException() => ErrorField.amount,
    InvalidInputException() || DuplicateNameException() => ErrorField.name,
    CategoryKindMismatchException() => ErrorField.category,
    InvalidCardScheduleException() => ErrorField.cardSchedule,
    ArchivedAccountException(:final accountId) =>
      accountId == destinationAccountId && accountId != sourceAccountId
          ? ErrorField.destination
          : ErrorField.account,
    InvalidTransferException(:final message) => message.contains('monto de destino')
        ? ErrorField.transferAmount
        : message.contains('destino')
            ? ErrorField.destination
            : ErrorField.general,
    _ => ErrorField.general,
  };
}
