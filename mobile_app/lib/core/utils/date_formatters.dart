import 'package:intl/intl.dart';

class AppDateFormatter {
  AppDateFormatter._();

  static final DateFormat _shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat _longDate = DateFormat('EEEE, dd MMMM yyyy');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _monthShort = DateFormat('MMM');
  static final DateFormat _day = DateFormat('dd');
  static final DateFormat _weekday = DateFormat('EEE');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _apiMonth = DateFormat('yyyy-MM');
  static final DateFormat _apiTime = DateFormat('HH:mm:ss');

  static String shortDate(DateTime value) => _shortDate.format(value.toLocal());

  static String longDate(DateTime value) => _longDate.format(value.toLocal());

  static String monthYear(DateTime value) => _monthYear.format(value.toLocal());

  static String monthShort(DateTime value) => _monthShort.format(value.toLocal());

  static String day(DateTime value) => _day.format(value.toLocal());

  static String weekday(DateTime value) => _weekday.format(value.toLocal());

  static String time(DateTime value) => _time.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  static String apiDate(DateTime value) => _apiDate.format(value);

  static String apiMonth(DateTime value) => _apiMonth.format(value);

  static String apiTime(DateTime value) => _apiTime.format(value);

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfMonth(DateTime value) =>
      DateTime(value.year, value.month, 1);

  static DateTime endOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0, 23, 59, 59);

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
