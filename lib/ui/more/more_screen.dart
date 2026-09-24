import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Pestaña "Más": accesos secundarios. Por ahora, la galería de componentes
/// (solo en depuración).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        children: [
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Galería de componentes'),
              subtitle: const Text('Solo en depuración'),
              onTap: () => context.push(Routes.gallery),
            ),
        ],
      ),
    );
  }
}
