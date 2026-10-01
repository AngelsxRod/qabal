package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.CreditCardDetailsEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity
import com.draskint.qabal.data.local.relation.StatementWithCard
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow

@Dao
interface CreditCardDao {

    @Insert
    suspend fun insertDetails(details: CreditCardDetailsEntity)

    @Update
    suspend fun updateDetails(details: CreditCardDetailsEntity)

    @Query("SELECT * FROM credit_card_details WHERE accountId = :accountId")
    suspend fun getDetails(accountId: String): CreditCardDetailsEntity?

    @Insert
    suspend fun insertStatement(statement: CreditCardStatementEntity)

    @Update
    suspend fun updateStatement(statement: CreditCardStatementEntity)

    @Query("SELECT * FROM credit_card_statements WHERE id = :id")
    suspend fun getStatement(id: String): CreditCardStatementEntity?

    @Query(
        "SELECT * FROM credit_card_statements WHERE accountId = :accountId AND isArchived = :archived " +
            "ORDER BY dueDate DESC",
    )
    fun observeStatements(accountId: String, archived: Boolean = false): Flow<List<CreditCardStatementEntity>>

    @Query("SELECT * FROM credit_card_statements WHERE isArchived = 0 ORDER BY dueDate")
    fun observeAllActiveStatements(): Flow<List<CreditCardStatementEntity>>

    /** Estados de cuenta de la tarjeta, del corte más reciente al más antiguo. */
    @Query(
        "SELECT * FROM credit_card_statements WHERE accountId = :accountId AND (:includeArchived OR isArchived = 0) " +
            "ORDER BY closingDate DESC",
    )
    suspend fun getStatements(accountId: String, includeArchived: Boolean): List<CreditCardStatementEntity>

    @Query("SELECT * FROM credit_card_statements WHERE accountId = :accountId AND closingDate = :closingDate")
    suspend fun getStatementByClosing(accountId: String, closingDate: LocalDate): CreditCardStatementEntity?

    /** Un estado de cuenta activo cuyo periodo se solapa con `[start, closing]`. */
    @Query(
        "SELECT * FROM credit_card_statements WHERE accountId = :accountId AND isArchived = 0 " +
            "AND closingDate >= :start AND periodStart <= :closing LIMIT 1",
    )
    suspend fun findOverlappingStatement(accountId: String, start: LocalDate, closing: LocalDate): CreditCardStatementEntity?

    /** Último estado de cuenta activo con corte anterior a [before]. */
    @Query(
        "SELECT * FROM credit_card_statements WHERE accountId = :accountId AND isArchived = 0 " +
            "AND closingDate < :before ORDER BY closingDate DESC LIMIT 1",
    )
    suspend fun getLastStatementBefore(accountId: String, before: LocalDate): CreditCardStatementEntity?

    /** Estados de cuenta activos de tarjetas activas, de la fecha de pago más próxima a la más lejana. */
    @Transaction
    @Query(
        "SELECT s.* FROM credit_card_statements s JOIN accounts a ON a.id = s.accountId " +
            "WHERE s.isArchived = 0 AND a.isArchived = 0 ORDER BY s.dueDate, s.closingDate",
    )
    suspend fun getActiveStatementsWithCard(): List<StatementWithCard>

    /** Estados de cuenta activos de una tarjeta, por fecha de pago ascendente. */
    @Query("SELECT * FROM credit_card_statements WHERE accountId = :accountId AND isArchived = 0 ORDER BY dueDate")
    suspend fun getActiveStatementsByDue(accountId: String): List<CreditCardStatementEntity>
}
