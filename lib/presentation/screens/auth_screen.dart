import 'package:flutter/material.dart';
import '../../data/services/upstox_auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final UpstoxAuthService _authService = UpstoxAuthService();
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking authentication status...';
    });

    await _authService.initialize();

    setState(() {
      _isLoading = false;
      if (_authService.isAuthenticated) {
        _statusMessage = 'Already authenticated!';
        _navigateToHome();
      } else {
        _statusMessage = 'Authentication required.';
      }
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting authentication flow...';
    });

    try {
      final success = await _authService.startAuthFlow(context);

      setState(() {
        _isLoading = false;
        _statusMessage =
            success ? 'Authentication successful!' : 'Authentication failed.';
      });

      if (success) {
        _navigateToHome();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Logging out...';
    });

    await _authService.logout();

    setState(() {
      _isLoading = false;
      _statusMessage = 'Logged out successfully.';
    });
  }

  void _navigateToHome() {
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upstox Authentication'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://upstox.com/assets/images/logo.svg', // Upstox logo
                width: 200,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_balance, size: 100),
              ),
              const SizedBox(height: 40),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Real-time NSE Stock Market Data',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                  child: const Text('Login with Upstox'),
                ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusMessage.contains('Error') ||
                          _statusMessage.contains('failed')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'This app requires authentication with Upstox to fetch real-time market data.',
                textAlign: TextAlign.center,
              ),
              if (_authService.isAuthenticated)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: TextButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
