import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  final Function(Locale) onLocaleChanged;
  final Locale currentLocale;

  const LanguageSelector({
    super.key,
    required this.onLocaleChanged,
    required this.currentLocale,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.globe,
            color: CupertinoColors.activeBlue,
            size: 20.0,
          ),
          const SizedBox(width: 4),
          Text(
            currentLocale.languageCode == 'zh' ? '中文' : 'English',
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
      onPressed: () {
        _showLanguageSelector(context);
      },
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            currentLocale.languageCode == 'zh' ? '选择语言' : 'Select Language',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onLocaleChanged(const Locale('zh', ''));
              },
              child: const Text('中文'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onLocaleChanged(const Locale('en', ''));
              },
              child: const Text('English'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              currentLocale.languageCode == 'zh' ? '取消' : 'Cancel',
            ),
          ),
        );
      },
    );
  }
}