package com.draskint.qabal.data.local

import com.draskint.qabal.data.local.seed.CategorySeed
import com.draskint.qabal.data.local.seed.INTEREST_FEES_CATEGORY_ID
import com.draskint.qabal.data.local.seed.REFUNDS_CATEGORY_ID
import com.draskint.qabal.domain.model.CategoryKind
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class CategorySeedTest : DatabaseTestBase() {

    private fun count(): Int =
        db.openHelper.writableDatabase.query("SELECT COUNT(*) FROM categories").use { it.moveToFirst(); it.getInt(0) }

    @Test
    fun `al crear la base siembra las categorias por defecto y las del sistema`() = runBlocking {
        assertEquals(20, count())
        assertNotNull(db.categoryDao().getById(INTEREST_FEES_CATEGORY_ID))
        assertNotNull(db.categoryDao().getById(REFUNDS_CATEGORY_ID))
    }

    @Test
    fun `el seed es idempotente y no pisa los cambios del usuario`() = runBlocking {
        val renamed = db.categoryDao().getById(REFUNDS_CATEGORY_ID)!!.copy(name = "Reembolsos")
        db.categoryDao().update(renamed)

        val sqlite = db.openHelper.writableDatabase
        CategorySeed.seedDefaults(sqlite, now.toEpochMilli())
        CategorySeed.ensureSystem(sqlite, now.toEpochMilli())

        assertEquals(20, count())
        assertEquals("Reembolsos", db.categoryDao().getById(REFUNDS_CATEGORY_ID)!!.name)
    }

    @Test
    fun `el arbol separa ingresos y gastos`() = runBlocking {
        val incomes = db.categoryDao().observeTree(CategoryKind.INCOME).first()
        assertEquals(7, incomes.size)
        assertEquals(13, db.categoryDao().observeTree(CategoryKind.EXPENSE).first().size)
    }
}
