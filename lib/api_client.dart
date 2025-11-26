import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://rocket.builtlab.io.vn',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
  }

  static final ApiClient _instance = ApiClient._();

  static ApiClient get instance => _instance;

  late Dio _dio;

  Dio get dio => _dio;

  Future get({required String id}) async {
    try {
      final response = await _dio.get(
        '/api/v1/device-tokens/$id',
        queryParameters: {'page': 1, 'limit': 10},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
