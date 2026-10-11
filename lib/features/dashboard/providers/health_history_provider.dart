import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/health/health_metrics.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

// The signed-in user's readings, newest first, kept live from Firestore.
// Saves, edits and deletes (from this device or the doctor's) arrive through
// the query, so nothing has to be patched or reloaded by hand.
class HealthHistoryProvider extends ChangeNotifier {
  static const _pageSize = 30;

  final List<HealthReading> _readings = []; // as the live query returned them

  // Deleted in the UI but still in Firestore while the Undo snackbar is up
  final Set<String> _hidden = {};

  StreamSubscription<List<HealthReading>>? _sub;
  String? _uid;
  int _limit = _pageSize;
  bool _loaded = false;
  bool _hasMore = true;
  bool _loadFailed = false;
  bool _loadingMore = false;

  List<HealthReading> get _visible =>
      _readings.where((r) => !_hidden.contains(r.id)).toList();

  List<HealthReading> get allReadings => List.unmodifiable(_visible);

  bool get isLoaded => _loaded;

  // True when the live query failed; History offers a retry
  bool get loadFailed => _loadFailed;

  bool get hasMore => _hasMore;

  bool get loadingMore => _loadingMore;

  int get todayCount {
    final now = DateTime.now();
    return _visible.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).length;
  }

  // List is newest-first, so the first element is the most recent reading
  DateTime? get lastReadingTime {
    final visible = _visible;
    return visible.isEmpty ? null : visible.first.timestamp;
  }

  // Starts the live query for [uid]; calling it again for the same user
  // keeps the running one
  void watch(String uid) {
    if (_uid == uid && _sub != null && !_loadFailed) return;
    if (_uid != uid) {
      _limit = _pageSize;
      _readings.clear();
      _hidden.clear();
      _loaded = false;
    }
    _uid = uid;
    _subscribe();
  }

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    _sub?.cancel();
    if (_loadFailed) {
      _loadFailed = false;
      notifyListeners();
    }
    _sub = HealthReadingService.watchReadings(uid, limit: _limit).listen(
      (list) {
        _readings
          ..clear()
          ..addAll(list);
        _hidden.removeWhere((id) => !list.any((r) => r.id == id));
        _hasMore = list.length >= _limit;
        _loaded = true;
        _loadFailed = false;
        _loadingMore = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('HealthHistoryProvider: live readings failed: $e');
        _loadFailed = true;
        _loadingMore = false;
        notifyListeners();
      },
    );
  }

  void retry() => _subscribe();

  // Widens the live query by one page of older readings
  void loadMore() {
    if (!_hasMore || _loadingMore || _uid == null) return;
    _loadingMore = true;
    _limit += _pageSize;
    notifyListeners();
    _subscribe();
  }

  // Forgets everything for the previous account (used on sign-out)
  void reset() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _limit = _pageSize;
    _readings.clear();
    _hidden.clear();
    _loaded = false;
    _hasMore = true;
    _loadFailed = false;
    _loadingMore = false;
    notifyListeners();
  }

  // Hides a reading while its delete can still be undone
  void removeReading(HealthReading reading) {
    _hidden.add(reading.id);
    notifyListeners();
  }

  // Undo: shows the reading again
  void restoreReading(HealthReading reading) {
    _hidden.remove(reading.id);
    notifyListeners();
  }

  // Returns readings filtered by metric set, or all if filter is null/empty.
  // Compares metric names as strings since HealthReading uses string-based metricType.
  List<HealthReading> filteredReadings(Set<HealthMetric>? metrics) {
    if (metrics == null || metrics.isEmpty) return allReadings;
    final names = metrics.map((m) => m.name).toSet();
    return _visible.where((r) => names.contains(r.metricType)).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
