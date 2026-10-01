package com.draskint.qabal.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.draskint.qabal.data.local.converter.Converters
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CategoryEntity
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.data.local.entity.TransactionTagCrossRef

@Database(
    entities = [
        AccountEntity::class,
        CategoryEntity::class,
        ContactEntity::class,
        TagEntity::class,
        CreditCardDetailsEntity::class,
        CreditCardStatementEntity::class,
        DebtEntity::class,
        TransactionEntity::class,
        TransactionTagCrossRef::class,
    ],
    version = 1,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    companion object {
        const val NAME = "qabal.db"
    }
}
