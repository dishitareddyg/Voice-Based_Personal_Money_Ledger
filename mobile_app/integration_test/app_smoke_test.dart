import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_ledger/app.dart';
import 'package:voice_ledger/models/auth_session.dart';
import 'package:voice_ledger/providers/infrastructure_providers.dart';
import 'package:voice_ledger/services/secure_token_storage.dart';

/// Runs on a real device or emulator:
///   flutter test integration_test -d `device-id`
///
/// Secure storage is replaced with an in-memory store so the smoke test does
/// not depend on platform keychains and never talks to the Raspberry Pi.
class _InMemoryTokenStorage implements TokenStorage {
  AuthSession? _session;
  final Map<String, String> _settings = {};

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async => _session = session;

  @override
  Future<void> clearSession() async => _session = null;

  @override
  Future<String?> readAccessToken() async => _session?.accessToken;

  @override
  Future<String?> readSetting(String key) async => _settings[key];

  @override
  Future<void> writeSetting(String key, String value) async =>
      _settings[key] = value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and reaches the sign-in screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_InMemoryTokenStorage()),
        ],
        child: const LedgerApp(),
      ),
    );

    // The splash screen shows an indefinite progress indicator, so pump on a
    // fixed timeline instead of pumpAndSettle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Create an account'), findsOneWidget);
  });
}
