package com.draskint.qabal.ui.error

import com.draskint.qabal.domain.error.ArchivedAccountException
import com.draskint.qabal.domain.error.DebtNotFullyPaidException
import com.draskint.qabal.domain.error.DuplicateNameException
import com.draskint.qabal.domain.error.InvalidAmountException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.InvalidTransferException
import com.draskint.qabal.domain.error.NotFoundException
import org.junit.Assert.assertEquals
import org.junit.Test

class ErrorMessagesTest {

    @Test
    fun `describe errores de dominio y desconocidos`() {
        assertEquals("Cuenta ya no existe. Puede que se haya eliminado.", describeError(NotFoundException("Cuenta", "x")))
        assertEquals("Ya existe \"Viaje\".", describeError(DuplicateNameException("Viaje")))
        assertEquals("La cuenta está archivada. Restáurala o elige otra cuenta.", describeError(ArchivedAccountException("a")))
        assertEquals("El monto debe ser mayor que cero", describeError(InvalidAmountException()))
        assertEquals("Quedan 5", describeError(DebtNotFullyPaidException("Quedan 5")))
        assertEquals("Ocurrió un error inesperado. Intenta de nuevo.", describeError(IllegalStateException("x")))
    }

    @Test
    fun `asigna cada error a su campo`() {
        assertEquals(ErrorField.AMOUNT, errorFieldOf(InvalidAmountException()))
        assertEquals(ErrorField.NAME, errorFieldOf(InvalidInputException("x")))
        assertEquals(ErrorField.NAME, errorFieldOf(DuplicateNameException("x")))
        assertEquals(ErrorField.GENERAL, errorFieldOf(NotFoundException("Cuenta", "x")))
        assertEquals(ErrorField.GENERAL, errorFieldOf(RuntimeException()))
    }

    @Test
    fun `distingue el campo de un error de transferencia`() {
        assertEquals(ErrorField.TRANSFER_AMOUNT, errorFieldOf(InvalidTransferException("indica el monto de destino")))
        assertEquals(ErrorField.DESTINATION, errorFieldOf(InvalidTransferException("requiere cuenta destino")))
        assertEquals(ErrorField.GENERAL, errorFieldOf(InvalidTransferException("Las transferencias no llevan categoría")))
    }

    @Test
    fun `una cuenta archivada va al campo de origen o de destino`() {
        val e = ArchivedAccountException("dest")
        assertEquals(ErrorField.DESTINATION, errorFieldOf(e, sourceAccountId = "src", destinationAccountId = "dest"))
        assertEquals(ErrorField.ACCOUNT, errorFieldOf(e, sourceAccountId = "dest", destinationAccountId = "dest"))
        assertEquals(ErrorField.ACCOUNT, errorFieldOf(ArchivedAccountException("src"), "src", "dest"))
    }
}
