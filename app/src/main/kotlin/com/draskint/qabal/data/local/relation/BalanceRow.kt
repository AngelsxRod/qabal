package com.draskint.qabal.data.local.relation

/** Saldo calculado de una cuenta (ver `AccountDao.observeBalances`). */
data class BalanceRow(val accountId: String, val balanceMinor: Long)
