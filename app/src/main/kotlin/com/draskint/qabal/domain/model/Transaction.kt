package com.draskint.qabal.domain.model

import java.time.Instant

data class Transaction(
    val id: String,
    val accountId: String,
    val categoryId: String?,
    val type: TransactionType,
    val amountMinor: Long,
    val transferAccountId: String?,
    val transferAmountMinor: Long?,
    val contactId: String?,
    val debtId: String?,
    val statementId: String?,
    val note: String?,
    val receiptPath: String?,
    val occurredAt: Instant,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class TransactionInput(
    val accountId: String,
    val type: TransactionType,
    val amountMinor: Long,
    val occurredAt: Instant,
    val categoryId: String? = null,
    val transferAccountId: String? = null,
    val transferAmountMinor: Long? = null,
    val contactId: String? = null,
    val debtId: String? = null,
    val statementId: String? = null,
    val note: String? = null,
    val receiptPath: String? = null,
)

/**
 * Filtros de listado de movimientos. [to] es exclusivo. [accountId] incluye los movimientos de la
 * cuenta y las transferencias que le llegan.
 */
data class TransactionFilter(
    val accountId: String? = null,
    val categoryId: String? = null,
    val contactId: String? = null,
    val debtId: String? = null,
    val statementId: String? = null,
    val tagId: String? = null,
    val type: TransactionType? = null,
    val from: Instant? = null,
    val to: Instant? = null,
    val limit: Int? = null,
    val offset: Int? = null,
)
