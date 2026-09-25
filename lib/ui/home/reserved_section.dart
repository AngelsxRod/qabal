import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// Espacio de Inicio reservado para una fase posterior. Mientras [visible]
/// sea `false` no ocupa lugar; al activarse muestra [title] y [child].
///
/// - "Próximos pagos": F3 (tarjetas).
/// - "Te deben / Debes": F4 (deudas).
class ReservedSection extends StatelessWidget {
  const ReservedSection({super.key, required this.title, this.child, this.visible = false});

  final String title;
  final Widget? child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: context.text.label),
          const SizedBox(height: Space.sm),
          child!,
        ],
      ),
    );
  }
}
