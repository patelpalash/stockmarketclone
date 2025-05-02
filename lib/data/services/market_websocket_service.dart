import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../../core/constants/app_constants.dart';
import '../../core/utils/api_logger.dart';
import 'upstox_auth_service.dart';

/// Service to handle WebSocket connections for real-time market data
class MarketWebSocketService {
  // WebSocket channels
  WebSocketChannel? _marketDataChannel;
  WebSocketChannel? _portfolioChannel;

  // Stream controllers to broadcast data to listeners
  final StreamController<Map<String, dynamic>> _marketDataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _portfolioStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Authentication service for tokens
  final UpstoxAuthService _authService;

  // Subscription management
  final Set<String> _subscribedInstruments = {};
  bool _isConnected = false;
  Timer? _pingTimer;

  // Getters for streams
  Stream<Map<String, dynamic>> get marketDataStream =>
      _marketDataStreamController.stream;
  Stream<Map<String, dynamic>> get portfolioStream =>
      _portfolioStreamController.stream;
  bool get isConnected => _isConnected;

  MarketWebSocketService({UpstoxAuthService? authService})
      : _authService = authService ?? UpstoxAuthService();

  /// Connect to market data WebSocket
  Future<bool> connectToMarketDataWebSocket() async {
    if (_isConnected) {
      if (kDebugMode) {
        print('Already connected to market data WebSocket');
      }
      return true;
    }

    try {
      // Get auth token from Upstox Auth Service
      final headers = await _authService.getAuthHeaders();
      final token = headers['Authorization']?.split(' ').last;

      if (token == null) {
        if (kDebugMode) {
          print('No authentication token available for WebSocket connection');
        }
        return false;
      }

      // Close existing connection if any
      await disconnectFromMarketDataWebSocket();

      // Construct WebSocket URL with authentication token
      final wsUrl =
          Uri.parse('${AppConstants.upstoxWebSocketUrl}?token=$token');

      if (kDebugMode) {
        print('Connecting to market data WebSocket: $wsUrl');
      }

      // Create WebSocket channel
      _marketDataChannel = WebSocketChannel.connect(wsUrl);

      // Listen for messages
      _marketDataChannel!.stream.listen(
        (message) {
          _handleMarketDataMessage(message);
        },
        onError: (error) {
          ApiLogger.logError('Market data WebSocket error', error);
          if (kDebugMode) {
            print('Market data WebSocket error: $error');
          }
          _isConnected = false;
        },
        onDone: () {
          if (kDebugMode) {
            print('Market data WebSocket connection closed');
          }
          _isConnected = false;
          _pingTimer?.cancel();
        },
      );

      // Set connection status
      _isConnected = true;

      // Start ping timer to keep connection alive
      _startPingTimer();

      return true;
    } catch (e) {
      ApiLogger.logError('Error connecting to market data WebSocket', e);
      if (kDebugMode) {
        print('Error connecting to market data WebSocket: $e');
      }
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from market data WebSocket
  Future<void> disconnectFromMarketDataWebSocket() async {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_marketDataChannel != null) {
      await _marketDataChannel!.sink.close(status.goingAway);
      _marketDataChannel = null;
    }

    _isConnected = false;
    _subscribedInstruments.clear();

    if (kDebugMode) {
      print('Disconnected from market data WebSocket');
    }
  }

  /// Subscribe to market data for specific instruments
  Future<bool> subscribeToMarketData(List<String> instrumentKeys) async {
    if (!_isConnected) {
      final connected = await connectToMarketDataWebSocket();
      if (!connected) {
        return false;
      }
    }

    try {
      // Create subscription message
      final subscriptionMessage = {
        'guid': 'market_data_${DateTime.now().millisecondsSinceEpoch}',
        'method': 'sub',
        'data': {
          'mode': 'full',
          'instrumentKeys': instrumentKeys,
        }
      };

      // Send subscription message
      _marketDataChannel!.sink.add(jsonEncode(subscriptionMessage));

      // Add to subscribed instruments
      _subscribedInstruments.addAll(instrumentKeys);

      if (kDebugMode) {
        print('Subscribed to market data for instruments: $instrumentKeys');
      }

      return true;
    } catch (e) {
      ApiLogger.logError('Error subscribing to market data', e);
      if (kDebugMode) {
        print('Error subscribing to market data: $e');
      }
      return false;
    }
  }

  /// Unsubscribe from market data for specific instruments
  Future<bool> unsubscribeFromMarketData(List<String> instrumentKeys) async {
    if (!_isConnected) {
      return false;
    }

    try {
      // Create unsubscription message
      final unsubscriptionMessage = {
        'guid': 'market_data_${DateTime.now().millisecondsSinceEpoch}',
        'method': 'unsub',
        'data': {
          'instrumentKeys': instrumentKeys,
        }
      };

      // Send unsubscription message
      _marketDataChannel!.sink.add(jsonEncode(unsubscriptionMessage));

      // Remove from subscribed instruments
      _subscribedInstruments.removeAll(instrumentKeys);

      if (kDebugMode) {
        print('Unsubscribed from market data for instruments: $instrumentKeys');
      }

      return true;
    } catch (e) {
      ApiLogger.logError('Error unsubscribing from market data', e);
      if (kDebugMode) {
        print('Error unsubscribing from market data: $e');
      }
      return false;
    }
  }

  /// Connect to portfolio stream WebSocket (for order/position updates)
  Future<bool> connectToPortfolioWebSocket() async {
    try {
      // Get auth token
      final headers = await _authService.getAuthHeaders();
      final token = headers['Authorization']?.split(' ').last;

      if (token == null) {
        if (kDebugMode) {
          print(
              'No authentication token available for portfolio WebSocket connection');
        }
        return false;
      }

      // Close existing connection if any
      await disconnectFromPortfolioWebSocket();

      // Construct WebSocket URL for portfolio
      final wsUrl =
          Uri.parse('${AppConstants.upstoxPortfolioWebSocketUrl}?token=$token');

      if (kDebugMode) {
        print('Connecting to portfolio WebSocket: $wsUrl');
      }

      // Create WebSocket channel for portfolio
      _portfolioChannel = WebSocketChannel.connect(wsUrl);

      // Listen for portfolio messages
      _portfolioChannel!.stream.listen(
        (message) {
          _handlePortfolioMessage(message);
        },
        onError: (error) {
          ApiLogger.logError('Portfolio WebSocket error', error);
          if (kDebugMode) {
            print('Portfolio WebSocket error: $error');
          }
        },
        onDone: () {
          if (kDebugMode) {
            print('Portfolio WebSocket connection closed');
          }
        },
      );

      return true;
    } catch (e) {
      ApiLogger.logError('Error connecting to portfolio WebSocket', e);
      if (kDebugMode) {
        print('Error connecting to portfolio WebSocket: $e');
      }
      return false;
    }
  }

  /// Disconnect from portfolio WebSocket
  Future<void> disconnectFromPortfolioWebSocket() async {
    if (_portfolioChannel != null) {
      await _portfolioChannel!.sink.close(status.goingAway);
      _portfolioChannel = null;
    }

    if (kDebugMode) {
      print('Disconnected from portfolio WebSocket');
    }
  }

  /// Handle incoming messages from market data WebSocket
  void _handleMarketDataMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;

        // Log the received message for debugging
        if (kDebugMode) {
          print(
              'Received market data: ${data.toString().substring(0, min(100, data.toString().length))}...');
        }

        // Add to stream
        _marketDataStreamController.add(data);
      }
    } catch (e) {
      ApiLogger.logError('Error handling market data message', e);
      if (kDebugMode) {
        print('Error handling market data message: $e');
      }
    }
  }

  /// Handle incoming messages from portfolio WebSocket
  void _handlePortfolioMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;

        // Log the received message for debugging
        if (kDebugMode) {
          print(
              'Received portfolio update: ${data.toString().substring(0, min(100, data.toString().length))}...');
        }

        // Add to portfolio stream
        _portfolioStreamController.add(data);
      }
    } catch (e) {
      ApiLogger.logError('Error handling portfolio message', e);
      if (kDebugMode) {
        print('Error handling portfolio message: $e');
      }
    }
  }

  /// Start ping timer to keep WebSocket connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();

    // Send ping every 30 seconds to keep connection alive
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _marketDataChannel != null) {
        try {
          final pingMessage = {
            'guid': 'ping_${DateTime.now().millisecondsSinceEpoch}',
            'method': 'heartbeat',
          };

          _marketDataChannel!.sink.add(jsonEncode(pingMessage));

          if (kDebugMode) {
            print('Sent heartbeat ping to market data WebSocket');
          }
        } catch (e) {
          ApiLogger.logError('Error sending ping', e);
          if (kDebugMode) {
            print('Error sending ping: $e');
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Dispose method to clean up resources
  void dispose() {
    disconnectFromMarketDataWebSocket();
    disconnectFromPortfolioWebSocket();
    _marketDataStreamController.close();
    _portfolioStreamController.close();
  }

  /// Helper method to get min value
  int min(int a, int b) => a < b ? a : b;
}
