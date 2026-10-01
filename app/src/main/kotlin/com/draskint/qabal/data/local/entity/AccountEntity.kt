package com.draskint.qabal.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.draskint.qabal.domain.model.AccountType
import java.time.Instant

/** Cuenta de dinero. Cada una tiene su moneda ISO-4217 y su saldo inicial en unidades menores. */
@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey val id: String,
    val name: String,
    val type: AccountType,
    val currency: String,
    @ColumnInfo(defaultValue = "0") val initialBalanceMinor: Long = 0,
    @ColumnInfo(defaultValue = "0") val isArchived: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
