package com.draskint.qabal.data.local

import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.draskint.qabal.data.local.seed.CategorySeed
import com.draskint.qabal.data.local.trigger.IntegrityTriggers
import java.time.Clock

/**
 * Al crear la base instala los triggers de integridad y siembra las categorías; en cada apertura
 * vuelve a garantizar las del sistema.
 */
class DatabaseCallback(private val clock: Clock) : RoomDatabase.Callback() {

    override fun onCreate(db: SupportSQLiteDatabase) {
        IntegrityTriggers.install(db)
        CategorySeed.seedDefaults(db, clock.millis())
    }

    override fun onOpen(db: SupportSQLiteDatabase) {
        CategorySeed.ensureSystem(db, clock.millis())
    }
}
