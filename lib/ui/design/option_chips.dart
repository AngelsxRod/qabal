import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

class Option<T> {
  const Option(this.value, this.label, {this.enabled = true});

  final T value;
  final String label;

  /// Una opción deshabilitada se ve atenuada y no se puede elegir.
  final bool enabled;
}

/// Opciones en chips que saltan de línea (para listas cortas: tipo de cuenta,
/// moneda). Con [enabled] en `false` todo el grupo queda de solo lectura.
class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Option<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final o in options)
          Builder(
            builder: (context) {
              final selected = o.value == value;
              final active = enabled && o.enabled;
              final fg = !active
                  ? c.textTertiary
                  : selected
                  ? c.accent
                  : c.textPrimary;
              return Semantics(
                button: true,
                selected: selected,
                enabled: active,
                label: o.label,
                excludeSemantics: true,
                child: Material(
                  color: selected ? c.accentSoft : c.surface,
                  shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: active ? () => onChanged(o.value) : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: kMinTap),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                                child: Text(o.label, style: t.bodyStrong.copyWith(color: fg)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
