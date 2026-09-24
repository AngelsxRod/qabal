import 'package:flutter/material.dart';

import 'tokens.dart';

enum AppButtonKind { primary, secondary, text }

/// Botón de la app. El primario ocupa todo el ancho y mide 52 dp.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kind == AppButtonKind.primary ? c.onAccent : c.accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: Space.sm)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = loading ? null : onPressed;
    return switch (kind) {
      AppButtonKind.primary => FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: child,
      ),
      AppButtonKind.secondary => OutlinedButton(
        onPressed: action,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: child,
      ),
      AppButtonKind.text => TextButton(onPressed: action, child: child),
    };
  }
}
