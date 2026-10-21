import 'nlp_vocabulary.dart';

class DatePhraseMatch {
  const DatePhraseMatch({
    required this.date,
    required this.explicit,
    required this.raw,
    this.time,
  });

  final DateTime date;
  final bool explicit;
  final String raw;
  final String? time;
}

class TimePhraseMatch {
  const TimePhraseMatch({required this.time, required this.raw});

  final String time;
  final String raw;
}

class DatePhraseParser {
  DatePhraseParser._();

  static DatePhraseMatch parse(String text, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final lower = text.toLowerCase();

    final relativeDays = _matchRelativeDays(lower, today);
    if (relativeDays != null) return relativeDays;

    final explicit = _matchExplicitDate(lower, today);
    if (explicit != null) return explicit;

    final weekday = _matchWeekday(lower, today);
    if (weekday != null) return weekday;

    final relativePeriod = _matchRelativePeriod(lower, today);
    if (relativePeriod != null) return relativePeriod;

    return DatePhraseMatch(
      date: today,
      explicit: false,
      raw: '',
      time: parseTime(text)?.time,
    );
  }

  static TimePhraseMatch? parseTime(String text) {
    final lower = text.toLowerCase();

    if (RegExp(r'\bnoon\b').hasMatch(lower)) {
      final match = RegExp(r'\bnoon\b').firstMatch(lower)!;
      return TimePhraseMatch(
        time: '12:00',
        raw: text.substring(match.start, match.end),
      );
    }
    if (RegExp(r'\bmidnight\b').hasMatch(lower)) {
      final match = RegExp(r'\bmidnight\b').firstMatch(lower)!;
      return TimePhraseMatch(
        time: '00:00',
        raw: text.substring(match.start, match.end),
      );
    }

    final amPm = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\b',
    ).firstMatch(lower);
    if (amPm != null) {
      var hour = int.parse(amPm.group(1)!);
      final minute = int.parse(amPm.group(2) ?? '0');
      final marker = amPm.group(3)!.replaceAll('.', '');
      if (hour < 1 || hour > 12 || minute > 59) return null;
      if (marker == 'pm' && hour != 12) hour += 12;
      if (marker == 'am' && hour == 12) hour = 0;
      return TimePhraseMatch(
        time:
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        raw: text.substring(amPm.start, amPm.end),
      );
    }

    final clock = RegExp(r'\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b')
        .firstMatch(lower);
    if (clock != null) {
      return TimePhraseMatch(
        time:
            '${clock.group(1)!.padLeft(2, '0')}:${clock.group(2)!.padLeft(2, '0')}',
        raw: text.substring(clock.start, clock.end),
      );
    }
    return null;
  }

  static DatePhraseMatch? _matchRelativeDays(String text, DateTime today) {
    const phrases = <String, int>{
      'day before yesterday': -2,
      'the day before yesterday': -2,
      'yesterday': -1,
      'last night': -1,
      'today': 0,
      'this morning': 0,
      'this afternoon': 0,
      'this evening': 0,
      'tonight': 0,
      'tomorrow': 1,
    };

    for (final entry in phrases.entries) {
      final match = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b')
          .firstMatch(text);
      if (match != null) {
        return DatePhraseMatch(
          date: today.add(Duration(days: entry.value)),
          explicit: true,
          raw: match.group(0)!,
        );
      }
    }

    final daysAgo = RegExp(r'\b(\d{1,3})\s+days?\s+ago\b').firstMatch(text);
    if (daysAgo != null) {
      final days = int.tryParse(daysAgo.group(1)!);
      if (days != null) {
        return DatePhraseMatch(
          date: today.subtract(Duration(days: days)),
          explicit: true,
          raw: daysAgo.group(0)!,
        );
      }
    }

    final weeksAgo = RegExp(r'\b(\d{1,2})\s+weeks?\s+ago\b').firstMatch(text);
    if (weeksAgo != null) {
      final weeks = int.tryParse(weeksAgo.group(1)!);
      if (weeks != null) {
        return DatePhraseMatch(
          date: today.subtract(Duration(days: weeks * 7)),
          explicit: true,
          raw: weeksAgo.group(0)!,
        );
      }
    }

    return null;
  }

  static DatePhraseMatch? _matchExplicitDate(String text, DateTime today) {
    final iso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      final date = _safeDate(year, month, day);
      if (date != null) {
        return DatePhraseMatch(date: date, explicit: true, raw: iso.group(0)!);
      }
    }

    final numeric =
        RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b').firstMatch(text);
    if (numeric != null) {
      final first = int.parse(numeric.group(1)!);
      final second = int.parse(numeric.group(2)!);
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;

      int day;
      int month;
      if (first > 12) {
        day = first;
        month = second;
      } else if (second > 12) {
        month = first;
        day = second;
      } else {
        day = first;
        month = second;
      }
      final date = _safeDate(year, month, day);
      if (date != null) {
        return DatePhraseMatch(
          date: date,
          explicit: true,
          raw: numeric.group(0)!,
        );
      }
    }

    final dayMonthYear = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|'
      r'dec(?:ember)?)'
      r'(?:\s*,?\s*(\d{4}))?\b',
    ).firstMatch(text);
    if (dayMonthYear != null) {
      final day = int.parse(dayMonthYear.group(1)!);
      final month = NlpVocabulary.monthNumber(dayMonthYear.group(2)!);
      final year = dayMonthYear.group(3) == null
          ? today.year
          : int.parse(dayMonthYear.group(3)!);
      if (month != null) {
        final date = _safeDate(year, month, day);
        if (date != null) {
          return DatePhraseMatch(
            date: date,
            explicit: true,
            raw: dayMonthYear.group(0)!,
          );
        }
      }
    }

    final monthDayYear = RegExp(
      r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|'
      r'dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?'
      r'(?:\s*,?\s*(\d{4}))?\b',
    ).firstMatch(text);
    if (monthDayYear != null) {
      final month = NlpVocabulary.monthNumber(monthDayYear.group(1)!);
      final day = int.parse(monthDayYear.group(2)!);
      final year = monthDayYear.group(3) == null
          ? today.year
          : int.parse(monthDayYear.group(3)!);
      if (month != null) {
        final date = _safeDate(year, month, day);
        if (date != null) {
          return DatePhraseMatch(
            date: date,
            explicit: true,
            raw: monthDayYear.group(0)!,
          );
        }
      }
    }

    return null;
  }

  static DatePhraseMatch? _matchWeekday(String text, DateTime today) {
    const weekdays = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final match = RegExp(
      r'\b(last|this|next|on|previous)?\s*'
      r'(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ).firstMatch(text);
    if (match == null) return null;

    final qualifier = match.group(1);
    final target = weekdays[match.group(2)!]!;
    var difference = target - today.weekday;

    if (qualifier == 'next') {
      if (difference <= 0) difference += 7;
    } else if (qualifier == 'last' || qualifier == 'previous') {
      if (difference >= 0) difference -= 7;
      if (difference == 0) difference = -7;
    } else {
      if (difference > 0) difference -= 7;
    }

    return DatePhraseMatch(
      date: today.add(Duration(days: difference)),
      explicit: true,
      raw: match.group(0)!.trim(),
    );
  }

  static DatePhraseMatch? _matchRelativePeriod(String text, DateTime today) {
    if (RegExp(r'\blast week\b').hasMatch(text)) {
      return DatePhraseMatch(
        date: today.subtract(const Duration(days: 7)),
        explicit: true,
        raw: 'last week',
      );
    }
    if (RegExp(r'\blast month\b').hasMatch(text)) {
      return DatePhraseMatch(
        date: _shiftMonth(today, -1),
        explicit: true,
        raw: 'last month',
      );
    }
    if (RegExp(r'\bnext week\b').hasMatch(text)) {
      return DatePhraseMatch(
        date: today.add(const Duration(days: 7)),
        explicit: true,
        raw: 'next week',
      );
    }
    final monthsAgo =
        RegExp(r'\b(\d{1,2})\s+months?\s+ago\b').firstMatch(text);
    if (monthsAgo != null) {
      final months = int.tryParse(monthsAgo.group(1)!);
      if (months != null) {
        return DatePhraseMatch(
          date: _shiftMonth(today, -months),
          explicit: true,
          raw: monthsAgo.group(0)!,
        );
      }
    }
    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (year < 1900 || year > 2200) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static DateTime _shiftMonth(DateTime date, int delta) {
    final rawMonth = date.month + delta;
    final year = date.year + (rawMonth - 1) ~/ 12;
    final month = ((rawMonth - 1) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }
}
