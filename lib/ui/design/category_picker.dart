import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import 'category_avatar.dart';
import 'category_style.dart';
import 'tokens.dart';
import 'typography.dart';

/// Resultado del selector de categoría; `id` nulo significa "sin categoría".
/// (Cerrar la hoja sin elegir devuelve `null`, no un `CategoryPick`.)
class CategoryPick {
  const CategoryPick(this.id);

  final String? id;
}

/// Hoja inferior con las categorías en cuadrícula de íconos. [categories]
/// debe venir ya filtrada por tipo.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  required List<Category> categories,
  required String? selectedId,
  String title = 'Categoría',
}) => showModalBottomSheet<CategoryPick>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _CategoryGrid(categories: categories, selectedId: selectedId, title: title),
);

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.selectedId, required this.title});

  final List<Category> categories;
  final String? selectedId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;
    final items = <Widget>[
      _Cell(
        label: 'Sin categoría',
        selected: selectedId == null,
        style: categoryStyleFor(null, brightness),
        onTap: () => Navigator.of(context).pop(const CategoryPick(null)),
      ),
      for (final cat in categories)
        _Cell(
          label: cat.name,
          selected: cat.id == selectedId,
          style: categoryStyleFor(cat, brightness),
          onTap: () => Navigator.of(context).pop(CategoryPick(cat.id)),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
          child: Text(title, style: t.heading.copyWith(color: c.textPrimary)),
        ),
        Flexible(
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.xs,
            childAspectRatio: 0.82,
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
            children: items,
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CategoryStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? c.accent : Colors.transparent, width: 2),
                ),
                child: CategoryAvatar(icon: style.icon, color: style.color, size: 48),
              ),
              const SizedBox(height: Space.xs),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
