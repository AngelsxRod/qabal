package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.RawQuery
import androidx.sqlite.db.SupportSQLiteQuery
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.data.local.entity.TransactionTagCrossRef
import kotlinx.coroutines.flow.Flow

/** Listados con filtros dinámicos; la consulta la arma `TransactionRepository`. */
@Dao
interface TransactionQueryDao {

    @RawQuery
    suspend fun query(query: SupportSQLiteQuery): List<TransactionEntity>

    @RawQuery(observedEntities = [TransactionEntity::class, TransactionTagCrossRef::class])
    fun observe(query: SupportSQLiteQuery): Flow<List<TransactionEntity>>
}
