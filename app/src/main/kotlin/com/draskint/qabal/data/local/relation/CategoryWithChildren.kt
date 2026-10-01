package com.draskint.qabal.data.local.relation

import androidx.room.Embedded
import androidx.room.Relation
import com.draskint.qabal.data.local.entity.CategoryEntity

/** Categoría con sus subcategorías directas. */
data class CategoryWithChildren(
    @Embedded val category: CategoryEntity,
    @Relation(parentColumn = "id", entityColumn = "parentId")
    val children: List<CategoryEntity>,
)
