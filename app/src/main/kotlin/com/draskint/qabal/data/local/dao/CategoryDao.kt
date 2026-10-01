package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.CategoryEntity
import com.draskint.qabal.data.local.relation.CategoryWithChildren
import com.draskint.qabal.domain.model.CategoryKind
import kotlinx.coroutines.flow.Flow

@Dao
interface CategoryDao {

    @Insert
    suspend fun insert(category: CategoryEntity)

    /** Para el seed: ignora las categorías que ya existen. */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAllIgnoring(categories: List<CategoryEntity>)

    @Update
    suspend fun update(category: CategoryEntity)

    @Query("SELECT * FROM categories WHERE id = :id")
    suspend fun getById(id: String): CategoryEntity?

    /** Todas las categorías (raíz y subcategorías); [kind] nulo = de cualquier tipo. */
    @Query(
        "SELECT * FROM categories WHERE (:kind IS NULL OR kind = :kind) AND (:includeArchived OR isArchived = 0) " +
            "ORDER BY name COLLATE NOCASE",
    )
    suspend fun list(kind: CategoryKind?, includeArchived: Boolean): List<CategoryEntity>

    @Query(
        "SELECT * FROM categories WHERE (:kind IS NULL OR kind = :kind) AND (:includeArchived OR isArchived = 0) " +
            "ORDER BY name COLLATE NOCASE",
    )
    fun observeList(kind: CategoryKind?, includeArchived: Boolean): Flow<List<CategoryEntity>>

    /** Categorías raíz de un tipo, cada una con sus subcategorías. */
    @Transaction
    @Query(
        "SELECT * FROM categories WHERE parentId IS NULL AND kind = :kind AND isArchived = :archived " +
            "ORDER BY name COLLATE NOCASE",
    )
    fun observeTree(kind: CategoryKind, archived: Boolean = false): Flow<List<CategoryWithChildren>>

    @Query("UPDATE categories SET isArchived = :archived, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setArchived(id: String, archived: Boolean, updatedAt: Long)
}
