import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../common/async_body.dart';
import '../design/app_card.dart';
import '../design/category_avatar.dart';
import '../design/category_style.dart';
import '../design/empty_state.dart';
import '../design/list_row.dart';
import '../design/tokens.dart';
import '../design/type_switcher.dart';
import 'category_ids.dart';

/// Categorías por tipo, con un nivel de subcategorías. Tocar una fila la edita;
/// el "+" de una categoría agrega una subcategoría.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryKind _kind = CategoryKind.expense;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            tooltip: 'Nueva categoría',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(Routes.categoryNew(kind: _kind)),
          ),
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              CheckedPopupMenuItem<void>(
                checked: _showArchived,
                onTap: () => setState(() => _showArchived = !_showArchived),
                child: const Text('Mostrar archivadas'),
              ),
            ],
          ),
        ],
      ),
      body: AsyncBody(
        value: ref.watch(categoriesProvider),
        data: (all) {
          bool shown(Category x) => _showArchived || !x.isArchived;
          final ofKind = all.where((x) => x.kind == _kind && shown(x)).toList();
          final ids = {for (final x in ofKind) x.id};
          // Sin padre visible (o de otro tipo) se trata como categoría de primer nivel.
          final parents = ofKind.where((x) => x.parentId == null || !ids.contains(x.parentId));
          final children = <String, List<Category>>{};
          for (final x in ofKind) {
            if (x.parentId != null && ids.contains(x.parentId)) {
              (children[x.parentId!] ??= []).add(x);
            }
          }
          final rows = <(Category, bool)>[
            for (final p in parents) ...[
              (p, false),
              for (final ch in children[p.id] ?? []) (ch, true),
            ],
          ];
          final brightness = Theme.of(context).brightness;

          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              TypeSwitcher<CategoryKind>(
                value: _kind,
                options: const [
                  (CategoryKind.expense, 'Gastos'),
                  (CategoryKind.income, 'Ingresos'),
                ],
                colorOf: (k) => k == CategoryKind.income ? c.income : c.expense,
                onChanged: (k) => setState(() => _kind = k),
              ),
              const SizedBox(height: Space.lg),
              if (rows.isEmpty)
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.category_rounded,
                    title: 'Sin categorías',
                    message: 'Crea la primera para clasificar tus movimientos.',
                    actionLabel: 'Nueva categoría',
                    onAction: () => context.push(Routes.categoryNew(kind: _kind)),
                  ),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) Divider(indent: rows[i].$2 ? 96 : 72, color: c.border),
                        _row(context, rows[i].$1, isChild: rows[i].$2, brightness: brightness),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Category cat, {
    required bool isChild,
    required Brightness brightness,
  }) {
    final c = context.colors;
    final style = categoryStyleFor(cat, brightness);
    final system = isSystemCategory(cat.id);
    final canAddChild = !isChild && !system && !cat.isArchived;
    final row = AppListRow(
      leading: CategoryAvatar(icon: style.icon, color: style.color, size: isChild ? 32 : 40),
      title: cat.name,
      subtitle: cat.isArchived
          ? 'Archivada'
          : system
          ? 'Del sistema'
          : null,
      dimmed: cat.isArchived,
      minHeight: isChild ? 56 : 64,
      onTap: () => context.push(Routes.categoryEdit(cat.id)),
      trailing: canAddChild
          ? IconButton(
              tooltip: 'Agregar subcategoría a ${cat.name}',
              icon: Icon(Icons.add_rounded, color: c.textSecondary),
              onPressed: () => context.push(Routes.categoryNew(kind: cat.kind, parentId: cat.id)),
            )
          : null,
    );
    return isChild
        ? Padding(
            padding: const EdgeInsets.only(left: Space.xl),
            child: row,
          )
        : row;
  }
}
