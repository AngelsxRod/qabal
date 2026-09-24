import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../design/tokens.dart';

String transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.expense => 'Gasto',
  TransactionType.income => 'Ingreso',
  TransactionType.transfer => 'Transferencia',
};

IconData transactionTypeIcon(TransactionType type) => switch (type) {
  TransactionType.expense => Icons.arrow_upward,
  TransactionType.income => Icons.arrow_downward,
  TransactionType.transfer => Icons.swap_horiz,
};

Color transactionTypeColor(BuildContext context, TransactionType type) {
  final colors = context.colors;
  return switch (type) {
    TransactionType.expense => colors.expense,
    TransactionType.income => colors.income,
    TransactionType.transfer => colors.transfer,
  };
}

/// Nombre de una categoría; las subcategorías se rotulan `Padre › Hijo`.
String categoryLabel(Category category, Map<String, Category> byId) {
  final parent = category.parentId == null ? null : byId[category.parentId];
  return parent == null ? category.name : '${parent.name} › ${category.name}';
}
