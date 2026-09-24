import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/credit_card_repository.dart';
import '../data/repositories/debt_repository.dart';
import '../data/repositories/models.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/clock.dart';

// Las pantallas importan solo este archivo: además de los providers, traen
// las entidades y modelos de la capa de datos que necesitan.
export '../data/database/app_database.dart';
export '../data/repositories/models.dart';
export 'day.dart';

/// Base de datos única de la app. Se crea en `main()` y se inyecta con
/// `appDatabaseProvider.overrideWithValue(...)`; en tests, con una base en
/// memoria.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider debe sobrescribirse'),
);

/// Reloj de la app. Los tests lo sobrescriben con un reloj falso.
final nowProvider = Provider<Now>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// Repositorios. Las escrituras se llaman directo: `ref.read(xRepositoryProvider)`.
// ---------------------------------------------------------------------------

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final categoryRepositoryProvider = Provider(
  (ref) => CategoryRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final contactRepositoryProvider = Provider(
  (ref) => ContactRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final tagRepositoryProvider = Provider(
  (ref) => TagRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final transactionRepositoryProvider = Provider(
  (ref) => TransactionRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final debtRepositoryProvider = Provider(
  (ref) => DebtRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

final creditCardRepositoryProvider = Provider(
  (ref) => CreditCardRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

// ---------------------------------------------------------------------------
// Lecturas reactivas
// ---------------------------------------------------------------------------

/// Cuentas con su saldo; el parámetro indica si se incluyen las archivadas.
final accountBalancesProvider = StreamProvider.autoDispose
    .family<List<AccountBalance>, bool>(
      (ref, includeArchived) => ref
          .watch(accountRepositoryProvider)
          .watchBalances(includeArchived: includeArchived),
    );

final accountBalanceProvider = StreamProvider.autoDispose
    .family<AccountBalance, String>(
      (ref, id) => ref.watch(accountRepositoryProvider).watchBalance(id),
    );

/// Todas las categorías, archivadas incluidas (para poder rotular movimientos
/// viejos); los selectores filtran por tipo y `isArchived`.
final categoriesProvider = StreamProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watch(includeArchived: true),
);

final contactsProvider = StreamProvider.autoDispose<List<Contact>>(
  (ref) => ref.watch(contactRepositoryProvider).watch(includeArchived: true),
);

final tagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagRepositoryProvider).watch(includeArchived: true),
);

/// Movimientos según el filtro (que tiene igualdad por valor).
final transactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, TransactionFilter>(
      (ref, filter) => ref.watch(transactionRepositoryProvider).watch(filter),
    );

/// Etiquetas de un movimiento.
final transactionTagsProvider = FutureProvider.autoDispose
    .family<List<Tag>, String>(
      (ref, transactionId) =>
          ref.watch(tagRepositoryProvider).tagsOf(transactionId),
    );
