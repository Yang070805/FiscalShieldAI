import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/colors.dart';
import 'config/theme_schemes.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().configure(host: '127.0.0.1', port: 9527);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FiscalShieldApp());
}

class FiscalShieldApp extends StatefulWidget {
  const FiscalShieldApp({super.key});
  @override
  State<FiscalShieldApp> createState() => _FiscalShieldAppState();
}

class _FiscalShieldAppState extends State<FiscalShieldApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    AppColors.update(themeNotifier.type);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme') ?? 'inkBlue';
    final type = ThemeType.values.firstWhere(
      (t) => t.name == savedTheme,
      orElse: () => ThemeType.inkBlue,
    );
    themeNotifier.setTheme(type);
    final savedFontSize = prefs.getInt('fontSize') ?? 0;
    themeNotifier.setFontSize(savedFontSize);
    final savedFontFamily = prefs.getInt('fontFamily') ?? 0;
    themeNotifier.setFontFamily(savedFontFamily);
    final savedAvatar = prefs.getString('avatar') ?? 'bamboo';
    themeNotifier.setAvatar(savedAvatar);
    final savedCustomAvatar = prefs.getString('customAvatarPath') ?? '';
    if (savedCustomAvatar.isNotEmpty) themeNotifier.setCustomAvatarPath(savedCustomAvatar);
  }

  void _onThemeChange() {
    AppColors.update(themeNotifier.type);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = themeNotifier.fontFamily;
    return DefaultTextStyle(
      style: TextStyle(decoration: TextDecoration.none, fontFamily: ff.isEmpty ? null : ff),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(themeNotifier.textScale),
        ),
        child: MaterialApp(
        title: 'FiscalShield AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/main': (_) => const MainScreen(role: '政务版'),
        },
        ),
      ),
    );
  }
}
