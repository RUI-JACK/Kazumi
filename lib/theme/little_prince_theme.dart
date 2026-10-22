import 'package:flutter/material.dart';

/// Colours from the user-supplied Little Prince illustration.
/// Kept separate from storage, controllers and playback code.
const littlePrinceSeedColor = Color(0xFF596A45);
const littlePrinceArtwork = 'assets/images/little_prince_theme.jpg';
const littlePrinceDarkArtwork = 'assets/images/little_prince_night.jpg';

ColorScheme littlePrinceColorScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ColorScheme.fromSeed(
    seedColor: littlePrinceSeedColor,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFE8CF7B) : littlePrinceSeedColor,
    onPrimary: dark ? const Color(0xFF332A10) : Colors.white,
    primaryContainer: dark ? const Color(0xFF4E4324) : const Color(0xFFE1EBCF),
    onPrimaryContainer: dark
        ? const Color(0xFFF8E6AC)
        : const Color(0xFF354426),
    secondary: dark ? const Color(0xFFE8DA8C) : const Color(0xFF6A5F22),
    onSecondary: dark ? const Color(0xFF37310D) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF504A22)
        : const Color(0xFFF5EDB0),
    onSecondaryContainer: dark
        ? const Color(0xFFF5EDB0)
        : const Color(0xFF4B4317),
    tertiary: dark ? const Color(0xFFD2C5DE) : const Color(0xFF6F647D),
    onTertiary: dark ? const Color(0xFF382C45) : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF4E425B) : const Color(0xFFEBE5F1),
    onTertiaryContainer: dark
        ? const Color(0xFFEBE5F1)
        : const Color(0xFF4E415E),
    surface: dark ? const Color(0xFF0E1629) : const Color(0xFFF4F8F2),
    onSurface: dark ? const Color(0xFFEBE9E3) : const Color(0xFF333D32),
    onSurfaceVariant: dark ? const Color(0xFFBDC4D4) : const Color(0xFF596453),
    surfaceContainerLowest: dark
        ? const Color(0xFF0A1120)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: dark
        ? const Color(0xFF151E35)
        : const Color(0xFFECF1E6),
    surfaceContainer: dark ? const Color(0xFF1B2540) : const Color(0xFFE6EDDD),
    surfaceContainerHigh: dark
        ? const Color(0xFF232E49)
        : const Color(0xFFDEE7D4),
    surfaceContainerHighest: dark
        ? const Color(0xFF2C3854)
        : const Color(0xFFD5DFC9),
    outline: dark ? const Color(0xFF909CB1) : const Color(0xFF7A8671),
    outlineVariant: dark ? const Color(0xFF3D4862) : const Color(0xFFD1DCC7),
  );
}

/// Component styling also works with the user's custom and dynamic colours.
ThemeData styleLittlePrinceTheme(ThemeData base) {
  final c = base.colorScheme;
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: c.surface,
    canvasColor: c.surface,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: c.surface,
      foregroundColor: c.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainerLowest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: c.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: base.textTheme.labelMedium?.fontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? c.onSurface
              : c.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surfaceContainerLow,
      indicatorColor: c.secondaryContainer,
      selectedIconTheme: IconThemeData(color: c.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: c.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        fontFamily: base.textTheme.labelMedium?.fontFamily,
        color: c.onSurface,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: base.textTheme.labelMedium?.fontFamily,
        color: c.onSurfaceVariant,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primaryContainer,
      foregroundColor: c.onPrimaryContainer,
      elevation: 0,
      hoverElevation: 1,
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: c.primaryContainer,
        foregroundColor: c.onPrimaryContainer,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surfaceContainerLow,
      selectedColor: c.secondaryContainer,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant.withValues(alpha: 0.5),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: c.onInverseSurface, fontSize: 12),
    ),
  );
}
