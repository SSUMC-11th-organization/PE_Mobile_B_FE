import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/backend_config.dart';

Dio createBackendClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: BackendConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
      ),
    );
  }

  return dio;
}
