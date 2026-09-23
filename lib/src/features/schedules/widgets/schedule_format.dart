import 'package:openlock/src/features/schedules/models/lock_schedule.dart';

/// Human-readable formatting for schedule times and weekdays.
abstract final class ScheduleFormat {
  static const List<String> weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String time(int minutesSinceMidnight) {
    final h = (minutesSinceMidnight ~/ 60) % 24;
    final m = minutesSinceMidnight % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String weekdays(Set<int> days) {
    if (days.isEmpty) return 'No days';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 &&
        days.containsAll({1, 2, 3, 4, 5}) &&
        !days.contains(6) &&
        !days.contains(7)) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
    final sorted = days.toList()..sort();
    return sorted.map((d) => weekdayLabels[d - 1]).join(', ');
  }

  static String summary(LockSchedule schedule) {
    final days = weekdays(schedule.weekdays);
    if (schedule.isAllDay) return '$days · All day';
    return '$days · ${time(schedule.startMinutes)}–'
        '${time(schedule.endMinutes)}';
  }
}
