import '../models/calendar_month.dart';
import '../models/json_utils.dart';
import '../models/ledger_summary.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';
import 'api_repository.dart';

/// The dashboard summary and per-month calendar aggregates.
abstract class DashboardRepository {
  Future<LedgerSummary> fetchSummary();
  Future<CalendarMonth> fetchCalendar(DateTime month);
}

class ApiDashboardRepository extends ApiRepositoryBase
    implements DashboardRepository {
  ApiDashboardRepository(super.dio);

  @override
  Future<LedgerSummary> fetchSummary() {
    return guard(() async {
      final response = await dio.get<dynamic>(ApiPaths.dashboardSummary);
      final payload = asJsonMap(response.data);
      final summary = parseMap(payload['summary']) ?? payload;
      return LedgerSummary.fromJson(summary);
    });
  }

  @override
  Future<CalendarMonth> fetchCalendar(DateTime month) {
    return guard(() async {
      final normalized = DateTime(month.year, month.month, 1);
      final response = await dio.get<dynamic>(
        ApiPaths.calendar,
        queryParameters: {
          'month': '${normalized.year.toString().padLeft(4, '0')}-'
              '${normalized.month.toString().padLeft(2, '0')}',
        },
      );
      return CalendarMonth.fromJson(
        unwrapEnvelope(response.data),
        requestedMonth: normalized,
      );
    });
  }
}
