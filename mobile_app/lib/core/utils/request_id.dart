import 'dart:math';

final Random _random = Random.secure();

String generateRequestId() {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
  final entropy = _random.nextInt(0x7fffffff).toRadixString(16);
  return 'vl-$timestamp-$entropy';
}
