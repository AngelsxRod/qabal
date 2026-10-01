package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.Contact
import com.draskint.qabal.domain.model.ContactInput
import com.draskint.qabal.domain.model.ContactType
import java.time.Clock
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class ContactRepository @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val contacts get() = db.contactDao()

    suspend fun create(input: ContactInput): Contact {
        val name = requireText(input.name, "El nombre")
        val now = clock.instant()
        val entity = ContactEntity(
            id = ids.newId(), name = name, type = input.type, note = input.note, createdAt = now, updatedAt = now,
        )
        contacts.insert(entity)
        return entity.toDomain()
    }

    /** Los argumentos nulos no se tocan. */
    suspend fun update(id: String, name: String? = null, type: ContactType? = null, note: String? = null) {
        val validName = name?.let { requireText(it, "El nombre") }
        db.withTransaction {
            val current = contacts.getById(id) ?: throw NotFoundException("Contacto", id)
            contacts.update(
                current.copy(
                    name = validName ?: current.name, type = type ?: current.type, note = note ?: current.note,
                    updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun setArchived(id: String, archived: Boolean) {
        db.withTransaction {
            contacts.getById(id) ?: throw NotFoundException("Contacto", id)
            contacts.setArchived(id, archived, clock.instant().toEpochMilli())
        }
    }

    suspend fun get(id: String): Contact? = contacts.getById(id)?.toDomain()

    suspend fun list(includeArchived: Boolean = false): List<Contact> =
        contacts.list(includeArchived).map { it.toDomain() }

    fun observe(includeArchived: Boolean = false): Flow<List<Contact>> =
        contacts.observeList(includeArchived).map { rows -> rows.map { it.toDomain() } }
}
