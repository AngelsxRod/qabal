package com.draskint.qabal.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtStatus
import java.time.Instant
import java.time.LocalDate

/**
 * Deuda con una persona (las tarjetas de crédito no van aquí). El saldo pendiente se calcula:
 * principal menos los abonos, que son movimientos con `debtId`.
 */
@Entity(
    tableName = "debts",
    foreignKeys = [
        ForeignKey(
            entity = ContactEntity::class,
            parentColumns = ["id"],
            childColumns = ["contactId"],
            onDelete = ForeignKey.RESTRICT,
        ),
    ],
    indices = [
        Index(value = ["contactId"], name = "idx_debts_contact"),
        Index(value = ["status"], name = "idx_debts_status"),
    ],
)
data class DebtEntity(
    @PrimaryKey val id: String,
    val contactId: String,
    val direction: DebtDirection,
    val principalMinor: Long,
    val currency: String,
    val description: String,
    val startDate: LocalDate,
    val dueDate: LocalDate? = null,
    @ColumnInfo(defaultValue = "OPEN") val status: DebtStatus = DebtStatus.OPEN,
    @ColumnInfo(defaultValue = "0") val isArchived: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
