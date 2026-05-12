import 'package:flutter/material.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';

// All tracked health metrics across disease types
enum HealthMetric {
  bloodSugar,
  bloodSugarBefore,
  bloodSugarAfter,
  systolic,
  diastolic,
  heartRate,
  weight,
  steps,
  temperature,
}

// Reading status bands — weight and steps have no threshold so they return null
enum MetricStatus { normal, warning, criticalLow, criticalHigh }

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
  // Blood sugar thresholds are in mg/dL (the app's stored unit).
  String? getSuggestionForMetric(String metricKey, double value) {
    switch (metricKey) {
      case 'bloodSugar':
        if (value > 180) return 'Blood sugar is high — reduce sugary drinks and rest';
        if (value < 72) return 'Blood sugar is low — eat something small now';
        return null;
      case 'bloodSugarBefore':
        if (value > 125) return 'Fasting glucose is high — avoid late-night snacks';
        if (value < 70) return 'Fasting glucose is low — eat something small now';
        return null;
      case 'bloodSugarAfter':
        if (value > 199) return 'Post-meal glucose is very high — limit carbs next meal';
        if (value > 140) return 'Post-meal glucose is elevated — consider a short walk';
        if (value < 70) return 'Post-meal glucose is low — drink juice or eat a snack';
        return null;
      case 'systolic':
        if (value > 140) return 'BP is elevated — avoid caffeine and rest quietly';
        return null;
      case 'heartRate':
        if (value > 100) return 'Heart rate is high — try slow deep breathing';
        if (value < 55) return 'Heart rate is low — avoid overexertion today';
        return null;
      case 'steps':
        if (value < 3000) return 'Low steps today — a short walk would help';
        return null;
      case 'weight':
        return 'Stay hydrated — drink water regularly';
      case 'temperature':
        if (value > 38.5) return 'Fever detected — rest, stay hydrated, seek care if it persists';
        if (value > 37.5) return 'Slightly elevated temperature — monitor closely';
        if (value < 35.5) return 'Temperature is low — warm up and monitor';
        return null;
      default:
        return null;
    }
  }

  // Evaluates a reading against clinical thresholds.
  // Returns null for metrics that have no status evaluation.
  MetricStatus? getStatus(HealthMetric metric, double value) {
    switch (metric) {
      case HealthMetric.bloodSugar:
        if (value < 70) return MetricStatus.criticalLow;
        if (value <= 180) return MetricStatus.normal;
        if (value <= 300) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.bloodSugarBefore:
        if (value < 70) return MetricStatus.criticalLow;
        if (value <= 99) return MetricStatus.normal;
        if (value <= 125) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.bloodSugarAfter:
        if (value < 70) return MetricStatus.criticalLow;
        if (value <= 140) return MetricStatus.normal;
        if (value <= 199) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.systolic:
        if (value < 90) return MetricStatus.criticalLow;
        if (value <= 120) return MetricStatus.normal;
        if (value <= 140) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.diastolic:
        if (value < 60) return MetricStatus.criticalLow;
        if (value <= 80) return MetricStatus.normal;
        if (value <= 90) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.heartRate:
        if (value < 50) return MetricStatus.criticalLow;
        if (value <= 100) return MetricStatus.normal;
        if (value <= 120) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      case HealthMetric.temperature:
        if (value < 35.5) return MetricStatus.criticalLow;
        if (value <= 37.5) return MetricStatus.normal;
        if (value <= 38.5) return MetricStatus.warning;
        return MetricStatus.criticalHigh;

      // No evaluation needed for these
      case HealthMetric.weight:
      case HealthMetric.steps:
        return null;
    }
  }

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
    } catch (_) {}
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
        status: _statusString(status),
        timestamp: DateTime.now(),
      );
      await HealthReadingService.saveReading(uid, reading);
    } catch (_) {}
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
}
