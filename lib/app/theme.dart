import 'package:flutter/material.dart';

const _seed = Color(0xFF1F7A5C);

/// Colores con significado financiero, distintos en claro y oscuro para
/// mantener el contraste.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({required this.income, required this.expense, required this.transfer});

  final Color income;
  final Color expense;
  final Color transfer;

  static const light = MoneyColors(
    income: Color(0xFF1B7F3B),
    expense: Color(0xFFB3261E),
    transfer: Color(0xFF3F5F90),
  );

  static const dark = MoneyColors(
    income: Color(0xFF7AD99A),
    expense: Color(0xFFF2B8B5),
    transfer: Color(0xFFA9C7FF),
  );

  @override
  MoneyColors copyWith({Color? income, Color? expense, Color? transfer}) => MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) => other == null
      ? this
      : MoneyColors(
          income: Color.lerp(income, other.income, t)!,
          expense: Color.lerp(expense, other.expense, t)!,
          transfer: Color.lerp(transfer, other.transfer, t)!,
        );
}

extension MoneyColorsOf on BuildContext {
  MoneyColors get moneyColors =>
      Theme.of(this).extension<MoneyColors>() ?? MoneyColors.light;
}

ThemeData _build(Brightness brightness, MoneyColors money) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [money],
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
  );
}

final lightTheme = _build(Brightness.light, MoneyColors.light);
final darkTheme = _build(Brightness.dark, MoneyColors.dark);
