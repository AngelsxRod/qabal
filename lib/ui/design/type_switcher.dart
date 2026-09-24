import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Selector compacto de 2 a 4 opciones, en forma de píldora.
class TypeSwitcher<T> extends StatelessWidget {
  const TypeSwitcher({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.colorOf,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Color del texto de la opción elegida (por defecto, el principal).
  final Color Function(T)? colorOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      height: kMinTap,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.sm + 2),
                      border: v == value ? Border.all(color: c.border) : null,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: t.bodyStrong.copyWith(
                        fontSize: 14,
                        color: v == value ? (colorOf?.call(v) ?? c.textPrimary) : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
