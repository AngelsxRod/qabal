import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Encabezado de un grupo de movimientos: día a la izquierda y, si se da,
/// el total del día a la derecha.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label, this.total});

  final String label;

  /// Normalmente un `AmountText` pequeño.
  final Widget? total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.label)),
          ?total,
        ],
      ),
    );
  }
}
