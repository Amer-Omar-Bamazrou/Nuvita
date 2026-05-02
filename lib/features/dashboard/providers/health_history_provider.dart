import 'package:flutter/material.dart';
import 'health_provider.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

class HealthHistoryProvider extends ChangeNotifier {
  final List<HealthReading> _readings = []; // maintained newest-first
  final HealthProvider _evaluator = HealthProvider();
  bool _loaded = false;

  List<HealthReading> get allReadings => List.unmodifiable(_readings);

  bool get isLoaded => _loaded;

  int get todayCount {
    final now = DateTime.now();
    return _readings.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).length;
  }

  // List is newest-first, so the first element is the most recent reading
  DateTime? get lastReadingTime =>
      _readings.isEmpty ? null : _readings.first.timestamp;

  // Loads the last 90 days of readings from Firestore once per session.
  // No-ops on repeat calls to avoid redundant Firestore fetches.
  Future<void> loadReadings(String uid) async {
    if (_loaded) return;
    try {
      final list = await HealthReadingService.getReadingsLastDays(uid, 90);
      _readings
        ..clear()
        ..addAll(list); // already newest-first from service
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  // Adds a reading to the in-memory list for instant UI update.
  // Firestore persistence is handled separately by HealthProvider.saveReadingToFirebase.
  void addReading(HealthMetric metric, double value) {
    final status = _evaluator.getStatus(metric, value);
    final reading = HealthReading(
      id: '',
      metricType: metric.name,
      value: value,
      unit: _unitForMetric(metric),
      status: _statusString(status),
      timestamp: DateTime.now(),
    );
    _readings.insert(0, reading); // insert at front to keep newest-first order
    notifyListeners();
  }

  // Removes a reading from the in-memory list.
  // Matches by Firestore ID when available, falls back to metricType + timestamp.
  void removeReading(HealthReading reading) {
    if (reading.id.isNotEmpty) {
      _readings.removeWhere((r) => r.id == reading.id);
    } else {
      _readings.removeWhere((r) =>
          r.metricType == reading.metricType &&
          r.timestamp.millisecondsSinceEpoch ==
              reading.timestamp.millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  // Re-inserts a reading while maintaining newest-first order (undo delete).
  void restoreReading(HealthReading reading) {
    final i = _readings.indexWhere(
      (r) => r.timestamp.isBefore(reading.timestamp),
    );
    if (i == -1) {
      _readings.add(reading);
    } else {
      _readings.insert(i, reading);
    }
    notifyListeners();
  }

  // Updates a reading's value and status in the in-memory list.
  void patchReading(HealthReading original, double newValue, String newStatus) {
    int i;
    if (original.id.isNotEmpty) {
      i = _readings.indexWhere((r) => r.id == original.id);
    } else {
      i = _readings.indexWhere((r) =>
          r.metricType == original.metricType &&
          r.timestamp.millisecondsSinceEpoch ==
              original.timestamp.millisecondsSinceEpoch);
    }
    if (i == -1) return;
    final old = _readings[i];
    _readings[i] = HealthReading(
      id: old.id,
      metricType: old.metricType,
      value: newValue,
      unit: old.unit,
      status: newStatus,
      timestamp: old.timestamp,
      note: old.note,
    );
    notifyListeners();
  }

  // Returns readings filtered by metric set, or all if filter is null/empty.
  // Compares metric names as strings since HealthReading uses string-based metricType.
  List<HealthReading> filteredReadings(Set<HealthMetric>? metrics) {
    if (metrics == null || metrics.isEmpty) return allReadings;
    final names = metrics.map((m) => m.name).toSet();
    return _readings.where((r) => names.contains(r.metricType)).toList();
  }

  String _statusString(MetricStatus? status) {
    switch (status) {
      case MetricStatus.normal:
        return 'Normal';
      case MetricStatus.warning:
        return 'Warning';
      case MetricStatus.criticalLow:
        return 'Low';
      case MetricStatus.criticalHigh:
        return 'High';
      case null:
        return 'Logged';
    }
  }

  String _unitForMetric(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.bloodSugar:
        return 'mg/dL';
      case HealthMetric.systolic:
      case HealthMetric.diastolic:
        return 'mmHg';
      case HealthMetric.heartRate:
        return 'BPM';
      case HealthMetric.weight:
        return 'kg';
      case HealthMetric.steps:
        return 'steps';
    }
  }
}
