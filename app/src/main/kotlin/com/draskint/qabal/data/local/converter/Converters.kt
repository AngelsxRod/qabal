package com.draskint.qabal.data.local.converter

import androidx.room.TypeConverter
import com.draskint.qabal.domain.model.AccountType
import com.draskint.qabal.domain.model.CategoryKind
import com.draskint.qabal.domain.model.ContactType
import com.draskint.qabal.domain.model.DebtDirection
import com.draskint.qabal.domain.model.DebtStatus
import com.draskint.qabal.domain.model.TransactionType
import java.time.Instant
import java.time.LocalDate

/**
 * Convertidores de Room. Los enums se guardan por `name`, las fechas sin hora como `yyyy-MM-dd`
 * (orden lexicográfico = orden cronológico) y los instantes como milisegundos desde epoch.
 */
class Converters {

    @TypeConverter
    fun fromLocalDate(value: LocalDate?): String? = value?.toString()

    @TypeConverter
    fun toLocalDate(value: String?): LocalDate? = value?.let(LocalDate::parse)

    @TypeConverter
    fun fromInstant(value: Instant?): Long? = value?.toEpochMilli()

    @TypeConverter
    fun toInstant(value: Long?): Instant? = value?.let(Instant::ofEpochMilli)

    @TypeConverter
    fun fromAccountType(value: AccountType?): String? = value?.name

    @TypeConverter
    fun toAccountType(value: String?): AccountType? = value?.let(AccountType::valueOf)

    @TypeConverter
    fun fromCategoryKind(value: CategoryKind?): String? = value?.name

    @TypeConverter
    fun toCategoryKind(value: String?): CategoryKind? = value?.let(CategoryKind::valueOf)

    @TypeConverter
    fun fromTransactionType(value: TransactionType?): String? = value?.name

    @TypeConverter
    fun toTransactionType(value: String?): TransactionType? = value?.let(TransactionType::valueOf)

    @TypeConverter
    fun fromContactType(value: ContactType?): String? = value?.name

    @TypeConverter
    fun toContactType(value: String?): ContactType? = value?.let(ContactType::valueOf)

    @TypeConverter
    fun fromDebtDirection(value: DebtDirection?): String? = value?.name

    @TypeConverter
    fun toDebtDirection(value: String?): DebtDirection? = value?.let(DebtDirection::valueOf)

    @TypeConverter
    fun fromDebtStatus(value: DebtStatus?): String? = value?.name

    @TypeConverter
    fun toDebtStatus(value: String?): DebtStatus? = value?.let(DebtStatus::valueOf)
}
