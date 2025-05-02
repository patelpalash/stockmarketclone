import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/api_logger.dart';

class UpstoxAuthService {
  static const String _accessTokenKey = 'upstox_access_token';
  static const String _tokenExpiryKey = 'upstox_token_expiry';
  static const String _apiSecretKey = 'upstox_api_secret';

  // This needs to be set to your actual API Secret from the Upstox Developer Portal
  // Store it securely in a constant for now, but should be moved to environment variables or secure storage
  static const String _defaultApiSecret = '0ockfjggom';

  // This redirect URI must match EXACTLY what you registered in Upstox
  final String _redirectUri = 'https://stockmarketcloneapp.web.app/auth';

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _apiSecret;

  // Singleton pattern
  static final UpstoxAuthService _instance = UpstoxAuthService._internal();

  factory UpstoxAuthService() {
    return _instance;
  }

  UpstoxAuthService._internal() {
    // Initialize authentication when created
    _initAuth();
  }

  // Initialize authentication asynchronously
  Future<void> _initAuth() async {
    try {
      await initialize();
      if (kDebugMode) {
        print('Auth initialized. Is authenticated: $isAuthenticated');
        if (isAuthenticated) {
          print('Token expires at: $_tokenExpiry');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth: $e');
      }
    }
  }

  // Custom URL launcher function
  Future<bool> _openURL(String url, BuildContext context) async {
    try {
      if (kDebugMode) {
        print('Trying to open URL: $url');
      }

      // Try url_launcher first
      if (await canLaunchUrlString(url)) {
        return await launchUrlString(
          url,
          mode: LaunchMode.externalApplication,
        );
      }

      // Try direct method if url_launcher fails
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      // If all fails, show a dialog with the URL to manually copy
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Open URL Manually'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Unable to open the browser automatically. Please copy this URL and open it in your browser:'),
                const SizedBox(height: 12),
                SelectableText(url,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                  },
                  child: const Text('Copy to Clipboard'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error in _openURL: $e');
      }
      return false;
    }
  }

  // Initialize and load stored token if available
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    final expiryString = prefs.getString(_tokenExpiryKey);
    if (expiryString != null) {
      _tokenExpiry = DateTime.parse(expiryString);
    }

    // Load API secret from preferences or use default
    _apiSecret = prefs.getString(_apiSecretKey) ?? _defaultApiSecret;

    ApiLogger.logRequest('Initializing UpstoxAuthService', {
      'Has Token': (_accessToken != null).toString(),
      'Token Expiry': _tokenExpiry?.toString() ?? 'None',
    });
  }

  // Check if we have a valid token
  bool get isAuthenticated {
    return _accessToken != null && !_isTokenExpired();
  }

  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    // Add a 5-minute buffer to handle slight time differences
    final expiryWithBuffer = _tokenExpiry!.subtract(const Duration(minutes: 5));
    return expiryWithBuffer.isBefore(DateTime.now());
  }

  // Get the access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    if (_accessToken != null && !_isTokenExpired()) {
      return _accessToken;
    }

    // Token is expired or not available
    return null;
  }

  // Get auth headers for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-API-KEY': AppConstants.apiKey,
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Start the OAuth flow with direct code entry option
  Future<bool> startAuthFlow(BuildContext context) async {
    try {
      final manualCodeController = TextEditingController();
      final apiSecretController = TextEditingController();
      apiSecretController.text = _apiSecret ?? _defaultApiSecret;

      bool result = false;

      // Step 1: Build the authorization URL - DO NOT encode client_id, it should be plain
      // But DO encode the redirect_uri
      final authUrlString =
          '${AppConstants.upstoxBaseUrl}/login/authorization/dialog'
          '?response_type=code'
          '&client_id=${AppConstants.apiKey}'
          '&redirect_uri=${Uri.encodeComponent(_redirectUri)}';

      // Show the manual code entry dialog
      final manualResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Upstox Authentication'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text(
                      'IMPORTANT: Authorization codes expire quickly. Use the code immediately after receiving it.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'API Secret',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: apiSecretController,
                    decoration: const InputDecoration(
                      labelText: 'API Secret',
                      hintText: 'Enter your Upstox API Secret',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Step 1: Copy the authorization URL below',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SelectableText(
                      authUrlString,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: authUrlString));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('URL copied to clipboard')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text(
                            'Copy URL',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openURL(authUrlString, context),
                          icon: const Icon(Icons.open_in_browser, size: 18),
                          label: const Text(
                            'Open URL',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Step 2: Complete authentication in browser',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Open the URL above in your browser\n'
                    '• Login to your Upstox account\n'
                    '• After login, you\'ll be redirected to a page\n'
                    '• From the address bar, find the "code=XXXXX" part\n'
                    '• Copy ONLY the code value (after code= and before any &)',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Step 3: Enter the authorization code below',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: manualCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Authorization Code',
                      hintText: 'Enter only the code from the URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (manualCodeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter the authorization code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Save the API secret if provided
                if (apiSecretController.text.isNotEmpty) {
                  _apiSecret = apiSecretController.text;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_apiSecretKey, _apiSecret!);
                }

                // Show a loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Processing authentication...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Extract the code
                String code = manualCodeController.text.trim();
                code = _extractCodeFromValue(code);

                if (kDebugMode) {
                  print('Attempting authentication with code: $code');
                }

                if (code.isNotEmpty) {
                  result = await _exchangeCodeForToken(code);

                  if (result) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Authentication successful!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    Navigator.of(context).pop(result);
                  } else {
                    if (context.mounted) {
                      // Show a more detailed error message
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Authentication Failed'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Failed to exchange code for token. Please check:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                  '• Your authorization code is correct and not expired'),
                              const Text(
                                  '• You are using the correct API key and secret'),
                              const Text(
                                  '• The redirect URI matches what you registered in Upstox'),
                              const SizedBox(height: 16),
                              const Text(
                                  'Try logging in to Upstox again to get a fresh code.'),
                              const SizedBox(height: 8),
                              SelectableText(
                                'Code used: $code',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid authorization code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      return manualResult ?? false;
    } catch (e) {
      ApiLogger.logError('Error starting auth flow', e);
      return false;
    }
  }

  // Helper method to extract just the code value
  String _extractCodeFromValue(String value) {
    // If the full URL was pasted
    if (value.contains('code=')) {
      try {
        // First try to parse as a URL
        final uri = Uri.parse(value);
        final codeParam = uri.queryParameters['code'];
        if (codeParam != null) {
          return codeParam;
        }
      } catch (_) {
        // If that fails, try to extract manually
      }

      // Manual extraction
      final codeIndex = value.indexOf('code=');
      if (codeIndex >= 0) {
        String code = value.substring(codeIndex + 5);
        // Extract until next & or end of string
        final endIndex = code.indexOf('&');
        if (endIndex >= 0) {
          code = code.substring(0, endIndex);
        }
        return code;
      }
    }

    // If it's just the code, return as is
    return value;
  }

  // Exchange the authorization code for an access token
  Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final apiSecret = _apiSecret ?? _defaultApiSecret;

      if (kDebugMode) {
        print('Exchanging code for token: $code');
        print('API Key: ${AppConstants.apiKey}');
        print('API Secret: $apiSecret');
        print('Redirect URI: $_redirectUri');
      }

      // Direct HTTP approach - simpler to debug
      final uri =
          Uri.parse('${AppConstants.upstoxBaseUrl}/login/authorization/token');

      // Make the request with properly formatted form data
      final bodyString = 'code=$code&'
          'client_id=${Uri.encodeComponent(AppConstants.apiKey)}&'
          'client_secret=${Uri.encodeComponent(apiSecret)}&'
          'redirect_uri=${Uri.encodeComponent(_redirectUri)}&'
          'grant_type=authorization_code';

      if (kDebugMode) {
        print('Request URI: $uri');
        print('Request body: $bodyString');
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: bodyString,
      );

      if (kDebugMode) {
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      // Detailed API response logging
      ApiLogger.logResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          // Check for access_token in the direct response (Upstox API format)
          if (data['access_token'] != null) {
            _accessToken = data['access_token'];

            // Calculate token expiry time if provided, otherwise use default (1 day)
            final expiresIn = data['expires_in'] ?? 86400;
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

            // Save to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_accessTokenKey, _accessToken!);
            await prefs.setString(
                _tokenExpiryKey, _tokenExpiry!.toIso8601String());

            return true;
          }
          // Check for older response format with status and data properties
          else if (data['status'] == 'success' && data['data'] != null) {
            final tokenData = data['data'];
            _accessToken = tokenData['access_token'];

            // Calculate token expiry time
            final expiresIn = tokenData['expires_in'] ?? 86400;
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

            // Save to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_accessTokenKey, _accessToken!);
            await prefs.setString(
                _tokenExpiryKey, _tokenExpiry!.toIso8601String());

            return true;
          } else {
            if (kDebugMode) {
              print('API returned unexpected response format');
              print('Response: $data');
            }
          }
        } catch (jsonError) {
          if (kDebugMode) {
            print('Error parsing JSON response: $jsonError');
            print('Raw response: ${response.body}');
          }
        }
      } else {
        if (kDebugMode) {
          print('HTTP error: ${response.statusCode}');
          print('Error body: ${response.body}');
        }
      }

      // If we get here, authentication failed
      return false;
    } catch (e) {
      ApiLogger.logError('Error exchanging code for token', e);
      if (kDebugMode) {
        print('Exception during token exchange: $e');
      }
      return false;
    }
  }

  // Clear stored tokens (logout)
  Future<void> logout() async {
    _accessToken = null;
    _tokenExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenExpiryKey);
  }
}
