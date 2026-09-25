import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Nota informativa con un ícono, sobre un fondo suave del acento. Para
/// vistas previas y avisos que no son errores.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.accent),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(text, style: context.text.caption.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}
