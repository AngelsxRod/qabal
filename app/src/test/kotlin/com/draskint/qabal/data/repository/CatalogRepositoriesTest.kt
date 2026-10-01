package com.draskint.qabal.data.repository

import com.draskint.qabal.domain.error.CategoryKindMismatchException
import com.draskint.qabal.domain.error.DuplicateNameException
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.CategoryInput
import com.draskint.qabal.domain.model.CategoryKind
import com.draskint.qabal.domain.model.ContactInput
import com.draskint.qabal.domain.model.ContactType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CatalogRepositoriesTest : RepositoryTestBase() {

    private lateinit var categories: CategoryRepository
    private lateinit var contacts: ContactRepository
    private lateinit var tags: TagRepository

    @Before
    fun createCatalogs() {
        categories = CategoryRepository(db, clock, ids)
        contacts = ContactRepository(db, clock, ids)
        tags = TagRepository(db, clock, ids)
    }

    // --- Categorías ---

    @Test
    fun `crea una categoria y una subcategoria del mismo tipo`() = runBlocking<Unit> {
        val parent = categories.create(CategoryInput("  Mascotas ", CategoryKind.EXPENSE, icon = "paw"))
        assertEquals("Mascotas", parent.name)
        assertEquals("paw", parent.icon)
        val child = categories.create(CategoryInput("Veterinario", CategoryKind.EXPENSE, parentId = parent.id))
        assertEquals(parent.id, categories.get(child.id)?.parentId)
    }

    @Test
    fun `rechaza una subcategoria de otro tipo o con padre inexistente`() {
        val parent = runBlocking { categories.create(CategoryInput("Sueldo extra", CategoryKind.INCOME)) }
        assertFails<CategoryKindMismatchException> {
            categories.create(CategoryInput("Gasto", CategoryKind.EXPENSE, parentId = parent.id))
        }
        assertFails<NotFoundException> {
            categories.create(CategoryInput("Huérfana", CategoryKind.INCOME, parentId = "nope"))
        }
        assertFails<InvalidInputException> { categories.create(CategoryInput("  ", CategoryKind.INCOME)) }
    }

    @Test
    fun `actualiza solo los campos indicados y archiva`() = runBlocking<Unit> {
        val c = categories.create(CategoryInput("Ocio", CategoryKind.EXPENSE, icon = "game"))
        categories.update(c.id, name = " Diversión ")
        val updated = categories.get(c.id)!!
        assertEquals("Diversión", updated.name)
        assertEquals("game", updated.icon)

        categories.setArchived(c.id, true)
        assertTrue(categories.get(c.id)!!.isArchived)
        assertFalse(categories.list().any { it.id == c.id })
        assertTrue(categories.list(includeArchived = true).any { it.id == c.id })
        assertFails<NotFoundException> { categories.update("nope", name = "x") }
        assertFails<NotFoundException> { categories.setArchived("nope", true) }
    }

    @Test
    fun `filtra las categorias por tipo e incluye las del seed`() = runBlocking<Unit> {
        val expense = categories.list(CategoryKind.EXPENSE)
        val income = categories.list(CategoryKind.INCOME)
        assertTrue(expense.isNotEmpty() && income.isNotEmpty())
        assertTrue(expense.all { it.kind == CategoryKind.EXPENSE })
        assertEquals(expense.size + income.size, categories.list().size)
        assertEquals(expense.map { it.id }, categories.observe(CategoryKind.EXPENSE).first().map { it.id })
    }

    // --- Contactos ---

    @Test
    fun `crea, edita y archiva contactos`() = runBlocking<Unit> {
        val c = contacts.create(ContactInput(" Ana ", ContactType.PERSON, "amiga"))
        assertEquals("Ana", c.name)
        contacts.update(c.id, note = "compañera")
        val updated = contacts.get(c.id)!!
        assertEquals(ContactType.PERSON, updated.type)
        assertEquals("compañera", updated.note)

        contacts.setArchived(c.id, true)
        assertTrue(contacts.list().isEmpty())
        assertEquals(listOf(c.id), contacts.observe(includeArchived = true).first().map { it.id })
        assertFails<InvalidInputException> { contacts.create(ContactInput("")) }
        assertFails<NotFoundException> { contacts.update("nope", name = "x") }
        assertNull(contacts.get("nope"))
    }

    @Test
    fun `lista los contactos ordenados por nombre sin distinguir mayusculas`() = runBlocking<Unit> {
        contacts.create(ContactInput("beto"))
        contacts.create(ContactInput("Carlos"))
        contacts.create(ContactInput("Ana"))
        assertEquals(listOf("Ana", "beto", "Carlos"), contacts.list().map { it.name })
    }

    // --- Etiquetas ---

    @Test
    fun `el nombre de la etiqueta es unico sin distinguir mayusculas`() = runBlocking<Unit> {
        val t = tags.create(" Viaje ", colorValue = 0xFF112233)
        assertEquals("Viaje", t.name)
        assertFails<DuplicateNameException> { tags.create("VIAJE") }

        val other = tags.create("Trabajo")
        assertFails<DuplicateNameException> { tags.update(other.id, name = "viaje") }
        tags.update(t.id, name = "VIAJE") // renombrarse a sí misma sí se permite
        assertEquals("VIAJE", tags.get(t.id)!!.name)
        assertEquals(0xFF112233, tags.get(t.id)!!.colorValue)
    }

    @Test
    fun `valida y archiva etiquetas`() = runBlocking<Unit> {
        assertFails<InvalidInputException> { tags.create("x".repeat(41)) }
        val t = tags.create("Casa")
        tags.setArchived(t.id, true)
        assertTrue(tags.list().isEmpty())
        assertEquals(1, tags.observe(includeArchived = true).first().size)
        assertFails<NotFoundException> { tags.setArchived("nope", true) }
        assertFails<NotFoundException> { tags.update("nope", name = "x") }
    }
}
