import 'package:flutter/material.dart';

import 'tokens.dart';

/// Barra fija al pie con la acción principal de un formulario. Se usa como
/// `bottomNavigationBar` de un `Scaffold`: sube junto con el teclado, así el
/// botón siempre está a la vista.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
          child: child,
        ),
      ),
    );
  }
}
