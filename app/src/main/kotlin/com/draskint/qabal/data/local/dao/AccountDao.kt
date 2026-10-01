package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.relation.AccountWithCard
import com.draskint.qabal.data.local.relation.BalanceRow
import kotlinx.coroutines.flow.Flow

private const val BALANCE_SQL =
    "SELECT a.id AS accountId, a.initialBalanceMinor " +
        "+ COALESCE((SELECT SUM(CASE t.type WHEN 'INCOME' THEN t.amountMinor ELSE -t.amountMinor END) " +
        "FROM transactions t WHERE t.accountId = a.id), 0) " +
        "+ COALESCE((SELECT SUM(COALESCE(t.transferAmountMinor, t.amountMinor)) " +
        "FROM transactions t WHERE t.transferAccountId = a.id), 0) AS balanceMinor FROM accounts a"

@Dao
interface AccountDao {

    @Insert
    suspend fun insert(account: AccountEntity)

    @Update
    suspend fun update(account: AccountEntity)

    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: String): AccountEntity?

    @Transaction
    @Query("SELECT * FROM accounts WHERE id = :id")
    fun observeWithCard(id: String): Flow<AccountWithCard?>

    @Transaction
    @Query("SELECT * FROM accounts WHERE isArchived = :archived ORDER BY name COLLATE NOCASE")
    fun observeAllWithCard(archived: Boolean = false): Flow<List<AccountWithCard>>

    @Query("UPDATE accounts SET isArchived = :archived, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setArchived(id: String, archived: Boolean, updatedAt: Long)

    @Query("SELECT * FROM accounts WHERE isArchived = :archived ORDER BY name COLLATE NOCASE")
    suspend fun getAll(archived: Boolean = false): List<AccountEntity>

    @Query("SELECT * FROM accounts ORDER BY name COLLATE NOCASE")
    suspend fun getAllIncludingArchived(): List<AccountEntity>

    /**
     * Saldo por cuenta: saldo inicial + ingresos - gastos - transferencias salientes + transferencias
     * entrantes (con el monto destino si las monedas difieren).
     */
    @Query(BALANCE_SQL)
    fun observeBalances(): Flow<List<BalanceRow>>

    @Query("$BALANCE_SQL WHERE a.id = :id")
    suspend fun getBalance(id: String): BalanceRow?
}
