import 'package:dio/dio.dart';
import 'env.dart';

Dio createDio({bool useCookies = false}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBase, // ← 여기!
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // (웹에서) 세션/쿠키를 쓸 때만 withCredentials = true
  // 쿠키 안 쓰면 생략 가능
  // if (useCookies) {
  //   dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
  // }

  // (선택) 공통 로깅
  // dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: true));

  return dio;
}
