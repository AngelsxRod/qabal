package com.draskint.qabal.data.local.relation

/** Total abonado a una deuda (ver `DebtDao.observePaid`). */
data class DebtPaidRow(val debtId: String, val paidMinor: Long)
