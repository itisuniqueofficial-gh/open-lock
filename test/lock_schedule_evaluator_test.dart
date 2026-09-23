import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/services/lock_schedule_evaluator.dart';

LockSchedule _schedule({
  Set<int> weekdays = const {1, 2, 3, 4, 5},
  int start = 9 * 60,
  int end = 17 * 60,
  Set<String> packages = const {'com.social'},
  bool enabled = true,
}) =>
    LockSchedule(
      id: 'test',
      name: 'Work focus',
      packages: packages,
      weekdays: weekdays,
      startMinutes: start,
      endMinutes: end,
      enabled: enabled,
    );

void main() {
  // 2026-07-08 is a Wednesday (weekday 3).
  group('same-day window (09:00–17:00 weekdays)', () {
    final s = _schedule();

    test('inside the window → locked', () {
      final now = DateTime(2026, 7, 8, 10, 30);
      expect(LockScheduleEvaluator.isActiveAt(s, now), isTrue);
    });

    test('before the window → not locked', () {
      final now = DateTime(2026, 7, 8, 8, 59);
      expect(LockScheduleEvaluator.isActiveAt(s, now), isFalse);
    });

    test('at the start minute → locked (inclusive)', () {
      expect(
          LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 8, 9)), isTrue);
    });

    test('at the end minute → not locked (exclusive)', () {
      expect(LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 8, 17)),
          isFalse);
    });

    test('on a weekend → not locked', () {
      // 2026-07-11 is a Saturday.
      final now = DateTime(2026, 7, 11, 10, 30);
      expect(LockScheduleEvaluator.isActiveAt(s, now), isFalse);
    });

    test('disabled schedules never lock', () {
      final disabled = _schedule(enabled: false);
      final now = DateTime(2026, 7, 8, 10, 30);
      expect(
        LockScheduleEvaluator.lockedPackagesAt([disabled], now),
        isEmpty,
      );
    });
  });

  group('overnight window (22:00–06:00)', () {
    // Active Fridays into Saturday morning.
    final s = _schedule(
      weekdays: {5},
      start: 22 * 60,
      end: 6 * 60,
    );

    test('Friday evening (after start) → locked', () {
      // 2026-07-10 is a Friday.
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 10, 23)),
        isTrue,
      );
    });

    test('Saturday early morning (before end) → locked (belongs to Friday)',
        () {
      // 2026-07-11 Saturday 05:00 — the tail of the Friday window.
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 11, 5)),
        isTrue,
      );
    });

    test('Saturday morning after end → not locked', () {
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 11, 7)),
        isFalse,
      );
    });

    test('Friday afternoon (before start) → not locked', () {
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 10, 12)),
        isFalse,
      );
    });

    test('Saturday evening is NOT locked (window is Friday-scoped)', () {
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 11, 23)),
        isFalse,
      );
    });
  });

  group('all-day window (start == end)', () {
    final s = _schedule(weekdays: {6}, start: 0, end: 0);

    test('locked all Saturday', () {
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 11, 3)),
        isTrue,
      );
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 11, 23, 59)),
        isTrue,
      );
    });

    test('not locked on other days', () {
      expect(
        LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 7, 8, 12)),
        isFalse,
      );
    });
  });

  test('union across multiple active schedules', () {
    final a = _schedule(packages: {'com.a'}, weekdays: {3});
    final b = _schedule(packages: {'com.b'}, weekdays: {3});
    final now = DateTime(2026, 7, 8, 10);
    expect(
      LockScheduleEvaluator.lockedPackagesAt([a, b], now),
      {'com.a', 'com.b'},
    );
  });

  test('DST-safe: local wall-clock window holds on a spring-forward date', () {
    // US DST began 2026-03-08 (a Sunday). Use a Monday just after so weekday
    // math is unaffected — the point is we operate on local components only.
    final s = _schedule(weekdays: {1}, start: 9 * 60, end: 17 * 60);
    // 2026-03-09 is a Monday.
    expect(
      LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 3, 9, 10)),
      isTrue,
    );
    expect(
      LockScheduleEvaluator.isActiveAt(s, DateTime(2026, 3, 9, 8)),
      isFalse,
    );
  });
}
