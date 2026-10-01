package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.draskint.qabal.data.local.entity.TagEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TagDao {

    @Insert
    suspend fun insert(tag: TagEntity)

    @Update
    suspend fun update(tag: TagEntity)

    @Query("SELECT * FROM tags WHERE id = :id")
    suspend fun getById(id: String): TagEntity?

    /** La búsqueda ignora mayúsculas porque la columna usa `COLLATE NOCASE`. */
    @Query("SELECT * FROM tags WHERE name = :name")
    suspend fun getByName(name: String): TagEntity?

    @Query("SELECT * FROM tags WHERE isArchived = :archived ORDER BY name")
    fun observeAll(archived: Boolean = false): Flow<List<TagEntity>>

    @Query("SELECT * FROM tags WHERE :includeArchived OR isArchived = 0 ORDER BY name")
    suspend fun list(includeArchived: Boolean): List<TagEntity>

    @Query("SELECT * FROM tags WHERE :includeArchived OR isArchived = 0 ORDER BY name")
    fun observeList(includeArchived: Boolean): Flow<List<TagEntity>>

    @Query("UPDATE tags SET isArchived = :archived, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setArchived(id: String, archived: Boolean, updatedAt: Long)
}
