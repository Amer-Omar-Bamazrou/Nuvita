import 'package:chronic_care_app/core/services/reminder_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location london;

  setUpAll(() {
    tz_data.initializeTimeZones();
    london = tz.getLocation('Europe/London');
  });

  // UK clocks go forward at 01:00 UTC on Sunday 29 March 2026 and back at
  // 01:00 UTC on Sunday 25 October 2026.

  group('nextInstanceOfTime across daylight-saving changes', () {
    test('evening before clocks go forward: next 08:00 is 08:00 BST', () {
      final now = tz.TZDateTime(london, 2026, 3, 28, 20, 0);
      final next = nextInstanceOfTime(london, 8, 0, now: now);

      expect([next.year, next.month, next.day], [2026, 3, 29]);
      expect([next.hour, next.minute], [8, 0]);
      expect(next.timeZoneOffset, const Duration(hours: 1));
      expect(next.toUtc(), DateTime.utc(2026, 3, 29, 7, 0));
    });

    test('the day before the change: 23 hours to the next reminder', () {
      final now = tz.TZDateTime(london, 2026, 3, 28, 8, 0, 1);
      final next = nextInstanceOfTime(london, 8, 0, now: now);

      expect([next.day, next.hour], [29, 8]);
      // Adding a fixed 24 hours would have landed on 09:00 local
      expect(next.difference(tz.TZDateTime(london, 2026, 3, 28, 8, 0)),
          const Duration(hours: 23));
    });

    test('evening before clocks go back: next 08:00 is 08:00 GMT', () {
      final now = tz.TZDateTime(london, 2026, 10, 24, 22, 0);
      final next = nextInstanceOfTime(london, 8, 0, now: now);

      expect([next.year, next.month, next.day], [2026, 10, 25]);
      expect([next.hour, next.minute], [8, 0]);
      expect(next.timeZoneOffset, Duration.zero);
      expect(next.toUtc(), DateTime.utc(2026, 10, 25, 8, 0));
    });

    test('later today when the time has not passed yet', () {
      final now = tz.TZDateTime(london, 2026, 6, 10, 7, 59);
      final next = nextInstanceOfTime(london, 8, 0, now: now);
      expect([next.day, next.hour, next.minute], [10, 8, 0]);
    });

    test('exactly now counts as now', () {
      final now = tz.TZDateTime(london, 2026, 6, 10, 8, 0);
      final next = nextInstanceOfTime(london, 8, 0, now: now);
      expect(next, now);
    });

    test('a plain DateTime "now" is read as an instant', () {
      final now = DateTime.utc(2026, 3, 28, 20, 0); // 20:00 GMT
      final next = nextInstanceOfTime(london, 8, 0, now: now);
      expect(next.toUtc(), DateTime.utc(2026, 3, 29, 7, 0));
    });
  });

  group('nextInstanceOfDayAndTime', () {
    test('weekly Sunday 10:00 lands on the clock-change Sunday at 10:00', () {
      final now = tz.TZDateTime(london, 2026, 3, 26, 12, 0); // Thursday
      final next = nextInstanceOfDayAndTime(london, DateTime.sunday, 10, 0,
          now: now);

      expect([next.month, next.day, next.hour], [3, 29, 10]);
      expect(next.weekday, DateTime.sunday);
      expect(next.timeZoneOffset, const Duration(hours: 1));
    });

    test('same weekday but time already passed moves a week on', () {
      final now = tz.TZDateTime(london, 2026, 3, 29, 11, 0); // Sunday
      final next = nextInstanceOfDayAndTime(london, DateTime.sunday, 10, 0,
          now: now);
      expect([next.month, next.day, next.hour], [4, 5, 10]);
    });
  });

  test('fixed-offset fallback keeps the wall-clock time for its offset', () {
    final zone = fixedOffsetLocation(const Duration(hours: 3));
    final now = tz.TZDateTime(zone, 2026, 6, 10, 9, 0);
    final next = nextInstanceOfTime(zone, 8, 0, now: now);
    expect([next.day, next.hour], [11, 8]);
    expect(next.toUtc(), DateTime.utc(2026, 6, 11, 5, 0));
  });
}
