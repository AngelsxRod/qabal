import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/async_body.dart';
import '../common/confirm_dialog.dart';
import '../common/name_dialog.dart';
import '../design/app_card.dart';
import '../design/category_avatar.dart';
import '../design/empty_state.dart';
import '../design/list_row.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Elemento de un catálogo con solo nombre (contactos, etiquetas).
class CatalogItem {
  const CatalogItem({required this.id, required this.name, required this.isArchived});

  final String id;
  final String name;
  final bool isArchived;
}

/// Lista de un catálogo con solo nombre: crear, renombrar (tocando la fila) y
/// archivar o restaurar. Los archivados se ocultan salvo que se pidan.
class NameCatalogScreen extends ConsumerStatefulWidget {
  const NameCatalogScreen({
    super.key,
    required this.title,
    required this.singular,
    required this.newLabel,
    required this.icon,
    required this.emptyMessage,
    required this.items,
    required this.onCreate,
    required this.onRename,
    required this.onArchive,
  });

  /// Título de la pantalla: "Contactos".
  final String title;

  /// Nombre en singular y minúsculas: "contacto".
  final String singular;

  /// Texto de la acción de crear: "Nuevo contacto", "Nueva etiqueta".
  final String newLabel;
  final IconData icon;
  final String emptyMessage;
  final AsyncValue<List<CatalogItem>> items;
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(String id, String name) onRename;
  final Future<void> Function(String id, bool archived) onArchive;

  @override
  ConsumerState<NameCatalogScreen> createState() => _NameCatalogScreenState();
}

class _NameCatalogScreenState extends ConsumerState<NameCatalogScreen> {
  bool _showArchived = false;

  Future<void> _create() => showNameDialog(
    context,
    title: widget.newLabel,
    confirmLabel: 'Crear',
    onSubmit: widget.onCreate,
  );

  Future<void> _rename(CatalogItem item) => showNameDialog(
    context,
    title: 'Renombrar ${widget.singular}',
    initial: item.name,
    onSubmit: (name) => widget.onRename(item.id, name),
  );

  Future<void> _toggleArchive(CatalogItem item) async {
    if (!item.isArchived) {
      final ok = await confirmAction(
        context,
        title: 'Archivar ${widget.singular}',
        message:
            '"${item.name}" dejará de ofrecerse al registrar movimientos. '
            'Los movimientos que ya lo usan lo conservan.',
        confirmLabel: 'Archivar',
      );
      if (!ok) return;
    }
    await widget.onArchive(item.id, !item.isArchived);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: widget.newLabel,
            icon: const Icon(Icons.add_rounded),
            onPressed: _create,
          ),
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              CheckedPopupMenuItem<void>(
                checked: _showArchived,
                onTap: () => setState(() => _showArchived = !_showArchived),
                child: const Text('Mostrar archivados'),
              ),
            ],
          ),
        ],
      ),
      body: AsyncBody(
        value: widget.items,
        data: (all) {
          final visible = all.where((x) => _showArchived || !x.isArchived).toList();
          if (visible.isEmpty) {
            final onlyArchived = all.isNotEmpty;
            return EmptyState(
              icon: widget.icon,
              title: onlyArchived
                  ? 'Todo está archivado'
                  : 'Aún no hay ${widget.title.toLowerCase()}',
              message: onlyArchived
                  ? 'Usa el menú para mostrar los archivados.'
                  : widget.emptyMessage,
              actionLabel: onlyArchived ? null : widget.newLabel,
              onAction: _create,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) Divider(indent: 68, color: c.border),
                      AppListRow(
                        leading: CategoryAvatar(
                          icon: widget.icon,
                          color: visible[i].isArchived ? c.textTertiary : c.accent,
                          size: 40,
                        ),
                        title: visible[i].name,
                        subtitle: visible[i].isArchived ? 'Archivado' : null,
                        dimmed: visible[i].isArchived,
                        onTap: () => _rename(visible[i]),
                        trailing: IconButton(
                          tooltip: visible[i].isArchived
                              ? 'Restaurar ${visible[i].name}'
                              : 'Archivar ${visible[i].name}',
                          icon: Icon(
                            visible[i].isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            color: c.textSecondary,
                          ),
                          onPressed: () => _toggleArchive(visible[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                'Toca un elemento para renombrarlo.',
                style: context.text.caption,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
