package com.draskint.qabal.data.mapper

import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.domain.model.Account
import com.draskint.qabal.domain.model.CreditCardSettings
import com.draskint.qabal.domain.model.Transaction

fun AccountEntity.toDomain() = Account(
    id = id, name = name, type = type, currency = currency, initialBalanceMinor = initialBalanceMinor,
    isArchived = isArchived, createdAt = createdAt, updatedAt = updatedAt,
)

fun CreditCardDetailsEntity.toSettings() = CreditCardSettings(
    creditLimitMinor = creditLimitMinor, statementDay = statementDay, dueDay = dueDay, minPaymentBp = minPaymentBp,
)

fun TransactionEntity.toDomain() = Transaction(
    id = id, accountId = accountId, categoryId = categoryId, type = type, amountMinor = amountMinor,
    transferAccountId = transferAccountId, transferAmountMinor = transferAmountMinor, contactId = contactId,
    debtId = debtId, statementId = statementId, note = note, receiptPath = receiptPath,
    occurredAt = occurredAt, createdAt = createdAt, updatedAt = updatedAt,
)
