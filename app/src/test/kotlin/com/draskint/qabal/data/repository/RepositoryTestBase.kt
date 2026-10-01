package com.draskint.qabal.data.repository

import com.draskint.qabal.data.local.DatabaseTestBase
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.model.Account
import com.draskint.qabal.domain.model.AccountInput
import com.draskint.qabal.domain.model.AccountType
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertThrows
import org.junit.Before

/** Repositorios reales sobre Room en memoria, con ids secuenciales (`id-1`, `id-2`...). */
abstract class RepositoryTestBase : DatabaseTestBase() {

    private var counter = 0
    protected val ids = IdGenerator { "id-${++counter}" }

    protected lateinit var accounts: AccountRepository
    protected lateinit var ledger: LedgerQueries
    protected lateinit var transactions: TransactionRepository

    @Before
    fun createRepositories() {
        accounts = AccountRepository(db, clock, ids)
        ledger = LedgerQueries(db, clock)
        transactions = TransactionRepository(db, clock, ids, ledger)
    }

    protected fun newAccount(
        name: String = "Cuenta",
        currency: String = "GTQ",
        type: AccountType = AccountType.BANK,
        initial: Long = 0,
    ): Account = runBlocking { accounts.create(AccountInput(name, type, currency, initial)) }

    /** Comprueba que [block] lanza [T] y devuelve la excepción. */
    protected inline fun <reified T : Throwable> assertFails(crossinline block: suspend () -> Unit): T =
        assertThrows(T::class.java) { runBlocking { block() } }
}
