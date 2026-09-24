import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/common/placeholder_screen.dart';
import '../ui/shell/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rutas de las pestañas.
abstract final class Routes {
  static const home = '/inicio';
  static const transactions = '/movimientos';
  static const accounts = '/cuentas';
  static const debts = '/deudas';
  static const more = '/mas';
}

GoRouter buildRouter({String initialLocation = Routes.home}) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) =>
                    const PlaceholderScreen(title: 'Inicio', icon: Icons.home_outlined),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (_, _) => const PlaceholderScreen(
                    title: 'Movimientos', icon: Icons.receipt_long_outlined),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.accounts,
                builder: (_, _) => const PlaceholderScreen(
                    title: 'Cuentas', icon: Icons.account_balance_wallet_outlined),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.debts,
                builder: (_, _) =>
                    const PlaceholderScreen(title: 'Deudas', icon: Icons.handshake_outlined),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.more,
                builder: (_, _) =>
                    const PlaceholderScreen(title: 'Más', icon: Icons.more_horiz),
              ),
            ]),
          ],
        ),
      ],
    );

/// Un único router por `ProviderScope`.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
