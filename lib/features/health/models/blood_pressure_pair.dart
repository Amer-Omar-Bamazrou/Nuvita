import '../../../core/health/health_metrics.dart';
import 'health_reading.dart';

// Systolic and diastolic are saved as two documents with the same timestamp.
// A pair has at least one side; the other is null when it was never saved.
class BloodPressurePair {
  final HealthReading? systolic;
  final HealthReading? diastolic;

  const BloodPressurePair({this.systolic, this.diastolic})
      : assert(systolic != null || diastolic != null);

  DateTime get timestamp => (systolic ?? diastolic)!.timestamp;

  String? get note => systolic?.note ?? diastolic?.note;

  // The more concerning of the two stored statuses
  String get status => HealthMetrics.statusLabel(HealthMetrics.worseStatus(
        HealthMetrics.statusFromLabel(systolic?.status),
        HealthMetrics.statusFromLabel(diastolic?.status),
      ));
}

bool _sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;

// Matches systolic and diastolic readings taken in the same minute.
// Other metrics are ignored; the input order is kept.
List<BloodPressurePair> pairBloodPressure(List<HealthReading> readings) {
  final bp = readings
      .where((r) =>
          r.metric == HealthMetric.systolic ||
          r.metric == HealthMetric.diastolic)
      .toList();
  final used = List.filled(bp.length, false);
  final pairs = <BloodPressurePair>[];

  for (var i = 0; i < bp.length; i++) {
    if (used[i]) continue;
    used[i] = true;
    final r = bp[i];
    final wantSystolic = r.metric == HealthMetric.diastolic;
    HealthReading? match;
    for (var j = i + 1; j < bp.length; j++) {
      final other = bp[j];
      final isWanted = wantSystolic
          ? other.metric == HealthMetric.systolic
          : other.metric == HealthMetric.diastolic;
      if (!used[j] && isWanted && _sameMinute(other.timestamp, r.timestamp)) {
        used[j] = true;
        match = other;
        break;
      }
    }
    pairs.add(wantSystolic
        ? BloodPressurePair(systolic: match, diastolic: r)
        : BloodPressurePair(systolic: r, diastolic: match));
  }
  return pairs;
}
