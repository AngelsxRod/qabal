package com.draskint.qabal.data.local

import com.draskint.qabal.data.local.entity.TagEntity
import com.draskint.qabal.domain.model.TransactionType
import java.time.Duration
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TransactionDaoTest : DatabaseTestBase() {

    private val dao get() = db.transactionDao()

    @Before
    fun seed() = runBlocking {
        db.accountDao().insert(account("a"))
        db.accountDao().insert(account("b", currency = "USD"))
    }

    @Test
    fun `los agregados de saldo separan tipos y usan el monto destino`() = runBlocking {
        dao.insert(tx("i", "a", TransactionType.INCOME, 50_000))
        dao.insert(tx("e", "a", TransactionType.EXPENSE, 12_000))
        dao.insert(tx("t", "a", TransactionType.TRANSFER, 7_700, transferAccountId = "b", transferAmount = 1_000))

        assertEquals(50_000L, dao.observeSumByAccountAndType("a", TransactionType.INCOME).first())
        assertEquals(12_000L, dao.observeSumByAccountAndType("a", TransactionType.EXPENSE).first())
        assertEquals(7_700L, dao.observeOutgoingTransfers("a").first())
        assertEquals(1_000L, dao.observeIncomingTransfers("b").first())
        assertEquals(0L, dao.observeIncomingTransfers("a").first())
    }

    @Test
    fun `observeByAccount incluye origen y destino, del mas reciente al mas antiguo`() = runBlocking {
        dao.insert(tx("old", "a", at = now.minus(Duration.ofDays(2))))
        dao.insert(tx("in", "b", TransactionType.TRANSFER, transferAccountId = "a", at = now))
        dao.insert(tx("other", "b"))

        val ids = dao.observeByAccount("a").first().map { it.transaction.id }
        assertEquals(listOf("in", "old"), ids)
    }

    @Test
    fun `replaceTags reemplaza las etiquetas y observeWithDetails las trae`() = runBlocking {
        listOf("x", "y", "z").forEach { db.tagDao().insert(TagEntity(it, "tag-$it", createdAt = now, updatedAt = now)) }
        dao.insert(tx("t", "a"))

        dao.replaceTags("t", setOf("x", "y"))
        dao.replaceTags("t", setOf("y", "z"))

        val details = dao.observeWithDetails("t").first()!!
        assertEquals(setOf("y", "z"), details.tags.map { it.id }.toSet())
        assertEquals("a", details.account.id)
        assertNull(details.transferAccount)
    }

    @Test
    fun `borrar un movimiento borra sus etiquetas`() = runBlocking {
        db.tagDao().insert(TagEntity("x", "tag", createdAt = now, updatedAt = now))
        dao.insert(tx("t", "a"))
        dao.replaceTags("t", setOf("x"))

        dao.deleteById("t")

        assertTrue(db.tagDao().getById("x") != null)
        assertNull(dao.observeWithDetails("t").first())
    }

    @Test
    fun `el nombre de etiqueta es unico sin distinguir mayusculas`() {
        runBlocking { db.tagDao().insert(TagEntity("1", "Viaje", createdAt = now, updatedAt = now)) }
        val error = runCatching {
            runBlocking { db.tagDao().insert(TagEntity("2", "viaje", createdAt = now, updatedAt = now)) }
        }.exceptionOrNull()
        assertTrue(error is android.database.sqlite.SQLiteConstraintException)
        assertEquals("1", runBlocking { db.tagDao().getByName("VIAJE") }?.id)
    }
}
