package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.relation.DebtWithContact
import com.draskint.qabal.domain.model.DebtStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface DebtDao {

    @Insert
    suspend fun insert(debt: DebtEntity)

    @Update
    suspend fun update(debt: DebtEntity)

    @Query("SELECT * FROM debts WHERE id = :id")
    suspend fun getById(id: String): DebtEntity?

    @Transaction
    @Query("SELECT * FROM debts WHERE id = :id")
    fun observeWithContact(id: String): Flow<DebtWithContact?>

    @Transaction
    @Query("SELECT * FROM debts WHERE isArchived = :archived ORDER BY startDate DESC")
    fun observeAllWithContact(archived: Boolean = false): Flow<List<DebtWithContact>>

    @Transaction
    @Query("SELECT * FROM debts WHERE status = :status AND isArchived = 0 ORDER BY dueDate IS NULL, dueDate")
    fun observeByStatus(status: DebtStatus): Flow<List<DebtWithContact>>

    @Query("UPDATE debts SET status = :status, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setStatus(id: String, status: DebtStatus, updatedAt: Long)
}
