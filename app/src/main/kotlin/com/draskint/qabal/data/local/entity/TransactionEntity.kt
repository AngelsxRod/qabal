package com.draskint.qabal.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.draskint.qabal.domain.model.TransactionType
import java.time.Instant

/**
 * Movimiento de dinero. `amountMinor` es siempre positivo; el signo lo determina `type`. En una
 * transferencia, `accountId` es el origen y `transferAccountId` el destino; `transferAmountMinor`
 * solo se usa cuando las monedas de ambas cuentas difieren.
 *
 * - Pago de tarjeta: transferencia hacia la tarjeta, opcionalmente con `statementId`.
 * - Movimiento de deuda (origen o abono): lleva `debtId`, sin categoría, y se excluye de los
 *   totales de ingresos y gastos.
 *
 * Room no soporta `CHECK`; las invariantes las refuerzan el dominio y los triggers.
 */
@Entity(
    tableName = "transactions",
    foreignKeys = [
        ForeignKey(AccountEntity::class, ["id"], ["accountId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(CategoryEntity::class, ["id"], ["categoryId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(AccountEntity::class, ["id"], ["transferAccountId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(ContactEntity::class, ["id"], ["contactId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(DebtEntity::class, ["id"], ["debtId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(CreditCardStatementEntity::class, ["id"], ["statementId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [
        Index(value = ["accountId", "occurredAt"], name = "idx_transactions_account_date"),
        Index(value = ["transferAccountId", "occurredAt"], name = "idx_transactions_transfer_date"),
        Index(value = ["categoryId"], name = "idx_transactions_category"),
        Index(value = ["statementId"], name = "idx_transactions_statement"),
        Index(value = ["debtId"], name = "idx_transactions_debt"),
        Index(value = ["contactId"], name = "idx_transactions_contact"),
    ],
)
data class TransactionEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val categoryId: String? = null,
    val type: TransactionType,
    val amountMinor: Long,
    val transferAccountId: String? = null,
    val transferAmountMinor: Long? = null,
    val contactId: String? = null,
    val debtId: String? = null,
    val statementId: String? = null,
    val note: String? = null,
    /** Ruta relativa a la carpeta de documentos de la app. */
    val receiptPath: String? = null,
    val occurredAt: Instant,
    val createdAt: Instant,
    val updatedAt: Instant,
)
