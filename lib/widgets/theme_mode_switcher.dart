import 'package:flutter/material.dart';
import 'package:race_timer/models/app_settings.dart';

class AppThemeModeSwitcher extends StatelessWidget {
  const AppThemeModeSwitcher({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final AppThemeMode selectedMode;
  final ValueChanged<AppThemeMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<AppThemeMode>(
          value: AppThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light Mode'),
        ),
        ButtonSegment<AppThemeMode>(
          value: AppThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark Mode'),
        ),
      ],
      selected: <AppThemeMode>{selectedMode},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
    );
  }
}
