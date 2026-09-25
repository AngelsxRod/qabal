import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Fila de lista dentro de una tarjeta: ícono o avatar, título, subtítulo y
/// un elemento final. Sin [onTap] se ve atenuada y sin flecha ("Próximamente").
/// Con [dimmed] se atenúa igual pero sigue siendo tocable (elementos archivados).
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    this.minHeight = 64,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Elemento final (fuera de la zona tocable de la fila); sin él y con [onTap],
  /// una flecha.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final muted = onTap == null || dimmed;
    final body = Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              trailing == null ? Space.lg : Space.xs,
              Space.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(
                          color: muted ? c.textSecondary : c.textPrimary,
                        ),
                      ),
                      if (subtitle != null) Text(subtitle!, style: t.caption),
                    ],
                  ),
                ),
                if (trailing == null && onTap != null)
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
    if (trailing == null) return body;
    // El elemento final queda fuera de la zona tocable de la fila para que
    // conserve su propia semántica (por ejemplo, un botón de archivar).
    return Row(
      children: [
        Expanded(child: body),
        Padding(
          padding: const EdgeInsets.only(right: Space.sm),
          child: trailing,
        ),
      ],
    );
  }
}
