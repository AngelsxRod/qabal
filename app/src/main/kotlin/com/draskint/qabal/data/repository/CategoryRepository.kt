package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.CategoryEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.error.CategoryKindMismatchException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.Category
import com.draskint.qabal.domain.model.CategoryInput
import com.draskint.qabal.domain.model.CategoryKind
import java.time.Clock
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class CategoryRepository @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val categories get() = db.categoryDao()

    /**
     * Una subcategoría debe tener el mismo `kind` que su padre. No se ofrece cambiar el padre, así
     * que no pueden formarse ciclos.
     */
    suspend fun create(input: CategoryInput): Category {
        val name = requireText(input.name, "El nombre")
        return db.withTransaction {
            if (input.parentId != null) {
                val parent = categories.getById(input.parentId) ?: throw NotFoundException("Categoría", input.parentId)
                if (parent.kind != input.kind) {
                    throw CategoryKindMismatchException("La subcategoría debe tener el mismo tipo que su categoría padre")
                }
            }
            val now = clock.instant()
            val entity = CategoryEntity(
                id = ids.newId(), name = name, kind = input.kind, parentId = input.parentId,
                icon = input.icon, colorValue = input.colorValue, createdAt = now, updatedAt = now,
            )
            categories.insert(entity)
            entity.toDomain()
        }
    }

    /** Los argumentos nulos no se tocan. */
    suspend fun update(id: String, name: String? = null, icon: String? = null, colorValue: Long? = null) {
        val validName = name?.let { requireText(it, "El nombre") }
        db.withTransaction {
            val current = categories.getById(id) ?: throw NotFoundException("Categoría", id)
            categories.update(
                current.copy(
                    name = validName ?: current.name, icon = icon ?: current.icon,
                    colorValue = colorValue ?: current.colorValue, updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun setArchived(id: String, archived: Boolean) {
        db.withTransaction {
            categories.getById(id) ?: throw NotFoundException("Categoría", id)
            categories.setArchived(id, archived, clock.instant().toEpochMilli())
        }
    }

    suspend fun get(id: String): Category? = categories.getById(id)?.toDomain()

    suspend fun list(kind: CategoryKind? = null, includeArchived: Boolean = false): List<Category> =
        categories.list(kind, includeArchived).map { it.toDomain() }

    fun observe(kind: CategoryKind? = null, includeArchived: Boolean = false): Flow<List<Category>> =
        categories.observeList(kind, includeArchived).map { rows -> rows.map { it.toDomain() } }
}
