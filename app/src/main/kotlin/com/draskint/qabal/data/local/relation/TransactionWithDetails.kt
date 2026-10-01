package com.draskint.qabal.data.local.relation

import androidx.room.Embedded
import androidx.room.Junction
import androidx.room.Relation
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CategoryEntity
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.data.local.entity.TransactionTagCrossRef

/** Movimiento con todo lo que referencia, listo para pintarlo en una lista o en el detalle. */
data class TransactionWithDetails(
    @Embedded val transaction: TransactionEntity,
    @Relation(parentColumn = "accountId", entityColumn = "id")
    val account: AccountEntity,
    @Relation(parentColumn = "transferAccountId", entityColumn = "id")
    val transferAccount: AccountEntity?,
    @Relation(parentColumn = "categoryId", entityColumn = "id")
    val category: CategoryEntity?,
    @Relation(parentColumn = "contactId", entityColumn = "id")
    val contact: ContactEntity?,
    @Relation(parentColumn = "debtId", entityColumn = "id")
    val debt: DebtEntity?,
    @Relation(
        parentColumn = "id",
        entityColumn = "id",
        associateBy = Junction(
            value = TransactionTagCrossRef::class,
            parentColumn = "transactionId",
            entityColumn = "tagId",
        ),
    )
    val tags: List<TagEntity>,
)
