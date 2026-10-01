package com.draskint.qabal.data.local.trigger

import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * Invariantes que Drift expresaba con `CHECK` y que Room no soporta. Cada regla genera un trigger
 * `BEFORE INSERT` y otro `BEFORE UPDATE` que abortan la operación cuando la fila nueva la viola.
 *
 * Los triggers se reinstalan en cada apertura de la base ([reinstall]: borrar y recrear dentro de una
 * transacción), así que cambiar una regla aquí basta: no hace falta tocarla en las migraciones.
 */
object IntegrityTriggers {

    private class Rule(val table: String, val name: String, val violation: String, val message: String)

    private val rules = listOf(
        Rule("transactions", "amount_positive", "NEW.amountMinor <= 0", "El monto debe ser positivo"),
        Rule(
            "transactions", "transfer_has_destination",
            "(NEW.type = 'TRANSFER') <> (NEW.transferAccountId IS NOT NULL)",
            "Solo las transferencias llevan cuenta destino, y todas deben llevarla",
        ),
        Rule(
            "transactions", "transfer_distinct_accounts",
            "NEW.transferAccountId IS NOT NULL AND NEW.transferAccountId = NEW.accountId",
            "El origen y el destino de una transferencia deben ser distintos",
        ),
        Rule(
            "transactions", "transfer_amount_valid",
            "NEW.transferAmountMinor IS NOT NULL AND (NEW.type <> 'TRANSFER' OR NEW.transferAmountMinor <= 0)",
            "El monto destino solo aplica a transferencias y debe ser positivo",
        ),
        Rule(
            "transactions", "statement_only_transfer",
            "NEW.statementId IS NOT NULL AND NEW.type <> 'TRANSFER'",
            "Solo una transferencia puede pagar un estado de cuenta",
        ),
        Rule(
            "transactions", "debt_not_transfer",
            "NEW.debtId IS NOT NULL AND NEW.type = 'TRANSFER'",
            "Un movimiento de deuda no puede ser una transferencia",
        ),
        Rule("debts", "principal_positive", "NEW.principalMinor <= 0", "El principal debe ser positivo"),
        Rule(
            "credit_card_details", "limit_positive", "NEW.creditLimitMinor <= 0",
            "El límite de crédito debe ser positivo",
        ),
        Rule(
            "credit_card_details", "days_valid",
            "NEW.statementDay NOT BETWEEN 1 AND 31 OR NEW.dueDay NOT BETWEEN 1 AND 31",
            "Los días de corte y de pago deben estar entre 1 y 31",
        ),
        Rule(
            "credit_card_details", "min_payment_valid",
            "NEW.minPaymentBp IS NOT NULL AND NEW.minPaymentBp NOT BETWEEN 0 AND 10000",
            "El pago mínimo debe estar entre 0 y 10000 puntos básicos",
        ),
        Rule(
            "credit_card_statements", "amounts_valid",
            "NEW.statementBalanceMinor < 0 OR NEW.minimumPaymentMinor < 0 " +
                "OR NEW.minimumPaymentMinor > NEW.statementBalanceMinor",
            "Los montos del estado de cuenta no son válidos",
        ),
    )

    private val events = listOf("INSERT", "UPDATE")

    private fun triggerName(rule: Rule, event: String) = "trg_${rule.table}_${rule.name}_${event.lowercase()}"

    /** Sentencias `DROP TRIGGER IF EXISTS` de todas las reglas. */
    fun dropStatements(): List<String> =
        rules.flatMap { rule -> events.map { "DROP TRIGGER IF EXISTS ${triggerName(rule, it)}" } }

    /** Sentencias `CREATE TRIGGER` de todas las reglas; son idempotentes. */
    fun statements(): List<String> = rules.flatMap { rule ->
        events.map { event ->
            "CREATE TRIGGER IF NOT EXISTS ${triggerName(rule, event)} " +
                "BEFORE $event ON ${rule.table} FOR EACH ROW WHEN ${rule.violation} " +
                "BEGIN SELECT RAISE(ABORT, '${rule.message.replace("'", "''")}'); END"
        }
    }

    fun install(db: SupportSQLiteDatabase) = statements().forEach(db::execSQL)

    /** Reemplaza los triggers por la definición actual de las reglas (atómico). */
    fun reinstall(db: SupportSQLiteDatabase) {
        db.beginTransaction()
        try {
            dropStatements().forEach(db::execSQL)
            install(db)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }
}
