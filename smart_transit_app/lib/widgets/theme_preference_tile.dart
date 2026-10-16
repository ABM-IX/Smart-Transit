import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemePreferenceTile extends StatelessWidget {
  const ThemePreferenceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<AppThemeProvider>();
    return ListTile(
      leading: Icon(
        themeProvider.themeMode == ThemeMode.system
            ? Icons.brightness_auto_outlined
            : themeProvider.themeMode == ThemeMode.dark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('App Appearance'),
      subtitle: const Text('Choose System Default, Light, or Dark'),
      trailing: DropdownButton<ThemeMode>(
        value: themeProvider.themeMode,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('System Default'),
          ),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (mode) {
          if (mode != null) themeProvider.setThemeMode(mode);
        },
      ),
    );
  }
}
