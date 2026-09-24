import 'package:flutter/material.dart';

import 'tokens.dart';

const appFontFamily = 'Inter';

/// Cifras de ancho fijo: los montos alinean sus dígitos en columnas.
final _tabular = [FontFeature.tabularFigures()];

/// Estilos de texto de la app, ya con su color. Los montos llevan cifras
/// tabulares.
class AppTypography {
  const AppTypography(this._c);

  final AppColors _c;

  TextStyle _s(
    double size,
    FontWeight w,
    Color color, {
    double? height,
    double? spacing,
    bool tab = false,
  }) => TextStyle(
    fontFamily: appFontFamily,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
    fontFeatures: tab ? _tabular : null,
  );

  // Montos.
  TextStyle get amountXL =>
      _s(40, FontWeight.w700, _c.textPrimary, height: 1.1, spacing: -1, tab: true);
  TextStyle get amountL =>
      _s(28, FontWeight.w700, _c.textPrimary, height: 1.15, spacing: -0.5, tab: true);
  TextStyle get amountM => _s(16, FontWeight.w600, _c.textPrimary, height: 1.25, tab: true);
  TextStyle get amountS => _s(14, FontWeight.w600, _c.textPrimary, height: 1.25, tab: true);

  // Texto.
  TextStyle get title => _s(22, FontWeight.w700, _c.textPrimary, height: 1.2, spacing: -0.3);
  TextStyle get heading => _s(17, FontWeight.w600, _c.textPrimary, height: 1.3);
  TextStyle get body => _s(15, FontWeight.w400, _c.textPrimary, height: 1.4);
  TextStyle get bodyStrong => _s(15, FontWeight.w500, _c.textPrimary, height: 1.4);
  TextStyle get caption => _s(13, FontWeight.w400, _c.textSecondary, height: 1.35);
  TextStyle get label => _s(12, FontWeight.w500, _c.textSecondary, height: 1.3, spacing: 0.2);
  TextStyle get button => _s(16, FontWeight.w600, _c.onAccent, height: 1.2);
}

extension AppTypographyOf on BuildContext {
  AppTypography get text => AppTypography(colors);
}
