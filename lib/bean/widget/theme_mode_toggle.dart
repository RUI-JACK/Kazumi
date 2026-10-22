import 'package:flutter/material.dart';

/// Switches to the opposite of the currently displayed brightness.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key, required this.onChanged});

  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? '切换至浅色模式' : '切换至深色模式',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => onChanged(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
