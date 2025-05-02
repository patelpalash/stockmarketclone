import 'dart:io';

import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/failures.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio) {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout =
        Duration(milliseconds: AppConstants.connectTimeout);
    _dio.options.receiveTimeout =
        Duration(milliseconds: AppConstants.receiveTimeout);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-KEY': AppConstants.apiKey,
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add token to headers if available
          // This would typically come from a secure storage
          // final token = _getToken();
          // if (token != null) {
          //   options.headers['Authorization'] = 'Bearer $token';
          // }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          return handler.next(_handleError(e));
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Error handling
  DioException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw TimeoutFailure(message: AppConstants.timeoutErrorMessage);
      case DioExceptionType.badResponse:
        return _handleResponseError(error);
      case DioExceptionType.cancel:
        throw const UnknownFailure(message: 'Request was cancelled');
      case DioExceptionType.connectionError:
        throw NetworkFailure(message: AppConstants.networkErrorMessage);
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          throw NetworkFailure(message: AppConstants.networkErrorMessage);
        }
        throw UnknownFailure(message: AppConstants.generalErrorMessage);
      default:
        throw UnknownFailure(message: AppConstants.generalErrorMessage);
    }
  }

  DioException _handleResponseError(DioException error) {
    int? statusCode = error.response?.statusCode;
    dynamic errorData = error.response?.data;
    String errorMessage = AppConstants.generalErrorMessage;

    if (errorData != null && errorData is Map<String, dynamic>) {
      errorMessage = errorData['message'] ?? errorMessage;
    }

    switch (statusCode) {
      case 400:
        throw ValidationFailure(
          message: errorMessage,
          errors:
              errorData is Map<String, dynamic> ? errorData['errors'] : null,
        );
      case 401:
      case 403:
        throw AuthenticationFailure(
          message: errorMessage,
          statusCode: statusCode,
        );
      case 404:
        throw ServerFailure(
          message: 'Resource not found',
          statusCode: statusCode,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerFailure(
          message: 'Server error',
          statusCode: statusCode,
        );
      default:
        throw ServerFailure(
          message: errorMessage,
          statusCode: statusCode,
        );
    }
  }
}
