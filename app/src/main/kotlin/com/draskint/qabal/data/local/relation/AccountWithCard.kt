package com.draskint.qabal.data.local.relation

import androidx.room.Embedded
import androidx.room.Relation
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity

/** Cuenta con sus datos de tarjeta (solo si es de tipo `CREDIT_CARD`). */
data class AccountWithCard(
    @Embedded val account: AccountEntity,
    @Relation(parentColumn = "id", entityColumn = "accountId")
    val card: CreditCardDetailsEntity?,
)
