import 'package:flutter/material.dart';
import 'health_provider.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

class HealthHistoryProvider extends ChangeNotifier {
  final List<HealthReading> _readings = []; // maintained newest-first
  final HealthProvider _evaluator = HealthProvider();
  bool _loaded = false;
  bool _hasMore = true;

  List<HealthReading> get allReadings => List.unmodifiable(_readings);

  bool get isLoaded => _loaded;

  bool get hasMore => _hasMore;

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

  Future<void> loadReadings(String uid) async {
    if (_loaded) return;
    try {
      final list = await HealthReadingService.getReadingsPaginated(uid, limit: 30);
      _readings
        ..clear()
        ..addAll(list);
      _hasMore = list.length >= 30;
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> forceReload(String uid) async {
    _loaded = false;
    _hasMore = true;
    _readings.clear();
    notifyListeners();
    await loadReadings(uid);
  }

  Future<void> loadMore(String uid) async {
    if (!_hasMore || _readings.isEmpty) return;
    try {
      final lastTimestamp = _readings.last.timestamp;
      final list = await HealthReadingService.getReadingsPaginated(
          uid, limit: 30, startAfter: lastTimestamp);
      _readings.addAll(list);
      _hasMore = list.length >= 30;
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

  void patchReading(HealthReading original, double newValue, String newStatus,
      {DateTime? newTimestamp}) {
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
    final updated = HealthReading(
      id: old.id,
      metricType: old.metricType,
      value: newValue,
      unit: old.unit,
      status: newStatus,
      timestamp: newTimestamp ?? old.timestamp,
      note: old.note,
    );

    if (newTimestamp != null) {
      _readings.removeAt(i);
      final insertIdx = _readings.indexWhere(
        (r) => r.timestamp.isBefore(updated.timestamp),
      );
      if (insertIdx == -1) {
        _readings.add(updated);
      } else {
        _readings.insert(insertIdx, updated);
      }
    } else {
      _readings[i] = updated;
    }
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
      case HealthMetric.bloodSugarBefore:
      case HealthMetric.bloodSugarAfter:
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
      case HealthMetric.temperature:
        return '°C';
    }
  }
}
