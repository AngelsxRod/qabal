import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';

/// Ícono, color e información visual de una categoría.
@immutable
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Los ids de ícono con que se siembran las categorías (`seed.dart`) son
/// nombres de Material Icons; aquí se traducen a su variante redondeada.
const _icons = <String, IconData>{
  'percent': Icons.percent_rounded,
  'undo': Icons.undo_rounded,
  'payments': Icons.payments_rounded,
  'laptop': Icons.laptop_mac_rounded,
  'sell': Icons.sell_rounded,
  'savings': Icons.savings_rounded,
  'redeem': Icons.redeem_rounded,
  'add_circle': Icons.add_circle_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping_cart': Icons.shopping_cart_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'bolt': Icons.bolt_rounded,
  'home': Icons.home_rounded,
  'favorite': Icons.favorite_rounded,
  'school': Icons.school_rounded,
  'movie': Icons.movie_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'more_horiz': Icons.more_horiz_rounded,
};

/// Ícono para el nombre guardado en la categoría; uno genérico si no se
/// conoce.
IconData categoryIcon(String? name) => _icons[name] ?? Icons.category_rounded;

/// Ícono de "sin categoría" y de las transferencias.
const uncategorizedIcon = Icons.label_outline_rounded;
const transferIcon = Icons.swap_horiz_rounded;

/// Colores medios, con saturación baja para que convivan sin gritar.
const _palette = <Color>[
  Color(0xFFE07B39), // naranja
  Color(0xFF2F9E6E), // verde
  Color(0xFF3B82C4), // azul
  Color(0xFFD4A017), // ámbar
  Color(0xFF8B5CC7), // violeta
  Color(0xFFD9546B), // rosa
  Color(0xFF4F63C9), // índigo
  Color(0xFFC04FA0), // magenta
  Color(0xFF1F9AA8), // turquesa
  Color(0xFF7A8594), // gris azulado
];

const _byId = <String, int>{
  'default:food': 0,
  'default:groceries': 1,
  'default:transport': 2,
  'default:utilities': 3,
  'default:housing': 4,
  'default:health': 5,
  'default:education': 6,
  'default:entertainment': 7,
  'default:shopping': 8,
  'default:subscriptions': 4,
  'default:gifts-donations': 5,
  'default:other-expense': 9,
  'default:salary': 1,
  'default:freelance': 2,
  'default:sales': 0,
  'default:interest-earned': 8,
  'default:gifts-received': 5,
  'default:other-income': 9,
  'system:interest-fees': 3,
  'system:refunds': 8,
};

/// Color base de una categoría: el que eligió el usuario, el asignado a las
/// sembradas o uno estable derivado de su id.
Color categoryBaseColor(String id, {int? colorValue}) {
  if (colorValue != null) return Color(colorValue);
  final fixed = _byId[id];
  if (fixed != null) return _palette[fixed];
  return _palette[id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) % _palette.length];
}

/// Aclara el color en modo oscuro para conservar el contraste sobre fondos
/// casi negros.
Color adaptToBrightness(Color color, Brightness brightness) {
  if (brightness == Brightness.light) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 0.85)).toColor();
}

CategoryStyle categoryStyleFor(Category? category, Brightness brightness) {
  if (category == null) {
    return CategoryStyle(uncategorizedIcon, adaptToBrightness(_palette[9], brightness));
  }
  return CategoryStyle(
    categoryIcon(category.icon),
    adaptToBrightness(categoryBaseColor(category.id, colorValue: category.colorValue), brightness),
  );
}
