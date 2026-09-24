import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Acción rápida: ícono sobre una etiqueta corta, en una tarjeta con borde.
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c.accent, size: 24),
                const SizedBox(height: Space.xs),
                Text(label, style: context.text.bodyStrong.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de acciones rápidas de igual ancho.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.children});

  final List<QuickAction> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.sm),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
