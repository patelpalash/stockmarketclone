import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../data/services/market_websocket_service.dart';
import '../../domain/entities/stock.dart';
import '../../core/constants/app_constants.dart';

class RealTimeStockTicker extends StatefulWidget {
  final String symbol;
  final String instrumentKey;
  final double lastPrice;
  final bool showDetailedView;

  const RealTimeStockTicker({
    Key? key,
    required this.symbol,
    required this.instrumentKey,
    required this.lastPrice,
    this.showDetailedView = false,
  }) : super(key: key);

  @override
  State<RealTimeStockTicker> createState() => _RealTimeStockTickerState();
}

class _RealTimeStockTickerState extends State<RealTimeStockTicker> {
  late MarketWebSocketService _webSocketService;
  late StreamSubscription<Map<String, dynamic>> _subscription;

  // State variables for stock data
  double _currentPrice = 0.0;
  double _priceChange = 0.0;
  double _percentChange = 0.0;
  double _dayHigh = 0.0;
  double _dayLow = 0.0;
  int _volume = 0;
  DateTime _lastUpdateTime = DateTime.now();

  // Animation variables
  Color _priceChangeColor = Colors.grey;
  bool _flashAnimation = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _currentPrice = widget.lastPrice;

    // Access the WebSocket service from provider
    _webSocketService =
        Provider.of<MarketWebSocketService>(context, listen: false);

    // Subscribe to this stock's updates
    _subscribeToStockUpdates();
  }

  @override
  void didUpdateWidget(RealTimeStockTicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If instrument key changed, re-subscribe
    if (oldWidget.instrumentKey != widget.instrumentKey) {
      _unsubscribeFromStockUpdates();
      _subscribeToStockUpdates();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromStockUpdates();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _subscribeToStockUpdates() async {
    // Connect to WebSocket if not already connected
    if (!_webSocketService.isConnected) {
      await _webSocketService.connectToMarketDataWebSocket();
    }

    // Subscribe to this stock's updates
    await _webSocketService.subscribeToMarketData([widget.instrumentKey]);

    // Listen to market data stream
    _subscription =
        _webSocketService.marketDataStream.listen(_handleMarketData);

    if (kDebugMode) {
      print(
          'Subscribed to real-time updates for ${widget.symbol} (${widget.instrumentKey})');
    }
  }

  void _unsubscribeFromStockUpdates() {
    // Cancel subscription
    _subscription.cancel();

    // Unsubscribe from this stock
    _webSocketService.unsubscribeFromMarketData([widget.instrumentKey]);

    if (kDebugMode) {
      print('Unsubscribed from real-time updates for ${widget.symbol}');
    }
  }

  void _handleMarketData(Map<String, dynamic> data) {
    // Check if this update is for our stock
    if (data.containsKey('feeds') &&
        data['feeds'].containsKey(widget.instrumentKey.replaceAll('|', ':'))) {
      final stockData =
          data['feeds'][widget.instrumentKey.replaceAll('|', ':')];

      if (stockData != null) {
        // Get previous price for comparison
        final previousPrice = _currentPrice;

        // Update state with new data
        setState(() {
          if (stockData.containsKey('ltpc')) {
            _currentPrice = (stockData['ltpc'] as num).toDouble();
          } else if (stockData.containsKey('ltp')) {
            _currentPrice = (stockData['ltp'] as num).toDouble();
          }

          if (stockData.containsKey('c')) {
            _priceChange = (stockData['c'] as num).toDouble();
          }

          if (stockData.containsKey('cp')) {
            _percentChange = (stockData['cp'] as num).toDouble();
          }

          if (stockData.containsKey('high')) {
            _dayHigh = (stockData['high'] as num).toDouble();
          }

          if (stockData.containsKey('low')) {
            _dayLow = (stockData['low'] as num).toDouble();
          }

          if (stockData.containsKey('v')) {
            _volume = (stockData['v'] as num).toInt();
          }

          _lastUpdateTime = DateTime.now();

          // Determine color based on price movement
          if (_currentPrice > previousPrice) {
            _priceChangeColor = Colors.green;
            _triggerFlashAnimation(Colors.green.withOpacity(0.3));
          } else if (_currentPrice < previousPrice) {
            _priceChangeColor = Colors.red;
            _triggerFlashAnimation(Colors.red.withOpacity(0.3));
          }
        });
      }
    }
  }

  void _triggerFlashAnimation(Color flashColor) {
    // Cancel any existing timer
    _flashTimer?.cancel();

    // Trigger flash animation
    setState(() {
      _flashAnimation = true;
    });

    // Reset flash after brief delay
    _flashTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _flashAnimation = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Basic view just shows current price with color indication
    if (!widget.showDetailedView) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _flashAnimation
              ? _priceChangeColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '₹${_currentPrice.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _priceChangeColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Detailed view shows more information
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _flashAnimation
            ? _priceChangeColor.withOpacity(0.1)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock symbol and current price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.symbol,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${_currentPrice.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: _priceChangeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Price change
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Change',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              Row(
                children: [
                  Icon(
                    _priceChange >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: _priceChangeColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '₹${_priceChange.abs().toStringAsFixed(2)} (${_percentChange.abs().toStringAsFixed(2)}%)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _priceChangeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24),

          // Day's range and volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day\'s Range',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_dayLow.toStringAsFixed(2)} - ₹${_dayHigh.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Volume',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatVolume(_volume),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Last updated time
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Last updated: ${_formatTime(_lastUpdateTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format volume for display (e.g., 1.2M instead of 1200000)
  String _formatVolume(int volume) {
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(1)}Cr';
    } else if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(1)}L';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    } else {
      return volume.toString();
    }
  }

  // Format time for display
  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
