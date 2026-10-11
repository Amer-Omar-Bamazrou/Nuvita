import '../../../core/health/health_metrics.dart';

// One value entered on a reading screen, before it is saved
class ReadingEntry {
  final HealthMetric metric;
  final double value;
  final GlucoseContext? context; // blood sugar only
  final String? note; // the context chip the user picked, if any

  const ReadingEntry({
    required this.metric,
    required this.value,
    this.context,
    this.note,
  });
}

// Saves entries that were taken together and share one timestamp.
// Throws ReadingSaveException when the save can't go ahead.
typedef SaveReadings = Future<void> Function(
    List<ReadingEntry> entries, DateTime when);

// A save that was refused for a reason the user can act on.
// The message is shown as-is on the reading screen.
class ReadingSaveException implements Exception {
  final String message;
  const ReadingSaveException(this.message);

  @override
  String toString() => message;
}
