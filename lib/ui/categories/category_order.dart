import '../../data/database/app_database.dart';

/// Ordena categorías para un selector: cada una de primer nivel por nombre,
/// seguida de sus subcategorías (también por nombre). Una subcategoría cuyo
/// padre no está en [categories] se trata como de primer nivel.
List<Category> orderForPicker(List<Category> categories) {
  int byName(Category a, Category b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final ids = {for (final c in categories) c.id};
  final roots = categories.where((c) => c.parentId == null || !ids.contains(c.parentId)).toList()
    ..sort(byName);
  return [
    for (final root in roots) ...[
      root,
      ...(categories.where((c) => c.parentId == root.id).toList()..sort(byName)),
    ],
  ];
}
