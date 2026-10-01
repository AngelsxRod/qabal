package com.draskint.qabal.domain.model

import java.time.Instant

data class Category(
    val id: String,
    val name: String,
    val kind: CategoryKind,
    val parentId: String?,
    val icon: String?,
    val colorValue: Long?,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

/** Una subcategoría (con [parentId]) debe tener el mismo [kind] que su padre. */
data class CategoryInput(
    val name: String,
    val kind: CategoryKind,
    val parentId: String? = null,
    val icon: String? = null,
    val colorValue: Long? = null,
)

data class Contact(
    val id: String,
    val name: String,
    val type: ContactType?,
    val note: String?,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class ContactInput(
    val name: String,
    val type: ContactType? = null,
    val note: String? = null,
)

data class Tag(
    val id: String,
    val name: String,
    val colorValue: Long?,
    val isArchived: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)
