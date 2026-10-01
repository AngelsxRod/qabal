package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.TransactionEntity
import com.draskint.qabal.data.local.entity.TransactionTagCrossRef
import com.draskint.qabal.data.local.relation.CycleSumsRow
import com.draskint.qabal.data.local.relation.StatementPaidRow
import com.draskint.qabal.data.local.relation.TransactionWithDetails
import com.draskint.qabal.domain.model.TransactionType
import kotlinx.coroutines.flow.Flow

@Dao
interface TransactionDao {

    @Insert
    suspend fun insert(transaction: TransactionEntity)

    @Update
    suspend fun update(transaction: TransactionEntity)

    @Query("DELETE FROM transactions WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT * FROM transactions WHERE id = :id")
    suspend fun getById(id: String): TransactionEntity?

    @Transaction
    @Query("SELECT * FROM transactions WHERE id = :id")
    fun observeWithDetails(id: String): Flow<TransactionWithDetails?>

    @Transaction
    @Query("SELECT * FROM transactions ORDER BY occurredAt DESC, createdAt DESC")
    fun observeAllWithDetails(): Flow<List<TransactionWithDetails>>

    /** Movimientos donde la cuenta es origen o destino, del más reciente al más antiguo. */
    @Transaction
    @Query(
        "SELECT * FROM transactions WHERE accountId = :accountId OR transferAccountId = :accountId " +
            "ORDER BY occurredAt DESC, createdAt DESC",
    )
    fun observeByAccount(accountId: String): Flow<List<TransactionWithDetails>>

    @Transaction
    @Query("SELECT * FROM transactions WHERE debtId = :debtId ORDER BY occurredAt DESC, createdAt DESC")
    fun observeByDebt(debtId: String): Flow<List<TransactionWithDetails>>

    @Transaction
    @Query("SELECT * FROM transactions WHERE statementId = :statementId ORDER BY occurredAt DESC")
    fun observeByStatement(statementId: String): Flow<List<TransactionWithDetails>>

    // --- Agregados para saldos (la composición del saldo vive en el repositorio) ---

    /** Suma de ingresos o gastos de la cuenta, sin contar transferencias. */
    @Query("SELECT COALESCE(SUM(amountMinor), 0) FROM transactions WHERE accountId = :accountId AND type = :type")
    fun observeSumByAccountAndType(accountId: String, type: TransactionType): Flow<Long>

    /** Lo que sale de la cuenta por transferencias (en la moneda de la cuenta origen). */
    @Query("SELECT COALESCE(SUM(amountMinor), 0) FROM transactions WHERE accountId = :accountId AND type = 'TRANSFER'")
    fun observeOutgoingTransfers(accountId: String): Flow<Long>

    /** Lo que entra a la cuenta por transferencias: usa el monto destino si las monedas difieren. */
    @Query(
        "SELECT COALESCE(SUM(COALESCE(transferAmountMinor, amountMinor)), 0) FROM transactions " +
            "WHERE transferAccountId = :accountId",
    )
    fun observeIncomingTransfers(accountId: String): Flow<Long>

    /** Suma por tipo de los movimientos de una deuda; el repositorio decide cuáles son abonos. */
    @Query("SELECT COALESCE(SUM(amountMinor), 0) FROM transactions WHERE debtId = :debtId AND type = :type")
    fun observeSumByDebtAndType(debtId: String, type: TransactionType): Flow<Long>

    // --- Consultas de tarjetas ---

    /**
     * Saldo de la cuenta con los movimientos anteriores a [before] (epoch ms; `Long.MAX_VALUE` = todos).
     * Misma composición que `AccountDao.observeBalances`. Nulo si la cuenta no existe.
     */
    @Query(
        "SELECT a.initialBalanceMinor " +
            "+ COALESCE((SELECT SUM(CASE t.type WHEN 'INCOME' THEN t.amountMinor ELSE -t.amountMinor END) " +
            "FROM transactions t WHERE t.accountId = a.id AND t.occurredAt < :before), 0) " +
            "+ COALESCE((SELECT SUM(COALESCE(t.transferAmountMinor, t.amountMinor)) " +
            "FROM transactions t WHERE t.transferAccountId = a.id AND t.occurredAt < :before), 0) " +
            "FROM accounts a WHERE a.id = :accountId",
    )
    suspend fun getBalanceBefore(accountId: String, before: Long): Long?

    /**
     * Movimientos de la tarjeta con `[start, end)` en epoch ms. [interestId] y [refundsId] son las
     * categorías del sistema «Intereses y cargos» y «Devoluciones».
     */
    @Query(
        "SELECT " +
            "COALESCE(SUM(CASE WHEN t.accountId = :cardId AND t.type = 'EXPENSE' " +
            "AND COALESCE(t.categoryId, '') <> :interestId THEN t.amountMinor END), 0) AS purchases, " +
            "COALESCE(SUM(CASE WHEN t.accountId = :cardId AND t.type = 'EXPENSE' " +
            "AND t.categoryId = :interestId THEN t.amountMinor END), 0) AS interest, " +
            "COALESCE(SUM(CASE WHEN t.accountId = :cardId AND t.type = 'TRANSFER' " +
            "THEN t.amountMinor END), 0) AS advances, " +
            "COALESCE(SUM(CASE WHEN t.accountId = :cardId AND t.type = 'INCOME' " +
            "AND t.categoryId = :refundsId THEN t.amountMinor END), 0) AS refunds, " +
            "COALESCE(SUM(CASE WHEN t.accountId = :cardId AND t.type = 'INCOME' " +
            "AND COALESCE(t.categoryId, '') <> :refundsId THEN t.amountMinor END), 0) AS otherCredits, " +
            "COALESCE(SUM(CASE WHEN t.transferAccountId = :cardId " +
            "THEN COALESCE(t.transferAmountMinor, t.amountMinor) END), 0) AS payments " +
            "FROM transactions t WHERE (t.accountId = :cardId OR t.transferAccountId = :cardId) " +
            "AND t.occurredAt >= :start AND t.occurredAt < :end",
    )
    suspend fun getCycleSums(cardId: String, interestId: String, refundsId: String, start: Long, end: Long): CycleSumsRow

    /** Suma de los pagos vinculados (`statementId`) a cada estado de cuenta. */
    @Query(
        "SELECT statementId, SUM(COALESCE(transferAmountMinor, amountMinor)) AS paidMinor " +
            "FROM transactions WHERE statementId IN (:statementIds) GROUP BY statementId",
    )
    suspend fun getPaidByStatement(statementIds: List<String>): List<StatementPaidRow>

    // --- Etiquetas ---

    @Insert
    suspend fun insertTagRefs(refs: List<TransactionTagCrossRef>)

    @Query("DELETE FROM transaction_tags WHERE transactionId = :transactionId")
    suspend fun deleteTagRefs(transactionId: String)

    /** Reemplaza las etiquetas del movimiento de forma atómica. */
    @Transaction
    suspend fun replaceTags(transactionId: String, tagIds: Set<String>) {
        deleteTagRefs(transactionId)
        if (tagIds.isNotEmpty()) {
            insertTagRefs(tagIds.map { TransactionTagCrossRef(transactionId, it) })
        }
    }
}
