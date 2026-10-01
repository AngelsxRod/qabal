package com.draskint.qabal.domain.model

import java.time.Instant

data class Account(
    val id: String,
    val name: String,
    val type: AccountType,
    val currency: String,
    val initialBalanceMinor: Long,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

/** Datos propios de una tarjeta. `minPaymentBp` es el pago mínimo estimado en puntos básicos (500 = 5 %). */
data class CreditCardSettings(
    val creditLimitMinor: Long,
    val statementDay: Int,
    val dueDay: Int,
    val minPaymentBp: Int? = null,
)

/**
 * Datos para crear una cuenta.
 *
 * CONVENCIÓN DE SIGNO: en una tarjeta de crédito el saldo es negativo cuando se debe dinero, así
 * que [initialBalanceMinor] es **negativo** si la tarjeta ya tenía deuda al empezar a usar la app
 * (deuda 500.00 → `-50000`). La UI debe convertir desde un valor de "deuda actual" positivo. En
 * cuentas normales es el saldo a favor.
 */
data class AccountInput(
    val name: String,
    val type: AccountType,
    val currency: String,
    val initialBalanceMinor: Long = 0,
)

/** Cuenta con su saldo calculado. En tarjetas de crédito, negativo = deuda. */
data class AccountBalance(val account: Account, val balanceMinor: Long)
