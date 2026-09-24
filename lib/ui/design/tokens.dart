import 'package:flutter/material.dart';

/// Espaciados (múltiplos de 4).
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Margen lateral de las pantallas.
  static const gutter = 20.0;
}

/// Radios de esquina.
abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Tamaño mínimo de cualquier zona táctil.
const kMinTap = 48.0;

/// Paleta de la app. Un solo color de acento; el resto es neutro. Los colores
/// de ingreso, gasto y transferencia son discretos y se usan solo en montos e
/// íconos, nunca como fondo de superficies grandes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.danger,
  });

  /// Fondo de pantalla.
  final Color background;

  /// Tarjetas, hojas y barras.
  final Color surface;

  /// Campos, chips y fondos secundarios sobre [surface] o [background].
  final Color surfaceAlt;

  /// Bordes y separadores.
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color danger;

  static const light = AppColors(
    background: Color(0xFFF6F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEFF3),
    border: Color(0xFFE4E4EA),
    textPrimary: Color(0xFF111114),
    textSecondary: Color(0xFF5F5F6B),
    textTertiary: Color(0xFF8A8A96),
    accent: Color(0xFF4338CA),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE9E8FB),
    income: Color(0xFF15803D),
    expense: Color(0xFFC2413B),
    transfer: Color(0xFF4B5E7E),
    danger: Color(0xFFB3261E),
  );

  static const dark = AppColors(
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF141417),
    surfaceAlt: Color(0xFF1E1E23),
    border: Color(0xFF2A2A31),
    textPrimary: Color(0xFFF3F3F5),
    textSecondary: Color(0xFFA6A6B2),
    textTertiary: Color(0xFF7B7B88),
    accent: Color(0xFF9B95FF),
    onAccent: Color(0xFF0E0B33),
    accentSoft: Color(0xFF25234A),
    income: Color(0xFF4CC38A),
    expense: Color(0xFFF08A85),
    transfer: Color(0xFF9DB0CF),
    danger: Color(0xFFFF8A80),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      income: l(income, other.income),
      expense: l(expense, other.expense),
      transfer: l(transfer, other.transfer),
      danger: l(danger, other.danger),
    );
  }
}

extension AppColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
