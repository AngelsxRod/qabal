package com.draskint.qabal.data.local.relation

import androidx.room.Embedded
import androidx.room.Relation
import com.draskint.qabal.data.local.entity.AccountEntity
import com.draskint.qabal.data.local.entity.CreditCardStatementEntity

/** Sumas de los movimientos de una tarjeta en una ventana (ver `TransactionDao.getCycleSums`). */
data class CycleSumsRow(
    val purchases: Long,
    val interest: Long,
    val advances: Long,
    val refunds: Long,
    val otherCredits: Long,
    val payments: Long,
)

/** Pagos vinculados a un estado de cuenta. */
data class StatementPaidRow(val statementId: String, val paidMinor: Long)

/** Estado de cuenta con la tarjeta a la que pertenece. */
data class StatementWithCard(
    @Embedded val statement: CreditCardStatementEntity,
    @Relation(parentColumn = "accountId", entityColumn = "id")
    val card: AccountEntity,
)

/** Ingresos, gastos brutos y devoluciones de una moneda (ver `TransactionDao.getPeriodTotals`). */
data class PeriodTotalsRow(val currency: String, val income: Long, val grossExpense: Long, val refunds: Long)

data class CategoryTotalRow(val currency: String, val categoryId: String?, val total: Long)
