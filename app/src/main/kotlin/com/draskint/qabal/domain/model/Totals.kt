package com.draskint.qabal.domain.model

/** Totales de un periodo en una moneda (sin conversión). Excluyen transferencias y movimientos de deuda. */
data class PeriodTotals(
    val currency: String,
    /** Ingresos sin contar la categoría del sistema «Devoluciones». */
    val incomeMinor: Long,
    /** Gastos **netos**: ya restadas las devoluciones. */
    val expenseMinor: Long,
    /** Devoluciones del periodo (informativo; ya están restadas en [expenseMinor]). */
    val refundsMinor: Long,
) {
    val grossExpenseMinor: Long get() = expenseMinor + refundsMinor
}

/** Total por moneda y categoría; [categoryId] nulo = sin categoría. En gastos, la línea de devoluciones es negativa. */
data class CategoryTotal(val currency: String, val categoryId: String?, val totalMinor: Long)
