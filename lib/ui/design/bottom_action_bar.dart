import 'package:flutter/material.dart';

import 'tokens.dart';

/// Barra fija al pie con la acción principal de un formulario. Se usa como
/// `bottomNavigationBar` de un `Scaffold`. Un `Scaffold` no sube esta barra con
/// el teclado, así que se rellena con el alto del teclado: el botón siempre
/// está a la vista.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
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
      ),
    );
  }
}
