package com.draskint.qabal.di

import android.content.Context
import androidx.room.Room
import com.draskint.qabal.data.local.AppDatabase
import com.draskint.qabal.data.local.DatabaseCallback
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.time.Clock
import javax.inject.Singleton

/** Base de datos y DAOs. Room activa las claves foráneas por sí solo al abrir la conexión. */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context, clock: Clock): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, AppDatabase.NAME)
            .addCallback(DatabaseCallback(clock))
            .build()

    @Provides fun provideAccountDao(db: AppDatabase) = db.accountDao()
    @Provides fun provideCategoryDao(db: AppDatabase) = db.categoryDao()
    @Provides fun provideContactDao(db: AppDatabase) = db.contactDao()
    @Provides fun provideTagDao(db: AppDatabase) = db.tagDao()
    @Provides fun provideCreditCardDao(db: AppDatabase) = db.creditCardDao()
    @Provides fun provideDebtDao(db: AppDatabase) = db.debtDao()
    @Provides fun provideTransactionDao(db: AppDatabase) = db.transactionDao()
}
