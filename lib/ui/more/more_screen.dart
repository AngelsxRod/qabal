import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../design/app_card.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Pestaña "Más": accesos secundarios. Deudas vivirá aquí; la galería de
/// componentes solo aparece en depuración.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    Widget row(IconData icon, String title, String subtitle, {VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Row(
            children: [
              Icon(icon, color: onTap == null ? c.textTertiary : c.accent),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyStrong.copyWith(
                        color: onTap == null ? c.textSecondary : c.textPrimary,
                      ),
                    ),
                    Text(subtitle, style: t.caption),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: tabAppBar(context, 'Más'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                row(Icons.handshake_rounded, 'Deudas', 'Próximamente'),
                if (kDebugMode) ...[
                  Divider(color: c.border),
                  row(
                    Icons.palette_outlined,
                    'Galería de componentes',
                    'Solo en depuración',
                    onTap: () => context.push(Routes.gallery),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
