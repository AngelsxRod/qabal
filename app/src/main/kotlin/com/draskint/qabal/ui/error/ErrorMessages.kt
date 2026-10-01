package com.draskint.qabal.ui.error

import com.draskint.qabal.domain.error.ArchivedAccountException
import com.draskint.qabal.domain.error.CategoryKindMismatchException
import com.draskint.qabal.domain.error.CurrencyMismatchException
import com.draskint.qabal.domain.error.DebtClosedException
import com.draskint.qabal.domain.error.DebtMovementCategoryException
import com.draskint.qabal.domain.error.DebtNotFullyPaidException
import com.draskint.qabal.domain.error.DomainException
import com.draskint.qabal.domain.error.DuplicateNameException
import com.draskint.qabal.domain.error.DuplicateStatementException
import com.draskint.qabal.domain.error.InvalidAmountException
import com.draskint.qabal.domain.error.InvalidCardScheduleException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.InvalidStatementLinkException
import com.draskint.qabal.domain.error.InvalidTransferException
import com.draskint.qabal.domain.error.NotACreditCardException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.error.StatementOverlapException

/**
 * Texto en español para mostrar al usuario cuando algo falla.
 *
 * El `when` es exhaustivo sobre [DomainException] (sellada): al agregar un error nuevo, el
 * compilador obliga a decidir cómo se comunica.
 */
fun describeError(error: Throwable): String {
    if (error !is DomainException) return "Ocurrió un error inesperado. Intenta de nuevo."
    return when (error) {
        is NotFoundException -> "${error.entity} ya no existe. Puede que se haya eliminado."
        is NotACreditCardException -> "La cuenta no es una tarjeta de crédito."
        is ArchivedAccountException -> "La cuenta está archivada. Restáurala o elige otra cuenta."
        is DuplicateNameException -> "Ya existe \"${error.name}\"."
        is InvalidInputException, is InvalidAmountException, is InvalidTransferException,
        is InvalidStatementLinkException, is CurrencyMismatchException, is DebtMovementCategoryException,
        is CategoryKindMismatchException, is InvalidCardScheduleException, is DuplicateStatementException,
        is StatementOverlapException, is DebtNotFullyPaidException, is DebtClosedException,
        -> error.message
    }
}

/** Campo de un formulario al que pertenece un error de dominio. */
enum class ErrorField { NAME, AMOUNT, TRANSFER_AMOUNT, ACCOUNT, DESTINATION, CATEGORY, CARD_SCHEDULE, GENERAL }

/**
 * Decide en qué campo mostrar [error]. Lo que no pertenece a un campo concreto cae en
 * [ErrorField.GENERAL] (aviso del formulario).
 *
 * [sourceAccountId] y [destinationAccountId] permiten distinguir a cuál de las dos cuentas del
 * movimiento se refiere un error de cuenta archivada.
 */
fun errorFieldOf(
    error: Throwable,
    sourceAccountId: String? = null,
    destinationAccountId: String? = null,
): ErrorField {
    if (error !is DomainException) return ErrorField.GENERAL
    return when (error) {
        is InvalidAmountException -> ErrorField.AMOUNT
        is InvalidInputException, is DuplicateNameException -> ErrorField.NAME
        is CategoryKindMismatchException -> ErrorField.CATEGORY
        is InvalidCardScheduleException -> ErrorField.CARD_SCHEDULE
        is ArchivedAccountException ->
            if (error.accountId == destinationAccountId && error.accountId != sourceAccountId) {
                ErrorField.DESTINATION
            } else {
                ErrorField.ACCOUNT
            }
        is InvalidTransferException -> when {
            "monto de destino" in error.message -> ErrorField.TRANSFER_AMOUNT
            "destino" in error.message -> ErrorField.DESTINATION
            else -> ErrorField.GENERAL
        }
        is NotFoundException, is NotACreditCardException, is InvalidStatementLinkException,
        is CurrencyMismatchException, is DebtMovementCategoryException, is DuplicateStatementException,
        is StatementOverlapException, is DebtNotFullyPaidException, is DebtClosedException,
        -> ErrorField.GENERAL
    }
}
