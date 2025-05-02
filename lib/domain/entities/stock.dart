class Stock {
  final String symbol;
  final String companyName;
  final double lastPrice;
  final double change;
  final double percentChange;
  final double open;
  final double high;
  final double low;
  final double previousClose;
  final int volume;
  final String lastUpdateTime;

  Stock({
    required this.symbol,
    required this.companyName,
    required this.lastPrice,
    required this.change,
    required this.percentChange,
    required this.open,
    required this.high,
    required this.low,
    required this.previousClose,
    required this.volume,
    required this.lastUpdateTime,
  });

  bool get isPositive => change >= 0;

  // Create a stock from JSON data
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] as String,
      companyName: json['companyName'] as String,
      lastPrice: (json['lastPrice'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      percentChange: (json['percentChange'] as num).toDouble(),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      previousClose: (json['previousClose'] as num).toDouble(),
      volume: json['volume'] as int,
      lastUpdateTime: json['lastUpdateTime'] as String,
    );
  }

  // Create a mock stock for testing
  factory Stock.mock(String symbol) {
    final bool isPositive = symbol.hashCode % 2 == 0;
    final double basePrice = 1000 + (symbol.hashCode % 5000);
    final double changeValue =
        (10 + (symbol.hashCode % 20)) * (isPositive ? 1 : -1);

    return Stock(
      symbol: symbol,
      companyName: 'Company $symbol',
      lastPrice: basePrice,
      change: changeValue,
      percentChange: (changeValue / basePrice) * 100,
      open: basePrice - 5,
      high: basePrice + 15,
      low: basePrice - 20,
      previousClose: basePrice - 10,
      volume: 1000000 + (symbol.hashCode % 5000000),
      lastUpdateTime: DateTime.now().toString(),
    );
  }
}
