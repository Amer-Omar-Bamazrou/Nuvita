import 'package:timezone/timezone.dart' as tz;

// Reminder times are wall-clock times in the user's zone. Each candidate is
// built with the TZDateTime constructor instead of adding 24 hours, so a
// reminder set for 08:00 stays at 08:00 across daylight-saving changes.

// The next time [location]'s clock shows hour:minute, at or after [now].
tz.TZDateTime nextInstanceOfTime(
  tz.Location location,
  int hour,
  int minute, {
  DateTime? now,
}) {
  final current = tz.TZDateTime.from(now ?? DateTime.now(), location);
  var scheduled = tz.TZDateTime(
      location, current.year, current.month, current.day, hour, minute);
  if (scheduled.isBefore(current)) {
    scheduled = tz.TZDateTime(
        location, current.year, current.month, current.day + 1, hour, minute);
  }
  return scheduled;
}

// The next [weekday] (DateTime.monday..sunday) at hour:minute, at or after [now].
tz.TZDateTime nextInstanceOfDayAndTime(
  tz.Location location,
  int weekday,
  int hour,
  int minute, {
  DateTime? now,
}) {
  final current = tz.TZDateTime.from(now ?? DateTime.now(), location);
  var dayOffset = 0;
  while (true) {
    final candidate = tz.TZDateTime(location, current.year, current.month,
        current.day + dayOffset, hour, minute);
    if (candidate.weekday == weekday && !candidate.isBefore(current)) {
      return candidate;
    }
    dayOffset++;
  }
}

// A zone with one fixed offset, used only when the device's zone can't be
// resolved. Times stay right until the next daylight-saving change.
tz.Location fixedOffsetLocation(Duration offset) {
  return tz.Location(
    'Device',
    const [],
    const [],
    [tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: '')],
  );
}
