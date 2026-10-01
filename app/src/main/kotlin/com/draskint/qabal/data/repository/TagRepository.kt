package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.error.DuplicateNameException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.Tag
import java.time.Clock
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class TagRepository @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val tags get() = db.tagDao()

    /** El nombre es único sin distinguir mayúsculas (igual que el índice de la tabla). */
    suspend fun create(name: String, colorValue: Long? = null): Tag {
        val clean = requireText(name, "El nombre", max = 40)
        return db.withTransaction {
            ensureUnique(clean)
            val now = clock.instant()
            val entity = TagEntity(id = ids.newId(), name = clean, colorValue = colorValue, createdAt = now, updatedAt = now)
            tags.insert(entity)
            entity.toDomain()
        }
    }

    /** Los argumentos nulos no se tocan. */
    suspend fun update(id: String, name: String? = null, colorValue: Long? = null) {
        val clean = name?.let { requireText(it, "El nombre", max = 40) }
        db.withTransaction {
            val current = tags.getById(id) ?: throw NotFoundException("Etiqueta", id)
            if (clean != null) ensureUnique(clean, exceptId = id)
            tags.update(
                current.copy(
                    name = clean ?: current.name, colorValue = colorValue ?: current.colorValue,
                    updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun setArchived(id: String, archived: Boolean) {
        db.withTransaction {
            tags.getById(id) ?: throw NotFoundException("Etiqueta", id)
            tags.setArchived(id, archived, clock.instant().toEpochMilli())
        }
    }

    suspend fun get(id: String): Tag? = tags.getById(id)?.toDomain()

    suspend fun list(includeArchived: Boolean = false): List<Tag> = tags.list(includeArchived).map { it.toDomain() }

    fun observe(includeArchived: Boolean = false): Flow<List<Tag>> =
        tags.observeList(includeArchived).map { rows -> rows.map { it.toDomain() } }

    private suspend fun ensureUnique(name: String, exceptId: String? = null) {
        val existing = tags.getByName(name)
        if (existing != null && existing.id != exceptId) throw DuplicateNameException(name)
    }
}
