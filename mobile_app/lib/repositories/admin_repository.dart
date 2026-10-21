import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';
import '../models/admin_action.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';

abstract class AdminRepository {
  Future<AdminActionResult> runAction(
    AdminAction action, {
    required String password,
    Map<String, dynamic> parameters = const {},
  });
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._dio);

  final Dio _dio;

  @override
  Future<AdminActionResult> runAction(
    AdminAction action, {
    required String password,
    Map<String, dynamic> parameters = const {},
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiPaths.adminActions,
        data: {
          'action': action.command,
          'password': password,
          'confirm': true,
          'parameters': parameters,
        },
      );
      return AdminActionResult.fromJson(asJsonMap(response.data));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
