/// Compile-time application configuration.
///
/// Never put secrets in this file. Everything here is safe to ship to a
/// mobile device. The API URL is supplied at build time:
///
///   flutter run --dart-define=API_BASE_URL=https://192.168.1.42/api/v1
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    required this.defaultCurrency,
    required this.defaultTimezone,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  final String apiBaseUrl;
  final String environment;
  final String defaultCurrency;
  final String defaultTimezone;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  bool get isProduction => environment == 'production';

  static const String appName = 'Voice Ledger';
  static const String appTagline = 'Your money, spoken simply.';

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://raspberrypi.local/api/v1',
    );
    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl,
      environment: environment,
      defaultCurrency: 'INR',
      defaultTimezone: 'Asia/Kolkata',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    );
  }
}
