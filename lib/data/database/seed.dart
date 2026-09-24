import 'package:drift/drift.dart';

import 'app_database.dart';

/// Ids fijos de las categorías del sistema. La lógica de tarjetas y de totales
/// las identifica por id, así que el usuario puede renombrarlas sin romperla.
const kInterestFeesCategoryId = 'system:interest-fees';
const kRefundsCategoryId = 'system:refunds';

class _Seed {
  const _Seed(this.id, this.name, this.kind, this.icon);

  final String id;
  final String name;
  final CategoryKind kind;
  final String icon;
}

const _systemCategories = [
  _Seed(kInterestFeesCategoryId, 'Intereses y cargos', CategoryKind.expense, 'percent'),
  _Seed(kRefundsCategoryId, 'Devoluciones', CategoryKind.income, 'undo'),
];

const _defaultCategories = [
  _Seed('default:salary', 'Sueldo', CategoryKind.income, 'payments'),
  _Seed('default:freelance', 'Freelance', CategoryKind.income, 'laptop'),
  _Seed('default:sales', 'Ventas', CategoryKind.income, 'sell'),
  _Seed('default:interest-earned', 'Intereses ganados', CategoryKind.income, 'savings'),
  _Seed('default:gifts-received', 'Regalos recibidos', CategoryKind.income, 'redeem'),
  _Seed('default:other-income', 'Otros ingresos', CategoryKind.income, 'add_circle'),
  _Seed('default:food', 'Comida', CategoryKind.expense, 'restaurant'),
  _Seed('default:groceries', 'Supermercado', CategoryKind.expense, 'shopping_cart'),
  _Seed('default:transport', 'Transporte', CategoryKind.expense, 'directions_bus'),
  _Seed('default:utilities', 'Servicios', CategoryKind.expense, 'bolt'),
  _Seed('default:housing', 'Vivienda', CategoryKind.expense, 'home'),
  _Seed('default:health', 'Salud', CategoryKind.expense, 'favorite'),
  _Seed('default:education', 'Educación', CategoryKind.expense, 'school'),
  _Seed('default:entertainment', 'Entretenimiento', CategoryKind.expense, 'movie'),
  _Seed('default:shopping', 'Compras', CategoryKind.expense, 'shopping_bag'),
  _Seed('default:subscriptions', 'Suscripciones', CategoryKind.expense, 'subscriptions'),
  _Seed('default:gifts-donations', 'Regalos y donaciones', CategoryKind.expense, 'card_giftcard'),
  _Seed('default:other-expense', 'Otros gastos', CategoryKind.expense, 'more_horiz'),
];

Future<void> _insertAll(AppDatabase db, List<_Seed> seeds, DateTime now) async {
  for (final s in seeds) {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: Value(s.id),
            name: s.name,
            kind: s.kind,
            icon: Value(s.icon),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

/// Garantiza que existan las categorías del sistema. Idempotente: se ejecuta
/// en cada apertura de la base y nunca duplica ni pisa datos del usuario.
Future<void> ensureSystemCategories(AppDatabase db, {DateTime? now}) =>
    _insertAll(db, _systemCategories, now ?? DateTime.now());

/// Siembra las categorías por defecto (y las del sistema). Idempotente.
Future<void> seedDefaults(AppDatabase db, {DateTime? now}) async {
  final n = now ?? DateTime.now();
  await _insertAll(db, _systemCategories, n);
  await _insertAll(db, _defaultCategories, n);
}
