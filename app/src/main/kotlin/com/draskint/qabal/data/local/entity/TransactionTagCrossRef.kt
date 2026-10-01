package com.draskint.qabal.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

/** Relación muchos a muchos entre movimientos y etiquetas. */
@Entity(
    tableName = "transaction_tags",
    primaryKeys = ["transactionId", "tagId"],
    foreignKeys = [
        ForeignKey(TransactionEntity::class, ["id"], ["transactionId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(TagEntity::class, ["id"], ["tagId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index(value = ["tagId"], name = "idx_transaction_tags_tag")],
)
data class TransactionTagCrossRef(
    val transactionId: String,
    val tagId: String,
)
