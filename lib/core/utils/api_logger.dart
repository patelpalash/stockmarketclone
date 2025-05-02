import 'package:flutter/foundation.dart';

class ApiLogger {
  // Log API requests
  static void logRequest(String url, dynamic headers) {
    if (kDebugMode) {
      print('\n---------------------------');
      print('🔶 API REQUEST 🔶');
      print('URL: $url');
      print('Headers: $headers');
      print('---------------------------\n');
    }
  }

  // Log API responses
  static void logResponse(int statusCode, String body, {String? url}) {
    if (kDebugMode) {
      print('\n---------------------------');
      print('🔷 API RESPONSE 🔷');
      if (url != null) {
        print('URL: $url');
      }
      print('Status Code: $statusCode');

      // For successful responses, log the beginning of the body
      if (statusCode >= 200 && statusCode < 300 && body.isNotEmpty) {
        String truncatedBody =
            body.length > 500 ? '${body.substring(0, 500)}...' : body;
        print('Body: $truncatedBody');
      }
      // For error responses, log the full body
      else if (statusCode >= 400) {
        print('Error Body: $body');
      }

      print('---------------------------\n');
    }
  }

  // Log errors
  static void logError(String message, dynamic error) {
    if (kDebugMode) {
      print('\n---------------------------');
      print('🔴 API ERROR 🔴');
      print('Message: $message');
      print('Error: $error');
      print('Stack Trace: ${StackTrace.current}');
      print('---------------------------\n');
    }
  }
}
