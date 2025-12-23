import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';

/// Theme toggle button for app bar
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return IconButton(
      icon: Icon(themeMode.icon),
      tooltip: 'Theme: ${themeMode.displayName}',
      onPressed: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
    );
  }
}

/// Theme selector dialog
class ThemeSelectorDialog extends ConsumerWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeProvider);

    return AlertDialog(
      title: const Text('Choose Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppThemeMode.values.map((mode) {
          return RadioListTile<AppThemeMode>(
            title: Text(mode.displayName),
            secondary: Icon(mode.icon),
            value: mode,
            groupValue: currentMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeProvider.notifier).setTheme(value);
                Navigator.of(context).pop();
              }
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ThemeSelectorDialog(),
    );
  }
}

/// Theme toggle card for settings
class ThemeToggleCard extends ConsumerWidget {
  const ThemeToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Card(
      child: ListTile(
        leading: Icon(themeMode.icon),
        title: const Text('Theme'),
        subtitle: Text(themeMode.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ThemeSelectorDialog.show(context),
      ),
    );
  }
}

/// Segmented theme selector
class ThemeSegmentedButton extends ConsumerWidget {
  const ThemeSegmentedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return SegmentedButton<AppThemeMode>(
      segments: AppThemeMode.values.map((mode) {
        return ButtonSegment<AppThemeMode>(
          value: mode,
          icon: Icon(mode.icon),
          label: Text(mode.displayName),
        );
      }).toList(),
      selected: {themeMode},
      onSelectionChanged: (selection) {
        ref.read(themeProvider.notifier).setTheme(selection.first);
      },
    );
  }
}

/// Compact theme toggle (cycles through modes)
class CompactThemeToggle extends ConsumerWidget {
  final bool showLabel;

  const CompactThemeToggle({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    if (showLabel) {
      return TextButton.icon(
        icon: Icon(themeMode.icon),
        label: Text(themeMode.displayName),
        onPressed: () {
          ref.read(themeProvider.notifier).toggleTheme();
        },
      );
    }

    return IconButton(
      icon: Icon(themeMode.icon),
      tooltip: themeMode.displayName,
      onPressed: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
    );
  }
}
