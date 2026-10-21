import '../models/json_utils.dart';

dynamic unwrapEnvelope(dynamic data) {
  final map = parseMap(data);
  if (map == null) return data;
  final inner = map['data'];
  if (inner is Map && !map.containsKey('items') && !map.containsKey('user')) {
    return inner;
  }
  return map;
}

Map<String, dynamic> asJsonMap(dynamic data) {
  final unwrapped = unwrapEnvelope(data);
  final map = parseMap(unwrapped);
  return map ?? const <String, dynamic>{};
}

List<dynamic> asJsonList(dynamic data, {List<String> keys = const []}) {
  if (data is List) return data;
  final map = parseMap(unwrapEnvelope(data)) ?? const <String, dynamic>{};
  for (final key in [...keys, 'items', 'results', 'data']) {
    final value = map[key];
    if (value is List) return value;
  }
  return const [];
}

Map<String, dynamic> errorDetails(dynamic data) {
  final map = parseMap(data);
  if (map == null) return const {};
  final error = map['error'];
  if (error is Map) return Map<String, dynamic>.from(error);
  return map;
}
