import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:patch_maker/l10n/app_localizations.dart';
import 'package:patch_maker/patch_maker/patch_maker_widget.dart';
import 'package:patch_maker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('zh', '');
  ThemeMode _themeMode = ThemeMode.system;
  final AppTheme _appTheme = AppTheme();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final String languageCode = prefs.getString('languageCode') ?? 'zh';
      _locale = Locale(languageCode, '');

      final String themeModeString = prefs.getString('themeMode') ?? 'system';
      switch (themeModeString) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      _appTheme.themeMode = _themeMode;
    });
  }

  void _setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
  }

  void _setThemeMode(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
      _appTheme.themeMode = themeMode;
    });
    final prefs = await SharedPreferences.getInstance();
    String themeModeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      default:
        themeModeString = 'system';
        break;
    }
    await prefs.setString('themeMode', themeModeString);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: _appTheme.getTheme(context),
      locale: _locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => PatchMakerWidget(
          onLocaleChanged: _setLocale,
          currentLocale: _locale,
          onThemeChanged: _setThemeMode,
          currentThemeMode: _themeMode,
        ),
      },
      // home: Builder(
      //   builder: (context) => PatchMakerWidget(
      //     onLocaleChanged: _setLocale,
      //     currentLocale: _locale,
      //     onThemeChanged: _setThemeMode,
      //     currentThemeMode: _themeMode,
      //   ),
      // ),
    );
  }
}
