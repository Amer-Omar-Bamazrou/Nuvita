import 'package:flutter/material.dart';
import 'health_provider.dart';
import '../../health/services/health_log_service.dart';

class HealthReading {
  final HealthMetric metric;
  final double value;
  final MetricStatus? status;
  final DateTime timestamp;

  const HealthReading({
    required this.metric,
    required this.value,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'metric': metric.name,
        'value': value,
        'status': status?.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  static HealthReading? fromMap(Map<String, dynamic> map) {
    try {
      final metric = HealthMetric.values.firstWhere(
        (m) => m.name == map['metric'],
      );
      final statusStr = map['status'] as String?;
      final status = statusStr != null
          ? MetricStatus.values.firstWhere((s) => s.name == statusStr)
          : null;
      return HealthReading(
        metric: metric,
        value: (map['value'] as num).toDouble(),
        status: status,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}

class HealthHistoryProvider extends ChangeNotifier {
  final List<HealthReading> _readings = [];
  final HealthProvider _evaluator = HealthProvider();
  bool _loaded = false;

  List<HealthReading> get allReadings => List.unmodifiable(_readings);

  int get todayCount {
    final now = DateTime.now();
    return _readings.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).length;
  }

  DateTime? get lastReadingTime =>
      _readings.isEmpty ? null : _readings.last.timestamp;

  // Loads readings from Firestore once per session — no-ops on repeat calls
  Future<void> loadReadings(String uid) async {
    if (_loaded) return;
    final maps = await HealthLogService.fetchReadings(uid);
    for (final map in maps) {
      final reading = HealthReading.fromMap(map);
      if (reading != null) _readings.add(reading);
    }
    _loaded = true;
    notifyListeners();
  }

  // Adds to local state immediately; persists to Firestore if uid is provided
  void addReading(HealthMetric metric, double value, {String? uid}) {
    final status = _evaluator.getStatus(metric, value);
    final reading = HealthReading(
      metric: metric,
      value: value,
      status: status,
      timestamp: DateTime.now(),
    );
    _readings.add(reading);
    notifyListeners();
    if (uid != null) {
      HealthLogService.saveReading(uid, reading.toMap());
    }
  }

  // Returns readings filtered by metric set, or all if filter is null/empty.
  // "Blood Pressure" chip maps to both systolic + diastolic.
  List<HealthReading> filteredReadings(Set<HealthMetric>? metrics) {
    if (metrics == null || metrics.isEmpty) return allReadings;
    return _readings.where((r) => metrics.contains(r.metric)).toList();
  }
}
