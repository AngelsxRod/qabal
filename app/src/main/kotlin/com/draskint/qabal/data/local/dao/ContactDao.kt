package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.draskint.qabal.data.local.entity.ContactEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ContactDao {

    @Insert
    suspend fun insert(contact: ContactEntity)

    @Update
    suspend fun update(contact: ContactEntity)

    @Query("SELECT * FROM contacts WHERE id = :id")
    suspend fun getById(id: String): ContactEntity?

    @Query("SELECT * FROM contacts WHERE isArchived = :archived ORDER BY name COLLATE NOCASE")
    fun observeAll(archived: Boolean = false): Flow<List<ContactEntity>>

    @Query("SELECT * FROM contacts WHERE :includeArchived OR isArchived = 0 ORDER BY name COLLATE NOCASE")
    suspend fun list(includeArchived: Boolean): List<ContactEntity>

    @Query("SELECT * FROM contacts WHERE :includeArchived OR isArchived = 0 ORDER BY name COLLATE NOCASE")
    fun observeList(includeArchived: Boolean): Flow<List<ContactEntity>>

    @Query("UPDATE contacts SET isArchived = :archived, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setArchived(id: String, archived: Boolean, updatedAt: Long)
}
