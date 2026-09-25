import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'name_catalog_screen.dart';

/// Etiquetas para agrupar movimientos de forma libre.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tagRepositoryProvider);
    return NameCatalogScreen(
      title: 'Etiquetas',
      singular: 'etiqueta',
      newLabel: 'Nueva etiqueta',
      icon: Icons.local_offer_rounded,
      emptyMessage: 'Marca movimientos como "Viaje" o "Trabajo" para reunirlos después.',
      items: ref
          .watch(tagsProvider)
          .whenData(
            (all) => [
              for (final x in all) CatalogItem(id: x.id, name: x.name, isArchived: x.isArchived),
            ],
          ),
      onCreate: (name) => repo.create(name),
      onRename: (id, name) => repo.update(id, name: name),
      onArchive: repo.setArchived,
    );
  }
}
