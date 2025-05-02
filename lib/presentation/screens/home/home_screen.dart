import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../widgets/market_index_card.dart';
import '../../widgets/stock_list_item.dart';
import '../../widgets/section_header.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../option_chain/option_chain_screen.dart';
import '../portfolio/portfolio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isDarkMode = false;
  final List<String> _watchlistStocks = [
    'RELIANCE',
    'TCS',
    'HDFCBANK',
    'INFY',
    'ICICIBANK'
  ];

  final List<Map<String, dynamic>> _marketIndices = [
    {
      'name': AppConstants.nifty50,
      'value': 22458.95,
      'change': 156.35,
      'percentChange': 0.70,
      'isPositive': true,
    },
    {
      'name': AppConstants.bankNifty,
      'value': 48752.45,
      'change': -126.80,
      'percentChange': -0.26,
      'isPositive': false,
    },
    {
      'name': AppConstants.niftyIT,
      'value': 37912.25,
      'change': 327.65,
      'percentChange': 0.87,
      'isPositive': true,
    },
    {
      'name': AppConstants.niftyFinService,
      'value': 21354.30,
      'change': 42.15,
      'percentChange': 0.20,
      'isPositive': true,
    },
  ];

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.show_chart,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _toggleTheme,
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Market Indices Section
              SectionHeader(
                title: 'Market Indices',
                onSeeAllPressed: () {},
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _marketIndices.length,
                  itemBuilder: (context, index) {
                    final indexData = _marketIndices[index];
                    return MarketIndexCard(
                      name: indexData['name'],
                      value: indexData['value'],
                      change: indexData['change'],
                      percentChange: indexData['percentChange'],
                      isPositive: indexData['isPositive'],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Watchlist Section
              SectionHeader(
                title: 'Watchlist',
                onSeeAllPressed: () {},
              ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _watchlistStocks.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  // Generate mock stock data
                  final stockPrice = (2000 + (index * 500 + index * 24.75));
                  final priceChange =
                      (index % 2 == 0) ? (5 + index * 2.5) : -(5 + index * 1.5);
                  final percentChange = (priceChange / stockPrice) * 100;

                  return StockListItem(
                    symbol: _watchlistStocks[index],
                    companyName: 'Company ${index + 1}',
                    price: stockPrice,
                    priceChange: priceChange,
                    percentChange: percentChange,
                    volume: '${(index + 1) * 2}.${(index + 1) * 5}M',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StockDetailScreen(
                            symbol: _watchlistStocks[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Options Chain Quick Access
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OptionChainScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.stacked_line_chart,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Options Chain',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Analyze and trade options with real-time data',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PortfolioScreen(),
              ),
            );
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: const Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.swap_horiz_outlined),
            activeIcon: const Icon(Icons.swap_horiz),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
