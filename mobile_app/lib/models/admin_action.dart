import 'json_utils.dart';

/// Whitelisted administrative operations. The mobile client can never send
/// arbitrary SQL; it only selects one of these fixed command identifiers.
enum AdminAction {
  databaseStats(
    command: 'DATABASE_STATS',
    title: 'Database statistics',
    description: 'Read table sizes and row counts from MySQL.',
    icon: 'database',
    isDestructive: false,
  ),
  runMigrations(
    command: 'RUN_MIGRATIONS',
    title: 'Run pending migrations',
    description: 'Apply Alembic migrations that are pending on the server.',
    icon: 'migration',
    isDestructive: false,
  ),
  createBackup(
    command: 'CREATE_BACKUP',
    title: 'Create encrypted backup',
    description: 'Start a server-side MySQL backup using the configured path.',
    icon: 'backup',
    isDestructive: false,
  ),
  optimizeIndexes(
    command: 'OPTIMIZE_INDEXES',
    title: 'Optimize ledger indexes',
    description: 'Run whitelisted maintenance on ledger tables.',
    icon: 'tune',
    isDestructive: false,
  ),
  pruneRateCache(
    command: 'PRUNE_RATE_CACHE',
    title: 'Prune expired rate cache',
    description: 'Remove expired exchange-rate cache entries from MongoDB.',
    icon: 'delete_sweep',
    isDestructive: true,
  );

  const AdminAction({
    required this.command,
    required this.title,
    required this.description,
    required this.icon,
    required this.isDestructive,
  });

  final String command;
  final String title;
  final String description;
  final String icon;
  final bool isDestructive;
}

class AdminActionResult {
  const AdminActionResult({
    required this.action,
    required this.message,
    required this.completedAt,
    this.details = const {},
  });

  final String action;
  final String message;
  final DateTime completedAt;
  final Map<String, dynamic> details;

  factory AdminActionResult.fromJson(Map<String, dynamic> json) {
    return AdminActionResult(
      action: parseString(json['action']),
      message: parseString(
        json['message'],
        fallback: 'Administrative action completed.',
      ),
      completedAt: parseRequiredDateTime(
        json['completed_at'] ?? DateTime.now(),
      ),
      details: parseMap(json['details']) ?? const {},
    );
  }
}
