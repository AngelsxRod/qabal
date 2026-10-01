package com.draskint.qabal.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import java.util.UUID
import javax.inject.Singleton

/** Generador de ids de registros nuevos (UUID v4); inyectable para fijarlo en tests. */
fun interface IdGenerator {
    fun newId(): String
}

@Module
@InstallIn(SingletonComponent::class)
object IdModule {

    @Provides
    @Singleton
    fun provideIdGenerator(): IdGenerator = IdGenerator { UUID.randomUUID().toString() }
}
