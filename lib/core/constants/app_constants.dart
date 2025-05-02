class AppConstants {
  // App Info
  static const String appName = 'Stock Market App';
  static const String appVersion = '1.0.0';

  // API Constants
  static const String apiKey = '46ebb484-3238-40b7-8849-6d7f72d8338d';
  static const String upstoxBaseUrl = 'https://api.upstox.com/v2';
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  static const bool enableMockData = false; // Set to false for real API data

  // WebSocket URLs
  static const String upstoxWebSocketUrl =
      'wss://api.upstox.com/feed/market-data/ws';
  static const String upstoxPortfolioWebSocketUrl =
      'wss://api.upstox.com/feed/portfolio/ws';

  // Authentication
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  // Hive Boxes
  static const String userBox = 'user_box';
  static const String stocksBox = 'stocks_box';
  static const String watchlistBox = 'watchlist_box';
  static const String portfolioBox = 'portfolio_box';

  // Routes
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String stockDetailRoute = '/stock-detail';
  static const String portfolioRoute = '/portfolio';
  static const String optionChainRoute = '/option-chain';
  static const String profileRoute = '/profile';
  static const String ordersRoute = '/orders';

  // App Settings
  static const int defaultChartInterval = 5; // 5 minute chart by default
  static const int stockListPageSize = 20;
  static const int maxWatchlistItems = 50;

  // Market Hours (IST)
  static const String marketOpenTime = '09:15';
  static const String marketCloseTime = '15:30';

  // NSE Indices
  static const String nifty50 = 'NIFTY 50';
  static const String bankNifty = 'NIFTY BANK';
  static const String niftyIT = 'NIFTY IT';
  static const String niftyFinService = 'NIFTY FIN SERVICE';

  // Order Types
  static const String marketOrder = 'MARKET';
  static const String limitOrder = 'LIMIT';
  static const String stopLossOrder = 'SL';
  static const String stopLossMarketOrder = 'SL-M';

  // Product Types
  static const String intraday = 'MIS';
  static const String delivery = 'CNC';
  static const String optionIntraday = 'NRML';

  // Option Types
  static const String callOption = 'CE';
  static const String putOption = 'PE';

  // Expiry Cycles
  static const String weekly = 'Weekly';
  static const String monthly = 'Monthly';

  // Error Messages
  static const String generalErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String timeoutErrorMessage =
      'Request timed out. Please try again.';
  static const String authErrorMessage =
      'Authentication failed. Please login again.';
  static const String dataParsingErrorMessage =
      'Error processing data. Please try again.';

  // Common Stocks
  static const List<String> popularStocks = [
    'RELIANCE',
    'TCS',
    'HDFCBANK',
    'INFY',
    'ICICIBANK',
    'HINDUNILVR',
    'ITC',
    'SBIN',
    'BHARTIARTL',
    'KOTAKBANK'
  ];
}
