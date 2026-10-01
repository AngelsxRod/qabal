package com.draskint.qabal.domain.model

/** Tipo del movimiento que origina la deuda (dinero prestado o recibido). */
fun originTypeOf(direction: DebtDirection): TransactionType =
    if (direction == DebtDirection.OWED_TO_ME) TransactionType.EXPENSE else TransactionType.INCOME

/** Tipo de los abonos: es el contrario al del origen. */
fun repaymentTypeOf(direction: DebtDirection): TransactionType =
    if (direction == DebtDirection.OWED_TO_ME) TransactionType.INCOME else TransactionType.EXPENSE
