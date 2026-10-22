import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/theme_mode_toggle.dart';

void main() {
  for (final systemBrightness in Brightness.values) {
    testWidgets('toggle follows effective $systemBrightness system theme', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = systemBrightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      var mode = ThemeMode.system;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  ThemeModeToggle(
                    onChanged: (next) => setState(() => mode = next),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final initiallyDark = systemBrightness == Brightness.dark;
      await tester.tap(find.byTooltip(initiallyDark ? '切换至浅色模式' : '切换至深色模式'));
      await tester.pumpAndSettle();
      expect(mode, initiallyDark ? ThemeMode.light : ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(ThemeModeToggle))).brightness,
        initiallyDark ? Brightness.light : Brightness.dark,
      );
      await tester.tap(find.byType(ThemeModeToggle));
      await tester.pumpAndSettle();
      expect(mode, initiallyDark ? ThemeMode.dark : ThemeMode.light);
      expect(tester.takeException(), isNull);
    });
  }
}
