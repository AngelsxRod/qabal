package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CreditCardDao {

    @Insert
    suspend fun insertDetails(details: CreditCardDetailsEntity)

    @Update
    suspend fun updateDetails(details: CreditCardDetailsEntity)

    @Query("SELECT * FROM credit_card_details WHERE accountId = :accountId")
    suspend fun getDetails(accountId: String): CreditCardDetailsEntity?

    @Insert
    suspend fun insertStatement(statement: CreditCardStatementEntity)

    @Update
    suspend fun updateStatement(statement: CreditCardStatementEntity)

    @Query("SELECT * FROM credit_card_statements WHERE id = :id")
    suspend fun getStatement(id: String): CreditCardStatementEntity?

    @Query(
        "SELECT * FROM credit_card_statements WHERE accountId = :accountId AND isArchived = :archived " +
            "ORDER BY dueDate DESC",
    )
    fun observeStatements(accountId: String, archived: Boolean = false): Flow<List<CreditCardStatementEntity>>

    @Query("SELECT * FROM credit_card_statements WHERE isArchived = 0 ORDER BY dueDate")
    fun observeAllActiveStatements(): Flow<List<CreditCardStatementEntity>>
}
