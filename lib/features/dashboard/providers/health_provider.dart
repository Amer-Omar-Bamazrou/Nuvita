import 'package:flutter/material.dart';
import '../../../core/health/health_metrics.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

// Latest value per metric for the current session. Thresholds live in
// HealthMetrics; this provider only remembers what was entered or loaded.
class HealthProvider extends ChangeNotifier {
  // All values start null (no reading entered yet)
  final Map<HealthMetric, double?> _values = {
    for (final m in HealthMetric.values) m: null,
  };

  // Holds the Firebase-loaded baseline so trend arrows can compare against it.
  // These are set once on load and not updated when the user enters new readings.
  final Map<HealthMetric, double?> _previousValues = {
    for (final m in HealthMetric.values) m: null,
  };

  double? getValue(HealthMetric metric) => _values[metric];

  double? getPreviousValue(HealthMetric metric) => _previousValues[metric];

  void updateValue(HealthMetric metric, double value) {
    _values[metric] = value;
    notifyListeners();
  }

  // Returns a short contextual tip when a reading is outside the healthy range.
  // The range itself comes from HealthMetrics so tips and statuses always agree.
  String? getSuggestionForMetric(String metricKey, double value) {
    final metric = HealthMetrics.metricForKey(metricKey);
    if (metric == null) return null;
    final status = HealthMetrics.evaluate(metric, value);
    final high = status == MetricStatus.criticalHigh;
    final aboveNormal = high || status == MetricStatus.warning;
    final low = status == MetricStatus.criticalLow;

    switch (metric) {
      case HealthMetric.bloodSugar:
        if (aboveNormal) return 'Blood sugar is high — reduce sugary drinks and rest';
        if (low) return 'Blood sugar is low — eat something small now';
        return null;
      case HealthMetric.bloodSugarBefore:
        if (high) return 'Fasting glucose is high — avoid late-night snacks';
        if (low) return 'Fasting glucose is low — eat something small now';
        return null;
      case HealthMetric.bloodSugarAfter:
        if (high) return 'Post-meal glucose is very high — limit carbs next meal';
        if (aboveNormal) return 'Post-meal glucose is elevated — consider a short walk';
        if (low) return 'Post-meal glucose is low — drink juice or eat a snack';
        return null;
      case HealthMetric.systolic:
        if (high) return 'BP is elevated — avoid caffeine and rest quietly';
        return null;
      case HealthMetric.heartRate:
        if (aboveNormal) return 'Heart rate is high — try slow deep breathing';
        if (low) return 'Heart rate is low — avoid overexertion today';
        return null;
      case HealthMetric.weight:
        return 'Stay hydrated — drink water regularly';
      case HealthMetric.temperature:
        if (high) return 'Fever detected — rest, stay hydrated, seek care if it persists';
        if (aboveNormal) return 'Slightly elevated temperature — monitor closely';
        if (low) return 'Temperature is low — warm up and monitor';
        return null;
      case HealthMetric.diastolic:
      case HealthMetric.steps:
        return null;
    }
  }

  MetricStatus? getStatus(HealthMetric metric, double value) =>
      HealthMetrics.evaluate(metric, value);

  // Restores the latest reading per metric from Firestore so cards
  // show previous values when the app restarts. Also populates _previousValues
  // so trend arrows have a baseline to compare against new session entries.
  Future<void> loadReadingsFromFirebase(String uid) async {
    try {
      for (final metric in HealthMetric.values) {
        final reading =
            await HealthReadingService.getLatestReading(uid, metric.name);
        if (reading != null) {
          _values[metric] = reading.value;
          _previousValues[metric] = reading.value;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('HealthProvider: loadLatestValues failed: $e');
    }
  }

  // Persists a single reading to Firestore after the local state has been updated.
  Future<void> saveReadingToFirebase(
    String uid,
    HealthMetric metric,
    double value,
    MetricStatus? status,
    String unit,
  ) async {
    try {
      final reading = HealthReading(
        id: '',
        metricType: metric.name,
        value: value,
        unit: unit,
        status: HealthMetrics.statusLabel(status),
        timestamp: DateTime.now(),
      );
      await HealthReadingService.saveReading(uid, reading);
    } catch (e) {
      debugPrint('HealthProvider: saveReading failed: $e');
    }
  }
}
