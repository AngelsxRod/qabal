import 'package:flutter/material.dart';

import 'category_style.dart';
import 'tokens.dart';

/// Elección de ícono para una categoría: una cuadrícula de círculos de 48 dp
/// (5 por fila a 320 dp). [color] tiñe los íconos para dar una vista previa.
class IconChooser extends StatelessWidget {
  const IconChooser({
    super.key,
    required this.icons,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  /// Ids de ícono (ver `categoryIconChoices`).
  final List<String> icons;
  final String? selected;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final id in icons)
          Semantics(
            button: true,
            selected: id == selected,
            label: 'Ícono $id',
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(id),
              child: Container(
                width: kMinTap,
                height: kMinTap,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: id == selected ? color.withValues(alpha: 0.14) : c.surface,
                  border: Border.all(
                    color: id == selected ? c.accent : c.border,
                    width: id == selected ? 2 : 1,
                  ),
                ),
                child: Icon(categoryIcon(id), color: color, size: 24),
              ),
            ),
          ),
      ],
    );
  }
}

/// Elección de color para una categoría: círculos de 44 dp con una marca en el
/// elegido. Los colores se aclaran en modo oscuro igual que en el resto de la
/// app.
class ColorChooser extends StatelessWidget {
  const ColorChooser({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.md,
      children: [
        for (var i = 0; i < colors.length; i++)
          Builder(
            builder: (_) {
              final isSelected = selected?.toARGB32() == colors[i].toARGB32();
              final shown = adaptToBrightness(colors[i], brightness);
              return Semantics(
                button: true,
                selected: isSelected,
                label: 'Color ${i + 1}',
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onChanged(colors[i]),
                  child: Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? c.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: shown),
                      child: isSelected
                          ? Icon(Icons.check_rounded, size: 20, color: c.background)
                          : null,
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
