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

/// 路由观察者 — 用于检测页面返回事件
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().restoreToken(); // 从本地恢复Token和后端地址
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

class _FiscalShieldAppState extends State<FiscalShieldApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChange);
    AppColors.update(themeNotifier.type);
    _loadTheme();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // 从后台恢复：刷新Token有效性
        ApiService().restoreToken();
        break;
      case AppLifecycleState.paused:
        // 进入后台：可选保存状态
        break;
      default:
        break;
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
        navigatorObservers: [routeObserver],
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/main': (_) => const MainScreen(role: 'gov'),
        },
        ),
      ),
    );
  }
}
