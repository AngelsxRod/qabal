package com.draskint.qabal.data.mapper

import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CategoryEntity
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.domain.model.Account
import com.draskint.qabal.domain.model.Category
import com.draskint.qabal.domain.model.Contact
import com.draskint.qabal.domain.model.CreditCardSettings
import com.draskint.qabal.domain.model.Debt
import com.draskint.qabal.domain.model.Tag
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

fun CategoryEntity.toDomain() = Category(
    id = id, name = name, kind = kind, parentId = parentId, icon = icon, colorValue = colorValue,
    isArchived = isArchived, createdAt = createdAt, updatedAt = updatedAt,
)

fun ContactEntity.toDomain() = Contact(
    id = id, name = name, type = type, note = note, isArchived = isArchived,
    createdAt = createdAt, updatedAt = updatedAt,
)

fun TagEntity.toDomain() = Tag(
    id = id, name = name, colorValue = colorValue, isArchived = isArchived,
    createdAt = createdAt, updatedAt = updatedAt,
)

fun DebtEntity.toDomain() = Debt(
    id = id, contactId = contactId, direction = direction, principalMinor = principalMinor, currency = currency,
    description = description, startDate = startDate, dueDate = dueDate, status = status, isArchived = isArchived,
    createdAt = createdAt, updatedAt = updatedAt,
)
