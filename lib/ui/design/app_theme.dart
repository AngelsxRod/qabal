import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData _build(Brightness brightness, AppColors c) {
  final t = AppTypography(c);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.accent,
    secondary: c.textSecondary,
    onSecondary: c.surface,
    secondaryContainer: c.surfaceAlt,
    onSecondaryContainer: c.textPrimary,
    error: c.danger,
    onError: c.surface,
    surface: c.surface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    outline: c.textTertiary,
    outlineVariant: c.border,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceAlt,
    surfaceContainerHighest: c.surfaceAlt,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.md),
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: appFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    extensions: [c],
    splashFactory: InkRipple.splashFactory,
    splashColor: c.accent.withValues(alpha: 0.06),
    highlightColor: c.accent.withValues(alpha: 0.04),
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    textTheme: TextTheme(
      headlineMedium: t.title,
      titleLarge: t.title,
      titleMedium: t.heading,
      titleSmall: t.bodyStrong,
      bodyLarge: t.body,
      bodyMedium: t.body,
      bodySmall: t.caption,
      labelLarge: t.bodyStrong,
      labelMedium: t.label,
      labelSmall: t.label,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.heading,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 1)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
      labelStyle: t.caption,
      floatingLabelStyle: t.label.copyWith(color: c.accent),
      hintStyle: t.body.copyWith(color: c.textTertiary),
      helperStyle: t.caption,
      errorStyle: t.caption.copyWith(color: c.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        disabledBackgroundColor: c.surfaceAlt,
        disabledForegroundColor: c.textTertiary,
        minimumSize: const Size(kMinTap, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        elevation: 0,
        textStyle: t.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md + 2)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        minimumSize: const Size(kMinTap, kMinTap),
        textStyle: t.bodyStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size(kMinTap, kMinTap),
        side: BorderSide(color: c.border),
        textStyle: t.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTap, kMinTap),
        foregroundColor: c.textPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    ),
    dialogTheme: DialogThemeData(
      insetPadding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xl),
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      titleTextStyle: t.heading,
      contentTextStyle: t.body.copyWith(color: c.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      dragHandleColor: c.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.border),
      ),
      textStyle: t.body,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.textPrimary,
      contentTextStyle: t.body.copyWith(color: c.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceAlt,
      selectedColor: c.accentSoft,
      side: BorderSide.none,
      labelStyle: t.bodyStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      titleTextStyle: t.bodyStrong,
      subtitleTextStyle: t.caption,
      iconColor: c.textSecondary,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: t.body),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

final lightTheme = _build(Brightness.light, AppColors.light);
final darkTheme = _build(Brightness.dark, AppColors.dark);
