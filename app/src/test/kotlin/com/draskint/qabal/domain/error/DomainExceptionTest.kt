package com.draskint.qabal.domain.error

import com.draskint.qabal.domain.model.DebtStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DomainExceptionTest {

    @Test
    fun `los mensajes incluyen el dato que falla`() {
        assertEquals("Cuenta \"x\" no existe", NotFoundException("Cuenta", "x").message)
        assertEquals("Ya existe \"Viaje\"", DuplicateNameException("Viaje").message)
        assertEquals("El monto debe ser mayor que cero", InvalidAmountException().message)
    }

    @Test
    fun `una deuda cerrada dice si esta saldada o perdonada`() {
        assertTrue(DebtClosedException("d", DebtStatus.SETTLED).message.contains("saldada"))
        assertTrue(DebtClosedException("d", DebtStatus.FORGIVEN).message.contains("perdonada"))
    }
}
