import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';

import '../ui/accounts/account_entry_screen.dart';
import '../ui/accounts/account_form_screen.dart';
import '../ui/accounts/accounts_screen.dart';
import '../ui/cards/statement_detail_screen.dart';
import '../ui/cards/statement_form_screen.dart';
import '../ui/catalog/contacts_screen.dart';
import '../ui/categories/categories_screen.dart';
import '../ui/categories/category_form_screen.dart';
import '../ui/catalog/tags_screen.dart';
import '../ui/design/gallery_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/more/more_screen.dart';
import '../ui/shell/app_shell.dart';
import '../ui/transactions/transaction_filter_params.dart';
import '../ui/transactions/transaction_form_screen.dart';
import '../ui/transactions/transactions_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rutas de las pestañas.
abstract final class Routes {
  static const home = '/inicio';
  static const transactions = '/movimientos';
  static const accounts = '/cuentas';
  static const more = '/mas';
  static const categories = '/mas/categorias';
  static String categoryEdit(String id) => '/mas/categorias/$id';

  /// Formulario de categoría nueva; con [parentId] es una subcategoría.
  static String categoryNew({CategoryKind? kind, String? parentId}) => Uri(
    path: '/mas/categorias/nueva',
    queryParameters: {'tipo': ?kind?.name, 'padre': ?parentId},
  ).toString();

  static const contacts = '/mas/contactos';
  static const tags = '/mas/etiquetas';
  static const gallery = '/mas/galeria';

  static const accountNew = '/cuentas/nueva';
  static String accountDetail(String id) => '/cuentas/$id';
  static String accountEdit(String id) => '/cuentas/$id/editar';

  static String statementNew(String cardId) => '/cuentas/$cardId/estados/nuevo';
  static String statementDetail(String cardId, String id) => '/cuentas/$cardId/estados/$id';
  static String statementEdit(String cardId, String id) => '/cuentas/$cardId/estados/$id/editar';

  static const transactionNew = '/movimientos/nuevo';
  static String transactionEdit(String id) => '/movimientos/$id';

  /// Formulario de movimiento nuevo; opcionalmente con cuenta, tipo, cuenta
  /// destino, categoría, estado de cuenta y monto (en centavos) ya elegidos.
  static String transactionNewFor({
    String? accountId,
    TransactionType? type,
    String? destinationId,
    String? categoryId,
    String? statementId,
    int? amountMinor,
  }) => Uri(
    path: transactionNew,
    queryParameters: {
      'cuenta': ?accountId,
      'tipo': ?type?.name,
      'destino': ?destinationId,
      'categoria': ?categoryId,
      'estado': ?statementId,
      'monto': ?amountMinor?.toString(),
    },
  ).toString();
}

GoRouter buildRouter({String initialLocation = Routes.home}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.transactions,
              builder: (_, state) => TransactionsScreen(
                params: TransactionFilterParams.fromQuery(state.uri.queryParameters),
              ),
              routes: [
                GoRoute(
                  path: 'nuevo',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => TransactionFormScreen(
                    initialDestinationId: state.uri.queryParameters['destino'],
                    initialCategoryId: state.uri.queryParameters['categoria'],
                    initialStatementId: state.uri.queryParameters['estado'],
                    initialAmountMinor: int.tryParse(state.uri.queryParameters['monto'] ?? ''),
                    initialAccountId: state.uri.queryParameters['cuenta'],
                    initialType: TransactionType.values
                        .asNameMap()[state.uri.queryParameters['tipo']],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => TransactionFormScreen(
                    transactionId: state.pathParameters['id'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.accounts,
              builder: (_, _) => const AccountsScreen(),
              routes: [
                // Los formularios cubren la barra de pestañas.
                GoRoute(
                  path: 'nueva',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => AccountFormScreen(
                    initialType: AccountType.values.asNameMap()[state.uri.queryParameters['tipo']],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => AccountEntryScreen(accountId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'estados/nuevo',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) =>
                          StatementFormScreen(cardId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'estados/:sid',
                      builder: (_, state) => StatementDetailScreen(
                        cardId: state.pathParameters['id']!,
                        statementId: state.pathParameters['sid']!,
                      ),
                    ),
                    GoRoute(
                      path: 'estados/:sid/editar',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) => StatementFormScreen(
                        cardId: state.pathParameters['id']!,
                        statementId: state.pathParameters['sid'],
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':id/editar',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) =>
                      AccountFormScreen(accountId: state.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.more,
              builder: (_, _) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'categorias',
                  builder: (_, _) => const CategoriesScreen(),
                  routes: [
                    // Los formularios cubren la barra de pestañas.
                    GoRoute(
                      path: 'nueva',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) => CategoryFormScreen(
                        initialKind: CategoryKind.values.asNameMap()[state.uri.queryParameters['tipo']],
                        parentId: state.uri.queryParameters['padre'],
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) =>
                          CategoryFormScreen(categoryId: state.pathParameters['id']),
                    ),
                  ],
                ),
                GoRoute(path: 'contactos', builder: (_, _) => const ContactsScreen()),
                GoRoute(path: 'etiquetas', builder: (_, _) => const TagsScreen()),
                if (kDebugMode)
                  GoRoute(
                    path: 'galeria',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const GalleryScreen(),
                  ),
              ],
            ),
          ],
        ),
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
