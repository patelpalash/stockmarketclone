import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../../data/services/upstox_auth_service.dart';
import '../../data/services/market_data_service.dart';
import '../../data/services/market_websocket_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => Dio());

  // Core
  sl.registerLazySingleton(() => ApiClient(sl()));

  // Feature - Authentication
  sl.registerLazySingleton(() => UpstoxAuthService());

  // Feature - Market Data
  sl.registerLazySingleton(() => MarketDataService(authService: sl()));
  sl.registerLazySingleton(() => MarketWebSocketService(authService: sl()));

  // Feature - Portfolio

  // Feature - Order Placement

  // Feature - Option Chain
}
