import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../design/app_card.dart';
import '../design/list_row.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';

/// Pestaña "Más": accesos secundarios. Deudas vivirá aquí; la galería de
/// componentes solo aparece en depuración.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget icon(IconData data, {required bool enabled}) =>
        Icon(data, color: enabled ? c.accent : c.textTertiary);

    return Scaffold(
      appBar: tabAppBar(context, 'Más'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListRow(
                  leading: icon(Icons.category_rounded, enabled: true),
                  title: 'Categorías',
                  subtitle: 'Gastos e ingresos',
                  onTap: () => context.push(Routes.categories),
                ),
                Divider(color: c.border),
                AppListRow(
                  leading: icon(Icons.person_rounded, enabled: true),
                  title: 'Contactos',
                  subtitle: 'Personas y comercios',
                  onTap: () => context.push(Routes.contacts),
                ),
                Divider(color: c.border),
                AppListRow(
                  leading: icon(Icons.local_offer_rounded, enabled: true),
                  title: 'Etiquetas',
                  subtitle: 'Agrupa tus movimientos',
                  onTap: () => context.push(Routes.tags),
                ),
                Divider(color: c.border),
                AppListRow(
                  leading: icon(Icons.handshake_rounded, enabled: false),
                  title: 'Deudas',
                  subtitle: 'Próximamente',
                ),
                if (kDebugMode) ...[
                  Divider(color: c.border),
                  AppListRow(
                    leading: icon(Icons.palette_outlined, enabled: true),
                    title: 'Galería de componentes',
                    subtitle: 'Solo en depuración',
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
