package com.draskint.qabal.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey
import java.time.Instant

/**
 * Datos propios de una cuenta de tipo `CREDIT_CARD` (relación 1 a 1).
 * `minPaymentBp` es el pago mínimo estimado en puntos básicos (500 = 5 %).
 */
@Entity(
    tableName = "credit_card_details",
    foreignKeys = [
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.RESTRICT,
        ),
    ],
)
data class CreditCardDetailsEntity(
    @PrimaryKey val accountId: String,
    val creditLimitMinor: Long,
    val statementDay: Int,
    val dueDay: Int,
    val minPaymentBp: Int? = null,
    val createdAt: Instant,
    val updatedAt: Instant,
)
