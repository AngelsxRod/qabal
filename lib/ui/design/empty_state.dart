import 'package:flutter/material.dart';

import 'app_button.dart';
import 'tokens.dart';
import 'typography.dart';

/// Estado vacío: un ícono, un mensaje breve y, opcionalmente, una acción.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: c.accent),
            ),
            const SizedBox(height: Space.lg),
            Text(title, style: t.heading, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Space.sm),
              Text(message!, style: t.caption, textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Space.xl),
              AppButton(label: actionLabel!, onPressed: onAction, icon: Icons.add_rounded),
            ],
          ],
        ),
      ),
    );
  }
}
