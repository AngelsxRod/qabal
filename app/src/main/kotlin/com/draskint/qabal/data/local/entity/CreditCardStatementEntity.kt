package com.draskint.qabal.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.time.Instant
import java.time.LocalDate

/**
 * Estado de cuenta ya cerrado, con los valores que reporta el banco. El estado (pagado, vencido...)
 * no se guarda: se calcula a partir de los pagos asociados y la fecha actual.
 */
@Entity(
    tableName = "credit_card_statements",
    foreignKeys = [
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.RESTRICT,
        ),
    ],
    indices = [
        Index(value = ["accountId", "dueDate"], name = "idx_statements_account_due"),
        Index(value = ["accountId", "closingDate"], unique = true),
    ],
)
data class CreditCardStatementEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val periodStart: LocalDate,
    val closingDate: LocalDate,
    val dueDate: LocalDate,
    val statementBalanceMinor: Long,
    val minimumPaymentMinor: Long,
    val note: String? = null,
    @ColumnInfo(defaultValue = "0") val isArchived: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
