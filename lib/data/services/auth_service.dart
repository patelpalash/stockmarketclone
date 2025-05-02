import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class AuthService {
  http.Client _httpClient;
  final Map<String, String> _headers;

  // Token related fields
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();

  factory AuthService({http.Client? httpClient}) {
    if (httpClient != null) {
      _instance._httpClient.close(); // Close the existing client
      _instance._httpClient = httpClient;
    }
    return _instance;
  }

  AuthService._internal()
      : _httpClient = http.Client(),
        _headers = {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Api-Version': '2.0',
          'X-API-KEY': AppConstants.apiKey,
        };

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && !_isTokenExpired();
  }

  // Initialize token from storage if available
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    final expiryString = prefs.getString('token_expiry');
    if (expiryString != null) {
      _tokenExpiry = DateTime.parse(expiryString);
    }
  }

  // Get current token
  Future<String?> _getToken() async {
    if (_accessToken == null || _isTokenExpired()) {
      // Try to refresh the token
      return null;
    }
    return _accessToken;
  }

  // Check if token is expired
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    // Add a buffer of 5 minutes before actual expiry
    return _tokenExpiry!
        .subtract(const Duration(minutes: 5))
        .isBefore(DateTime.now());
  }

  // Login user with Upstox credentials
  Future<bool> login(String userId, String password) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConstants.upstoxBaseUrl}/login'),
        headers: _headers,
        body: json.encode({
          'user_id': userId,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          await _handleAuthResponse(data['data']);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return false;
    }
  }

  // Handle and store auth response
  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    _accessToken = data['access_token'];

    // Calculate expiry time
    final int expiresIn = data['expires_in'] ?? 86400; // Default to 1 day
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('token_expiry', _tokenExpiry!.toIso8601String());
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('token_expiry');
    _accessToken = null;
    _tokenExpiry = null;
  }

  // Get auth headers for API requests
  Map<String, String> get authHeaders {
    final headers = Map<String, String>.from(_headers);
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // Dispose
  void dispose() {
    _httpClient.close();
  }
}
