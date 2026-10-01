package com.draskint.qabal.domain.model

enum class AccountType { CASH, BANK, CREDIT_CARD, SAVINGS, OTHER }

enum class CategoryKind { INCOME, EXPENSE }

enum class TransactionType { INCOME, EXPENSE, TRANSFER }

enum class ContactType { PERSON, COMPANY, EMPLOYER }

enum class DebtDirection { I_OWE, OWED_TO_ME }

enum class DebtStatus { OPEN, SETTLED, FORGIVEN }
