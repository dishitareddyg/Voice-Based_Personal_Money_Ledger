import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/user.dart';
import 'infrastructure_providers.dart';
import 'session_providers.dart';

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    ref.listen<int>(sessionEventProvider, (previous, next) {
      if (previous != next && state.valueOrNull != null) {
        state = const AsyncData(null);
      }
    });
    return ref.watch(authRepositoryProvider).restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);
    final session = await repository.login(
      LoginRequest(email: email.trim(), password: password),
    );
    state = AsyncData(session);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final session = await repository.register(
      RegisterRequest(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
      ),
    );
    state = AsyncData(session);
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }

  Future<void> refreshProfile() async {
    final session = state.valueOrNull;
    if (session == null) return;
    try {
      final user = await ref.read(authRepositoryProvider).fetchProfile();
      state = AsyncData(
        AuthSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: user,
        ),
      );
    } catch (_) {
      // Keep the cached session; individual screens surface network errors.
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull?.user;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});
