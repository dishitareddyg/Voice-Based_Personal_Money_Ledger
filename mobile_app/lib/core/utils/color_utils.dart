import 'package:flutter/material.dart';

Color colorFromHex(String hex, {Color fallback = const Color(0xFF0E6B5C)}) {
  var value = hex.trim().replaceAll('#', '');
  if (value.length == 3) {
    value = value.split('').map((char) => '$char$char').join();
  }
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
