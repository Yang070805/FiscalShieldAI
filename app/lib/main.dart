import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().configure(host: '127.0.0.1', port: 9527);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FiscalShieldApp());
}

class FiscalShieldApp extends StatelessWidget {
  const FiscalShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '财智哨兵',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainScreen(role: '政务版'),
      },
    );
  }
}
