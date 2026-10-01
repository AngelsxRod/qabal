package com.draskint.qabal.data.repository

import com.draskint.qabal.domain.card.validateCardSchedule
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.model.CreditCardSettings

private val currencyCode = Regex("^[A-Z]{3}$")

/** Texto no vacío (sin espacios en los extremos). */
fun requireText(value: String, field: String, max: Int = 80): String {
    val v = value.trim()
    if (v.isEmpty()) throw InvalidInputException("$field no puede estar vacío")
    if (v.length > max) throw InvalidInputException("$field no puede pasar de $max caracteres")
    return v
}

/** Código de moneda de 3 letras en mayúsculas. */
fun normalizeCurrency(value: String): String {
    val v = value.trim().uppercase()
    if (!currencyCode.matches(v)) throw InvalidInputException("Moneda inválida \"$value\" (se esperan 3 letras)")
    return v
}

fun validateCardSettings(s: CreditCardSettings) {
    if (s.creditLimitMinor <= 0) throw InvalidInputException("El límite de crédito debe ser mayor que cero")
    val bp = s.minPaymentBp
    if (bp != null && bp !in 0..10000) throw InvalidInputException("minPaymentBp debe estar entre 0 y 10000")
    validateCardSchedule(s.statementDay, s.dueDay)
}
