package com.draskint.qabal.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.draskint.qabal.domain.model.ContactType
import java.time.Instant

/** De quién viene o a quién va el dinero (empleador, cliente, persona...). */
@Entity(tableName = "contacts")
data class ContactEntity(
    @PrimaryKey val id: String,
    val name: String,
    val type: ContactType? = null,
    val note: String? = null,
    @ColumnInfo(defaultValue = "0") val isArchived: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
