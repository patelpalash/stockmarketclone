class MarketIndex {
  final String name;
  final double value;
  final double change;
  final double percentChange;
  final String lastUpdateTime;

  MarketIndex({
    required this.name,
    required this.value,
    required this.change,
    required this.percentChange,
    required this.lastUpdateTime,
  });

  bool get isPositive => change >= 0;

  // Create a market index from JSON data
  factory MarketIndex.fromJson(Map<String, dynamic> json) {
    return MarketIndex(
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      percentChange: (json['percentChange'] as num).toDouble(),
      lastUpdateTime: json['lastUpdateTime'] as String,
    );
  }

  // Create a mock market index for testing
  factory MarketIndex.mock(String name) {
    final bool isPositive = name.hashCode % 2 == 0;
    final double baseValue = 10000 + (name.hashCode % 5000);
    final double changeValue =
        (50 + (name.hashCode % 100)) * (isPositive ? 1 : -1);

    return MarketIndex(
      name: name,
      value: baseValue,
      change: changeValue,
      percentChange: (changeValue / baseValue) * 100,
      lastUpdateTime: DateTime.now().toString(),
    );
  }
}
