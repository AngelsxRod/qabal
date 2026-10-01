package com.draskint.qabal.data.local

import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.draskint.qabal.data.local.seed.CategorySeed
import com.draskint.qabal.data.local.trigger.IntegrityTriggers
import java.time.Clock

/**
 * Al crear la base siembra las categorías; en cada apertura reinstala los triggers de integridad
 * (así una regla cambiada llega a las bases ya existentes) y garantiza las categorías del sistema.
 */
class DatabaseCallback(private val clock: Clock) : RoomDatabase.Callback() {

    override fun onCreate(db: SupportSQLiteDatabase) {
        CategorySeed.seedDefaults(db, clock.millis())
    }

    override fun onOpen(db: SupportSQLiteDatabase) {
        IntegrityTriggers.reinstall(db)
        CategorySeed.ensureSystem(db, clock.millis())
    }
}
