package com.draskint.qabal.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.draskint.qabal.data.local.entity.DebtEntity
import com.draskint.qabal.data.local.relation.DebtPaidRow
import com.draskint.qabal.data.local.relation.DebtWithContact
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtStatus
import kotlinx.coroutines.flow.Flow

private const val DEBT_PAID_SQL =
    "SELECT d.id AS debtId, COALESCE(SUM(t.amountMinor), 0) AS paidMinor FROM debts d " +
        "LEFT JOIN transactions t ON t.debtId = d.id " +
        "AND t.type = CASE d.direction WHEN 'OWED_TO_ME' THEN 'INCOME' ELSE 'EXPENSE' END " +
        "GROUP BY d.id"

@Dao
interface DebtDao {

    @Insert
    suspend fun insert(debt: DebtEntity)

    @Update
    suspend fun update(debt: DebtEntity)

    @Query("SELECT * FROM debts WHERE id = :id")
    suspend fun getById(id: String): DebtEntity?

    @Transaction
    @Query("SELECT * FROM debts WHERE id = :id")
    fun observeWithContact(id: String): Flow<DebtWithContact?>

    @Transaction
    @Query("SELECT * FROM debts WHERE isArchived = :archived ORDER BY startDate DESC")
    fun observeAllWithContact(archived: Boolean = false): Flow<List<DebtWithContact>>

    @Transaction
    @Query("SELECT * FROM debts WHERE status = :status AND isArchived = 0 ORDER BY dueDate IS NULL, dueDate")
    fun observeByStatus(status: DebtStatus): Flow<List<DebtWithContact>>

    /** Deudas filtradas (un filtro nulo no se aplica), de la más reciente a la más antigua. */
    @Query(
        "SELECT * FROM debts WHERE (:direction IS NULL OR direction = :direction) " +
            "AND (:status IS NULL OR status = :status) AND (:includeArchived OR isArchived = 0) " +
            "ORDER BY startDate DESC, createdAt DESC",
    )
    suspend fun list(direction: DebtDirection?, status: DebtStatus?, includeArchived: Boolean): List<DebtEntity>

    @Query(
        "SELECT * FROM debts WHERE (:direction IS NULL OR direction = :direction) " +
            "AND (:status IS NULL OR status = :status) AND (:includeArchived OR isArchived = 0) " +
            "ORDER BY startDate DESC, createdAt DESC",
    )
    fun observeList(direction: DebtDirection?, status: DebtStatus?, includeArchived: Boolean): Flow<List<DebtEntity>>

    /**
     * Abonado por deuda: movimientos con `debtId` cuyo tipo es el de abono para la dirección de la
     * deuda (el de origen tiene el tipo contrario; ver `repaymentTypeOf`).
     */
    @Query(DEBT_PAID_SQL)
    suspend fun getPaid(): List<DebtPaidRow>

    @Query(DEBT_PAID_SQL)
    fun observePaid(): Flow<List<DebtPaidRow>>

    @Query("UPDATE debts SET status = :status, updatedAt = :updatedAt WHERE id = :id")
    suspend fun setStatus(id: String, status: DebtStatus, updatedAt: Long)
}
