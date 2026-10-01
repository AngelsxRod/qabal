package com.draskint.qabal.data.repository

import com.draskint.qabal.data.local.AppDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Flujo de un valor calculado con varias consultas: se recalcula al cambiar cualquiera de [tables]
 * (nombres de tabla de Room) y emite el valor inicial al empezar a recolectarse.
 */
fun <T> AppDatabase.observeComputed(vararg tables: String, compute: suspend () -> T): Flow<T> =
    invalidationTracker.createFlow(*tables).map { compute() }
