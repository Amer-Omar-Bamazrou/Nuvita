import '../models/medication_model.dart';

// Adherence counts for a day or a range.
//   expected — doses whose time has come (taken + missed)
//   pending  — doses later today that aren't due yet; never counted as missed
class AdherenceCounts {
  final int expected;
  final int taken;
  final int missed;
  final int pending;

  const AdherenceCounts({
    this.expected = 0,
    this.taken = 0,
    this.missed = 0,
    this.pending = 0,
  });

  // Share of due doses that were taken; null when nothing was due yet
  double? get rate => expected == 0 ? null : taken / expected;

  // Every dose scheduled for the period has been taken
  bool get isComplete => taken > 0 && missed == 0 && pending == 0;

  bool get hasSchedule => expected + pending > 0;

  AdherenceCounts operator +(AdherenceCounts other) => AdherenceCounts(
        expected: expected + other.expected,
        taken: taken + other.taken,
        missed: missed + other.missed,
        pending: pending + other.pending,
      );
}

class AdherenceReport {
  final AdherenceCounts total;

  // Keyed by local midnight; only days inside the requested range
  final Map<DateTime, AdherenceCounts> byDay;

  const AdherenceReport({required this.total, required this.byDay});
}

const _asNeeded = 'As needed';
const _weekly = 'Weekly';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Whole days between two dates, ignoring daylight-saving hour shifts
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

String _dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

// Same format as the adherence document IDs: yyyy-MM-dd_{medId}_{HH:mm}
String doseKey(DateTime day, String medicationId, String timeSlot) =>
    '${_dateKey(day)}_${medicationId}_$timeSlot';

// True when [med] has doses scheduled on [day]. Inactive and "As needed"
// medications never do; weekly ones repeat on their start date's weekday.
bool isScheduledOn(MedicationModel med, DateTime day) {
  if (!med.isActive || med.frequency == _asNeeded || med.times.isEmpty) {
    return false;
  }
  final daysSinceStart = _daysBetween(med.startDate, day);
  if (daysSinceStart < 0) return false;
  if (med.frequency == _weekly) return daysSinceStart % 7 == 0;
  return true;
}

// Counts expected, taken, missed and pending doses for [medications] on every
// day from [from] to [to] (inclusive). [takenDoses] holds doseKey() strings
// for doses recorded as taken. A dose is due once its time is <= [now].
AdherenceReport calculateAdherence({
  required Iterable<MedicationModel> medications,
  required Set<String> takenDoses,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final start = _dateOnly(from);
  final days = _daysBetween(start, to);
  final byDay = <DateTime, AdherenceCounts>{};
  var total = const AdherenceCounts();

  for (var i = 0; i <= days; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    var expected = 0, taken = 0, missed = 0, pending = 0;

    for (final med in medications) {
      if (!isScheduledOn(med, day)) continue;
      for (final time in med.times) {
        final parts = time.split(':');
        final due = DateTime(day.year, day.month, day.day,
            int.parse(parts[0]), int.parse(parts[1]));
        if (takenDoses.contains(doseKey(day, med.id, time))) {
          expected++;
          taken++;
        } else if (!due.isAfter(now)) {
          expected++;
          missed++;
        } else {
          pending++;
        }
      }
    }

    final counts = AdherenceCounts(
      expected: expected,
      taken: taken,
      missed: missed,
      pending: pending,
    );
    byDay[day] = counts;
    total = total + counts;
  }

  return AdherenceReport(total: total, byDay: byDay);
}
