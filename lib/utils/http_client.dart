import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:suika_multi_player/config/api_config.dart';

Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (obj) => debugPrint('[DIO] $obj'),
  ));

  return dio;
}

