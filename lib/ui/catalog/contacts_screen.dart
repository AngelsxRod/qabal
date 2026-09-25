import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'name_catalog_screen.dart';

/// Contactos: personas o comercios a quienes se asocian movimientos.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(contactRepositoryProvider);
    return NameCatalogScreen(
      title: 'Contactos',
      singular: 'contacto',
      newLabel: 'Nuevo contacto',
      icon: Icons.person_rounded,
      emptyMessage: 'Guarda a quién le pagas o de quién recibes para encontrarlo rápido.',
      items: ref
          .watch(contactsProvider)
          .whenData(
            (all) => [
              for (final x in all) CatalogItem(id: x.id, name: x.name, isArchived: x.isArchived),
            ],
          ),
      onCreate: (name) => repo.create(ContactInput(name: name)),
      onRename: (id, name) => repo.update(id, name: name),
      onArchive: repo.setArchived,
    );
  }
}
