import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Broadcasts authentication lifecycle events that originate outside the auth
/// controller. Today it carries a single signal: a 401 from an authenticated
/// request, which means the stored session has expired and must be dropped.
class SessionEventNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notifyUnauthorized() => state = state + 1;
}

final sessionEventProvider =
    NotifierProvider<SessionEventNotifier, int>(SessionEventNotifier.new);
