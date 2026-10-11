import 'package:flutter/material.dart';
import '../../../core/health/health_metrics.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

class HealthHistoryProvider extends ChangeNotifier {
  final List<HealthReading> _readings = []; // maintained newest-first
  bool _loaded = false;
  bool _hasMore = true;

  // Bumped by reset() so a fetch that started for the previous account
  // can't refill the list after sign-out
  int _generation = 0;

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
    final generation = _generation;
    try {
      final list = await HealthReadingService.getReadingsPaginated(uid, limit: 30);
      if (generation != _generation) return;
      _readings
        ..clear()
        ..addAll(list);
      _hasMore = list.length >= 30;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('HealthHistoryProvider: loadReadings failed: $e');
    }
  }

  // Forgets everything loaded for the previous account (used on sign-out)
  void reset() {
    _generation++;
    _readings.clear();
    _loaded = false;
    _hasMore = true;
    notifyListeners();
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
    final generation = _generation;
    try {
      final lastTimestamp = _readings.last.timestamp;
      final list = await HealthReadingService.getReadingsPaginated(
          uid, limit: 30, startAfter: lastTimestamp);
      if (generation != _generation) return;
      _readings.addAll(list);
      _hasMore = list.length >= 30;
      notifyListeners();
    } catch (e) {
      debugPrint('HealthHistoryProvider: loadMore failed: $e');
    }
  }

  // Adds a just-saved reading (with its Firestore ID and chosen time) to the
  // list so it shows on the right day and can be edited or deleted at once.
  void addReading(HealthReading reading) {
    // Older than everything loaded so far while more pages exist: it will
    // arrive with "Load older readings", and inserting it now would make
    // pagination skip the readings in between.
    if (_hasMore &&
        _readings.isNotEmpty &&
        reading.timestamp.isBefore(_readings.last.timestamp)) {
      return;
    }
    final i = _readings.indexWhere((r) => r.timestamp.isBefore(reading.timestamp));
    if (i == -1) {
      _readings.add(reading);
    } else {
      _readings.insert(i, reading);
    }
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
      context: old.context,
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
}
