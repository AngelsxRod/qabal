package com.draskint.qabal.domain.error

import com.draskint.qabal.domain.model.DebtStatus

/**
 * Errores de dominio: reglas de negocio que la capa de datos rechaza. Se lanzan como excepciones;
 * dentro de una transacción de Room provocan rollback. Es `sealed` para que la UI los describa con
 * un `when` exhaustivo.
 */
sealed class DomainException(override val message: String) : Exception(message)

/** El registro referenciado no existe. */
class NotFoundException(val entity: String, val id: String) : DomainException("$entity \"$id\" no existe")

/** Dato de entrada inválido (campo vacío, valor fuera de rango, combinación no permitida). */
class InvalidInputException(message: String) : DomainException(message)

class InvalidAmountException : DomainException("El monto debe ser mayor que cero")

/** Transferencia mal formada (sin destino, mismo origen y destino, monto de destino faltante o sobrante). */
class InvalidTransferException(message: String) : DomainException(message)

/** Detalles de tarjeta o estado de cuenta sobre una cuenta que no es `CREDIT_CARD`. */
class NotACreditCardException(val accountId: String) :
    DomainException("La cuenta \"$accountId\" no es una tarjeta de crédito")

/** `statementId` solo puede venir de una transferencia hacia la tarjeta a la que pertenece el estado. */
class InvalidStatementLinkException(message: String) : DomainException(message)

/** Moneda de la cuenta distinta de la de la deuda. */
class CurrencyMismatchException(message: String) : DomainException(message)

/** Un movimiento con `debtId` (o una transferencia) no lleva categoría. */
class DebtMovementCategoryException(message: String) : DomainException(message)

class CategoryKindMismatchException(message: String) : DomainException(message)

class ArchivedAccountException(val accountId: String) :
    DomainException("La cuenta \"$accountId\" está archivada")

/** Combinación de día de corte y día de pago que puede hacer coincidir ambas fechas. */
class InvalidCardScheduleException(message: String) : DomainException(message)

class DuplicateStatementException(message: String) : DomainException(message)

class StatementOverlapException(message: String) : DomainException(message)

class DuplicateNameException(val name: String) : DomainException("Ya existe \"$name\"")

/** Se intentó saldar una deuda con saldo pendiente. */
class DebtNotFullyPaidException(message: String) : DomainException(message)

/** Se intentó registrar un abono en una deuda saldada o perdonada; hay que reabrirla primero. */
class DebtClosedException(val debtId: String, val status: DebtStatus) : DomainException(
    "La deuda \"$debtId\" está ${if (status == DebtStatus.SETTLED) "saldada" else "perdonada"}; " +
        "reábrela para registrar abonos",
)
