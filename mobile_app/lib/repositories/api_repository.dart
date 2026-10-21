import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';

/// Shared plumbing for the HTTP-backed repositories. Every call is wrapped so a
/// [DioException] is translated into a user-presentable [AppException] and the
/// UI never sees transport details.
abstract class ApiRepositoryBase {
  ApiRepositoryBase(this.dio);

  final Dio dio;

  Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
