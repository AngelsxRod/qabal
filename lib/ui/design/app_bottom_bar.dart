import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

class BottomBarItem {
  const BottomBarItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra inferior con cuatro destinos y un botón central de acción ("+").
/// Los destinos se reparten a los lados: los dos primeros a la izquierda y
/// el resto a la derecha.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onAction,
    this.actionLabel = 'Nuevo movimiento',
  }) : assert(items.length == 4);

  final List<BottomBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(int i) => Expanded(
      child: _Destination(item: items[i], selected: i == currentIndex, onTap: () => onSelected(i)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              item(0),
              item(1),
              SizedBox(
                width: 60,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: actionLabel,
                    excludeSemantics: true,
                    child: Material(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        onTap: onAction,
                        child: SizedBox(
                          width: 52,
                          height: 48,
                          child: Icon(Icons.add_rounded, color: c.onAccent, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.item, required this.selected, required this.onTap});

  final BottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.accent : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.selectedIcon : item.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: context.text.label.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
