package com.draskint.qabal.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.time.Instant

/** Etiqueta libre para filtrar movimientos; el nombre es único sin distinguir mayúsculas. */
@Entity(tableName = "tags", indices = [Index(value = ["name"], unique = true)])
data class TagEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(collate = ColumnInfo.NOCASE) val name: String,
    val colorValue: Long? = null,
    @ColumnInfo(defaultValue = "0") val isArchived: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
