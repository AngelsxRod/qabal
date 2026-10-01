package com.draskint.qabal.data.local.seed

import androidx.sqlite.db.SupportSQLiteDatabase
import com.draskint.qabal.domain.model.CategoryKind

/**
 * Ids fijos de las categorías del sistema. La lógica de tarjetas y de totales las identifica por id,
 * así que el usuario puede renombrarlas sin romperla.
 */
const val INTEREST_FEES_CATEGORY_ID = "system:interest-fees"
const val REFUNDS_CATEGORY_ID = "system:refunds"

object CategorySeed {

    private class Seed(val id: String, val name: String, val kind: CategoryKind, val icon: String)

    private val system = listOf(
        Seed(INTEREST_FEES_CATEGORY_ID, "Intereses y cargos", CategoryKind.EXPENSE, "percent"),
        Seed(REFUNDS_CATEGORY_ID, "Devoluciones", CategoryKind.INCOME, "undo"),
    )

    private val defaults = listOf(
        Seed("default:salary", "Sueldo", CategoryKind.INCOME, "payments"),
        Seed("default:freelance", "Freelance", CategoryKind.INCOME, "laptop"),
        Seed("default:sales", "Ventas", CategoryKind.INCOME, "sell"),
        Seed("default:interest-earned", "Intereses ganados", CategoryKind.INCOME, "savings"),
        Seed("default:gifts-received", "Regalos recibidos", CategoryKind.INCOME, "redeem"),
        Seed("default:other-income", "Otros ingresos", CategoryKind.INCOME, "add_circle"),
        Seed("default:food", "Comida", CategoryKind.EXPENSE, "restaurant"),
        Seed("default:groceries", "Supermercado", CategoryKind.EXPENSE, "shopping_cart"),
        Seed("default:transport", "Transporte", CategoryKind.EXPENSE, "directions_bus"),
        Seed("default:utilities", "Servicios", CategoryKind.EXPENSE, "bolt"),
        Seed("default:housing", "Vivienda", CategoryKind.EXPENSE, "home"),
        Seed("default:health", "Salud", CategoryKind.EXPENSE, "favorite"),
        Seed("default:education", "Educación", CategoryKind.EXPENSE, "school"),
        Seed("default:entertainment", "Entretenimiento", CategoryKind.EXPENSE, "movie"),
        Seed("default:shopping", "Compras", CategoryKind.EXPENSE, "shopping_bag"),
        Seed("default:subscriptions", "Suscripciones", CategoryKind.EXPENSE, "subscriptions"),
        Seed("default:gifts-donations", "Regalos y donaciones", CategoryKind.EXPENSE, "card_giftcard"),
        Seed("default:other-expense", "Otros gastos", CategoryKind.EXPENSE, "more_horiz"),
    )

    /** Garantiza las categorías del sistema. Idempotente: nunca duplica ni pisa datos del usuario. */
    fun ensureSystem(db: SupportSQLiteDatabase, nowMillis: Long) = insertAll(db, system, nowMillis)

    /** Siembra las categorías por defecto y las del sistema. Idempotente. */
    fun seedDefaults(db: SupportSQLiteDatabase, nowMillis: Long) {
        insertAll(db, system, nowMillis)
        insertAll(db, defaults, nowMillis)
    }

    private fun insertAll(db: SupportSQLiteDatabase, seeds: List<Seed>, nowMillis: Long) {
        seeds.forEach {
            db.execSQL(
                "INSERT OR IGNORE INTO categories (id, name, kind, icon, isArchived, createdAt, updatedAt) " +
                    "VALUES (?, ?, ?, ?, 0, ?, ?)",
                arrayOf(it.id, it.name, it.kind.name, it.icon, nowMillis, nowMillis),
            )
        }
    }
}
