import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/utils/log_buffer.dart';

Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  final lb = LogBuffer.instance;

  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (obj) {
      debugPrint('[DIO] $obj');
      lb.info('DIO', obj.toString());
    },
  ));

  // 错误拦截器
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) {
      lb.error('DIO', 'Request failed: ${e.requestOptions.path} — ${e.message}');
      handler.next(e);
    },
  ));

  return dio;
}

