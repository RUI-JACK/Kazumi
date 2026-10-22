import 'package:flutter/material.dart';
import 'package:kazumi/theme/little_prince_theme.dart';
import 'package:kazumi/utils/constants.dart';

ThemeData buildKazumiTheme({
  required Brightness brightness,
  required String? fontFamily,
  Color? color,
  ColorScheme? colorScheme,
}) {
  // The original default was green. Keep its stored value compatible.
  final isDefault =
      color == null || color == Colors.green || color == littlePrinceSeedColor;
  final scheme =
      colorScheme ??
      (isDefault
          ? littlePrinceColorScheme(brightness)
          : ColorScheme.fromSeed(seedColor: color, brightness: brightness));
  return styleLittlePrinceTheme(
    ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: scheme,
      progressIndicatorTheme: progressIndicatorTheme2024,
      sliderTheme: sliderTheme2024,
      pageTransitionsTheme: pageTransitionsTheme2024,
    ),
  );
}

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
