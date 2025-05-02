import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/services/upstox_auth_service.dart';
import 'data/services/market_data_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize the authentication service
  final authService = UpstoxAuthService();
  await authService.initialize();

  // Test API connectivity to diagnose issues
  if (authService.isAuthenticated) {
    final marketDataService = MarketDataService(authService: authService);
    final bool apiConnected = await marketDataService.testApiConnection();

    if (apiConnected) {
      print('✅ API connection test passed');
    } else {
      print('❌ API connection test failed');
    }
  } else {
    print('⚠️ Not authenticated, skipping API connection test');
  }

  // Initialize dependency injection
  // await di.init();

  runApp(const StockMarketApp());
}

class StockMarketApp extends StatelessWidget {
  const StockMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      // Authentication is now fixed, use HomeScreen
      home: const HomeScreen(),
    );
  }
}
