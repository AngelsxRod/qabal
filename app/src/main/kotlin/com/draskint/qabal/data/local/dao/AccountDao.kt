package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.relation.AccountWithCard
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {

    @Insert
    suspend fun insert(account: AccountEntity)

    @Update
    suspend fun update(account: AccountEntity)

    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: String): AccountEntity?

    @Transaction
    @Query("SELECT * FROM accounts WHERE id = :id")
    fun observeWithCard(id: String): Flow<AccountWithCard?>

    @Transaction
    @Query("SELECT * FROM accounts WHERE isArchived = :archived ORDER BY name COLLATE NOCASE")
    fun observeAllWithCard(archived: Boolean = false): Flow<List<AccountWithCard>>

    @Query("UPDATE accounts SET isArchived = :archived, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setArchived(id: String, archived: Boolean, updatedAt: Long)
}
