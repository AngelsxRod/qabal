package com.draskint.qabal.data.repository

import androidx.room.withTransaction
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.mapper.toDomain
import com.draskint.qabal.data.mapper.toSettings
import com.draskint.qabal.di.IdGenerator
import com.draskint.qabal.domain.error.InvalidInputException
import com.draskint.qabal.domain.error.NotACreditCardException
import com.draskint.qabal.domain.error.NotFoundException
import com.draskint.qabal.domain.model.Account
import com.draskint.qabal.domain.model.AccountBalance
import com.draskint.qabal.domain.model.AccountInput
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CreditCardSettings
import java.time.Clock
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class AccountRepository @Inject constructor(
    private val db: AppDatabase,
    private val clock: Clock,
    private val ids: IdGenerator,
) {
    private val accounts get() = db.accountDao()
    private val cards get() = db.creditCardDao()

    /**
     * Crea una cuenta. Una cuenta `CREDIT_CARD` exige [card] (y se crea junto con sus detalles en una
     * sola transacción); las demás lo prohíben.
     */
    suspend fun create(input: AccountInput, card: CreditCardSettings? = null): Account {
        val name = requireText(input.name, "El nombre")
        val currency = normalizeCurrency(input.currency)
        val isCard = input.type == AccountType.CREDIT_CARD
        if (isCard && card == null) {
            throw InvalidInputException("Una tarjeta de crédito requiere sus datos de tarjeta")
        }
        if (!isCard && card != null) {
            throw InvalidInputException("Solo las tarjetas de crédito llevan datos de tarjeta")
        }
        if (card != null) validateCardSettings(card)

        return db.withTransaction {
            val now = clock.instant()
            val entity = AccountEntity(
                id = ids.newId(), name = name, type = input.type, currency = currency,
                initialBalanceMinor = input.initialBalanceMinor, createdAt = now, updatedAt = now,
            )
            accounts.insert(entity)
            if (card != null) {
                cards.insertDetails(
                    CreditCardDetailsEntity(
                        accountId = entity.id, creditLimitMinor = card.creditLimitMinor,
                        statementDay = card.statementDay, dueDay = card.dueDay,
                        minPaymentBp = card.minPaymentBp, createdAt = now, updatedAt = now,
                    ),
                )
            }
            entity.toDomain()
        }
    }

    /** `type` y `currency` no se pueden cambiar; los argumentos nulos no se tocan. */
    suspend fun update(
        id: String,
        name: String? = null,
        isArchived: Boolean? = null,
        initialBalanceMinor: Long? = null,
    ) {
        val validName = name?.let { requireText(it, "El nombre") }
        db.withTransaction {
            val current = accounts.getById(id) ?: throw NotFoundException("Cuenta", id)
            accounts.update(
                current.copy(
                    name = validName ?: current.name,
                    isArchived = isArchived ?: current.isArchived,
                    initialBalanceMinor = initialBalanceMinor ?: current.initialBalanceMinor,
                    updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun updateCardSettings(accountId: String, settings: CreditCardSettings) {
        validateCardSettings(settings)
        db.withTransaction {
            val account = accounts.getById(accountId) ?: throw NotFoundException("Cuenta", accountId)
            if (account.type != AccountType.CREDIT_CARD) throw NotACreditCardException(accountId)
            val details = cards.getDetails(accountId) ?: throw NotFoundException("Detalles de tarjeta", accountId)
            cards.updateDetails(
                details.copy(
                    creditLimitMinor = settings.creditLimitMinor, statementDay = settings.statementDay,
                    dueDay = settings.dueDay, minPaymentBp = settings.minPaymentBp, updatedAt = clock.instant(),
                ),
            )
        }
    }

    suspend fun get(id: String): Account? = accounts.getById(id)?.toDomain()

    suspend fun cardSettings(accountId: String): CreditCardSettings? = cards.getDetails(accountId)?.toSettings()

    suspend fun list(includeArchived: Boolean = false): List<Account> =
        (if (includeArchived) accounts.getAllIncludingArchived() else accounts.getAll()).map { it.toDomain() }

    suspend fun balance(id: String): AccountBalance {
        val account = get(id) ?: throw NotFoundException("Cuenta", id)
        return AccountBalance(account, accounts.getBalance(id)?.balanceMinor ?: 0)
    }

    /** Cuentas con su saldo; se reemite al cambiar cuentas o movimientos. */
    fun observeBalances(includeArchived: Boolean = false): Flow<List<AccountBalance>> =
        accounts.observeBalances().map { rows ->
            val balances = rows.associate { it.accountId to it.balanceMinor }
            list(includeArchived).map { AccountBalance(it, balances[it.id] ?: 0) }
        }
}
