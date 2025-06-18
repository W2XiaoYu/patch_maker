import 'package:flutter/cupertino.dart';
import 'package:patch_maker/l10n/app_localizations.dart';
import 'package:patch_maker/theme/app_theme.dart';

class ThemeSelector extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const ThemeSelector({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme().isDarkMode(context);
    
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
            color: CupertinoTheme.of(context).primaryColor,
            size: 20.0,
          ),
        ],
      ),
      onPressed: () {
        _showThemeSelector(context);
      },
    );
  }

  void _showThemeSelector(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(localizations.selectTheme),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onThemeChanged(ThemeMode.light);
              },
              child: Text(localizations.lightTheme),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onThemeChanged(ThemeMode.dark);
              },
              child: Text(localizations.darkTheme),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onThemeChanged(ThemeMode.system);
              },
              child: Text(localizations.systemTheme),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(localizations.cancel),
          ),
        );
      },
    );
  }
}