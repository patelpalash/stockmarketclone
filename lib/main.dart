import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'data/services/upstox_auth_service.dart';
import 'data/services/market_data_service.dart';
import 'data/services/market_websocket_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize dependency injection
  await di.init();

  // Get auth service from DI
  final authService = di.sl<UpstoxAuthService>();
  await authService.initialize();

  // Test API connectivity to diagnose issues
  if (authService.isAuthenticated) {
    final marketDataService = di.sl<MarketDataService>();
    final bool apiConnected = await marketDataService.testApiConnection();

    if (apiConnected) {
      print('✅ API connection test passed');
    } else {
      print('❌ API connection test failed');
    }
  } else {
    print('⚠️ Not authenticated, skipping API connection test');
  }

  // Register lifecycle observer to manage WebSocket connections
  final webSocketService = di.sl<MarketWebSocketService>();
  final lifecycleObserver = StockMarketAppLifecycleObserver(webSocketService);
  WidgetsBinding.instance.addObserver(lifecycleObserver);

  runApp(const StockMarketApp());
}

class StockMarketApp extends StatelessWidget {
  const StockMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide globally available services
        Provider<UpstoxAuthService>.value(value: di.sl<UpstoxAuthService>()),
        Provider<MarketDataService>.value(value: di.sl<MarketDataService>()),
        Provider<MarketWebSocketService>.value(
            value: di.sl<MarketWebSocketService>()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

// Close the WebSocket connections when the app is closed
class StockMarketAppLifecycleObserver extends WidgetsBindingObserver {
  final MarketWebSocketService _webSocketService;

  StockMarketAppLifecycleObserver(this._webSocketService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Close WebSocket connections when app goes to background
      _webSocketService.disconnectFromMarketDataWebSocket();
      _webSocketService.disconnectFromPortfolioWebSocket();
    } else if (state == AppLifecycleState.resumed) {
      // Reconnect WebSocket when app comes to foreground if needed
      // The widget will reconnect automatically when needed
    }
  }
}
