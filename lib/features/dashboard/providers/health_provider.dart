import 'package:flutter/material.dart';

// All tracked health metrics across disease types
enum HealthMetric { bloodSugar, systolic, diastolic, heartRate, weight, steps }

// Reading status bands — weight and steps have no threshold so they return null
enum MetricStatus { normal, warning, criticalLow, criticalHigh }

class HealthProvider extends ChangeNotifier {
  // All values start null (no reading entered yet)
  final Map<HealthMetric, double?> _values = {
    for (final m in HealthMetric.values) m: null,
  };

  double? getValue(HealthMetric metric) => _values[metric];

  void updateValue(HealthMetric metric, double value) {
    _values[metric] = value;
    notifyListeners();
  }

  // Returns a short contextual tip when a reading is outside the healthy range.
  // Blood sugar thresholds are in mg/dL (the app's stored unit).
  String? getSuggestionForMetric(String metricKey, double value) {
    switch (metricKey) {
      case 'bloodSugar':
        // 180 mg/dL = 10 mmol/L (high threshold), 72 mg/dL = 4 mmol/L (low threshold)
        if (value > 180) return 'Blood sugar is high — reduce sugary drinks and rest';
        if (value < 72) return 'Blood sugar is low — eat something small now';
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

      // No evaluation needed for these
      case HealthMetric.weight:
      case HealthMetric.steps:
        return null;
    }
  }
}
