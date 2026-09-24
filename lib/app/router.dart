import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/accounts/account_form_screen.dart';
import '../ui/accounts/accounts_screen.dart';
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

  static const accountNew = '/cuentas/nueva';
  static String accountDetail(String id) => '/cuentas/$id';
  static String accountEdit(String id) => '/cuentas/$id/editar';
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
                builder: (_, _) => const AccountsScreen(),
                routes: [
                  // Los formularios cubren la barra de pestañas.
                  GoRoute(
                    path: 'nueva',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AccountFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/editar',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) =>
                        AccountFormScreen(accountId: state.pathParameters['id']),
                  ),
                ],
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
