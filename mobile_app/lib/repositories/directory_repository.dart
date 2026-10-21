import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';
import '../models/category.dart';
import '../models/person.dart';
import '../models/transaction_type.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';

abstract class PersonRepository {
  Future<List<Person>> fetchPersons({String? search});
  Future<Person> createPerson({
    required String name,
    String? phone,
    String? email,
    String? notes,
  });
  Future<Person> updatePerson(Person person);
  Future<void> deletePerson(String id);
}

abstract class CategoryRepository {
  Future<List<Category>> fetchCategories({TransactionType? type});
  Future<Category> createCategory({
    required String name,
    required TransactionType type,
    String colorHex,
    String iconKey,
  });
  Future<Category> updateCategory(Category category);
  Future<void> deleteCategory(String id);
}

class ApiDirectoryRepository implements PersonRepository, CategoryRepository {
  ApiDirectoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Person>> fetchPersons({String? search}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.persons,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final raw = asJsonList(response.data, keys: const ['persons']);
      return raw
          .whereType<Map>()
          .map((item) => Person.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Person> createPerson({
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiPaths.persons,
        data: {
          'name': name.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      final payload = asJsonMap(response.data);
      final person = payload['person'] ?? payload;
      return Person.fromJson(Map<String, dynamic>.from(person as Map));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Person> updatePerson(Person person) async {
    try {
      final response = await _dio.patch<dynamic>(
        ApiPaths.person(person.id),
        data: person.toRequestJson(),
      );
      final payload = asJsonMap(response.data);
      final updated = payload['person'] ?? payload;
      return Person.fromJson(Map<String, dynamic>.from(updated as Map));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<void> deletePerson(String id) async {
    try {
      await _dio.delete<dynamic>(ApiPaths.person(id));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<List<Category>> fetchCategories({TransactionType? type}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.categories,
        queryParameters: {if (type != null) 'type': type.apiValue},
      );
      final raw = asJsonList(response.data, keys: const ['categories']);
      return raw
          .whereType<Map>()
          .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Category> createCategory({
    required String name,
    required TransactionType type,
    String colorHex = '#0E6B5C',
    String iconKey = 'category',
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiPaths.categories,
        data: {
          'name': name.trim(),
          'type': type.apiValue,
          'color_hex': colorHex,
          'icon': iconKey,
        },
      );
      final payload = asJsonMap(response.data);
      final category = payload['category'] ?? payload;
      return Category.fromJson(Map<String, dynamic>.from(category as Map));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Category> updateCategory(Category category) async {
    try {
      final response = await _dio.patch<dynamic>(
        ApiPaths.category(category.id),
        data: category.toRequestJson(),
      );
      final payload = asJsonMap(response.data);
      final updated = payload['category'] ?? payload;
      return Category.fromJson(Map<String, dynamic>.from(updated as Map));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete<dynamic>(ApiPaths.category(id));
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
