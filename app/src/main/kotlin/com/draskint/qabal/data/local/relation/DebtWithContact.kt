package com.draskint.qabal.data.local.relation

import androidx.room.Embedded
import androidx.room.Relation
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.local.entity.DebtEntity

/** Deuda con el contacto al que pertenece. */
data class DebtWithContact(
    @Embedded val debt: DebtEntity,
    @Relation(parentColumn = "contactId", entityColumn = "id")
    val contact: ContactEntity,
)
