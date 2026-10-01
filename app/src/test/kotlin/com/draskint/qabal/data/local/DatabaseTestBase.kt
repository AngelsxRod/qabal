package com.draskint.qabal.data.local

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.ContactEntity
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.TransactionType
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import org.junit.After
import org.junit.Before
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Base de pruebas con Room en memoria y el mismo callback que usa la app. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
abstract class DatabaseTestBase {

    protected val now: Instant = Instant.parse("2026-10-01T12:00:00Z")
    protected val clock: Clock = Clock.fixed(now, ZoneOffset.UTC)
    protected lateinit var db: AppDatabase

    @Before
    fun openDatabase() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .addCallback(DatabaseCallback(clock))
            .build()
    }

    @After
    fun closeDatabase() = db.close()

    protected fun account(id: String, currency: String = "GTQ", type: AccountType = AccountType.BANK) =
        AccountEntity(id, "Cuenta $id", type, currency, createdAt = now, updatedAt = now)

    protected fun contact(id: String) = ContactEntity(id, "Contacto $id", createdAt = now, updatedAt = now)

    protected fun debt(id: String, contactId: String, principal: Long = 10_000) = DebtEntity(
        id = id, contactId = contactId, direction = DebtDirection.I_OWE, principalMinor = principal,
        currency = "GTQ", description = "Deuda $id", startDate = LocalDate.of(2026, 10, 1),
        createdAt = now, updatedAt = now,
    )

    protected fun tx(
        id: String,
        accountId: String,
        type: TransactionType = TransactionType.EXPENSE,
        amount: Long = 1_000,
        at: Instant = now,
        transferAccountId: String? = null,
        transferAmount: Long? = null,
        debtId: String? = null,
        statementId: String? = null,
    ) = TransactionEntity(
        id = id, accountId = accountId, type = type, amountMinor = amount,
        transferAccountId = transferAccountId, transferAmountMinor = transferAmount,
        debtId = debtId, statementId = statementId, occurredAt = at, createdAt = now, updatedAt = now,
    )
}
