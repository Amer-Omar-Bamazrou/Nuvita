import 'health_metric.dart';

export 'health_metric.dart';

// Below [low] is criticalLow, up to and including [normalMax] is normal,
// up to and including [warningMax] is warning, anything higher is criticalHigh.
class StatusBands {
  final double low;
  final double normalMax;
  final double warningMax;

  const StatusBands({
    required this.low,
    required this.normalMax,
    required this.warningMax,
  });

  MetricStatus evaluate(double value) {
    if (value < low) return MetricStatus.criticalLow;
    if (value <= normalMax) return MetricStatus.normal;
    if (value <= warningMax) return MetricStatus.warning;
    return MetricStatus.criticalHigh;
  }
}

class MetricDefinition {
  final HealthMetric metric;
  final String label;
  final String unit;

  // Accepted input range when entering or editing a reading
  final double min;
  final double max;

  // Stepper increment; also decides how many decimals the value shows
  final double step;

  // Null when the metric is logged without a status
  final StatusBands? bands;

  const MetricDefinition({
    required this.metric,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    this.step = 1,
    this.bands,
  });

  String get key => metric.name;

  int get decimals => step < 1 ? 1 : 0;

  bool isInRange(double value) => value >= min && value <= max;
}

// The single source for metric labels, units, input ranges and clinical
// thresholds. Screens, charts, the PDF report and the doctor portal all read
// from here, so a threshold change only ever happens in this file.
class HealthMetrics {
  HealthMetrics._();

  // Systolic and diastolic are shown together under this label
  static const bloodPressureLabel = 'Blood Pressure';

  // Clinical thresholds. These are the values HealthProvider.getStatus used
  // before this module existed. Any change needs clinical review.
  static const _sugarRandom =
      StatusBands(low: 70, normalMax: 180, warningMax: 300);
  static const _sugarBeforeMeal =
      StatusBands(low: 70, normalMax: 99, warningMax: 125);
  static const _sugarAfterMeal =
      StatusBands(low: 70, normalMax: 140, warningMax: 199);
  static const _systolic =
      StatusBands(low: 90, normalMax: 120, warningMax: 140);
  static const _diastolic =
      StatusBands(low: 60, normalMax: 80, warningMax: 90);
  static const _heartRate =
      StatusBands(low: 50, normalMax: 100, warningMax: 120);
  static const _temperature =
      StatusBands(low: 35.5, normalMax: 37.5, warningMax: 38.5);

  static const _definitions = <HealthMetric, MetricDefinition>{
    HealthMetric.bloodSugar: MetricDefinition(
      metric: HealthMetric.bloodSugar,
      label: 'Blood Sugar',
      unit: 'mg/dL',
      min: 20,
      max: 600,
      bands: _sugarRandom,
    ),
    HealthMetric.bloodSugarBefore: MetricDefinition(
      metric: HealthMetric.bloodSugarBefore,
      label: 'Blood Sugar (Before Meal)',
      unit: 'mg/dL',
      min: 20,
      max: 600,
      bands: _sugarBeforeMeal,
    ),
    HealthMetric.bloodSugarAfter: MetricDefinition(
      metric: HealthMetric.bloodSugarAfter,
      label: 'Blood Sugar (After Meal)',
      unit: 'mg/dL',
      min: 20,
      max: 600,
      bands: _sugarAfterMeal,
    ),
    HealthMetric.systolic: MetricDefinition(
      metric: HealthMetric.systolic,
      label: 'Systolic BP',
      unit: 'mmHg',
      min: 50,
      max: 250,
      bands: _systolic,
    ),
    HealthMetric.diastolic: MetricDefinition(
      metric: HealthMetric.diastolic,
      label: 'Diastolic BP',
      unit: 'mmHg',
      min: 30,
      max: 150,
      bands: _diastolic,
    ),
    HealthMetric.heartRate: MetricDefinition(
      metric: HealthMetric.heartRate,
      label: 'Heart Rate',
      unit: 'bpm',
      min: 20,
      max: 250,
      bands: _heartRate,
    ),
    HealthMetric.weight: MetricDefinition(
      metric: HealthMetric.weight,
      label: 'Weight',
      unit: 'kg',
      min: 20,
      max: 300,
      step: 0.1,
    ),
    HealthMetric.steps: MetricDefinition(
      metric: HealthMetric.steps,
      label: 'Walking',
      unit: 'min',
      min: 0,
      max: 300,
    ),
    HealthMetric.temperature: MetricDefinition(
      metric: HealthMetric.temperature,
      label: 'Temperature',
      unit: '°C',
      min: 30,
      max: 45,
      step: 0.1,
      bands: _temperature,
    ),
  };

  static MetricDefinition of(HealthMetric metric) => _definitions[metric]!;

  static StatusBands? bandsFor(HealthMetric metric) => of(metric).bands;

  static MetricStatus? evaluate(HealthMetric metric, double value) =>
      bandsFor(metric)?.evaluate(value);

  // Maps a stored metricType string to its metric, or null if unknown
  static HealthMetric? metricForKey(String key) {
    for (final m in HealthMetric.values) {
      if (m.name == key) return m;
    }
    return null;
  }

  // Display label for a stored key; unknown keys are shown as-is
  static String labelForKey(String key) {
    final metric = metricForKey(key);
    return metric == null ? key : of(metric).label;
  }

  static String unitForKey(String key) {
    final metric = metricForKey(key);
    return metric == null ? '' : of(metric).unit;
  }

  // Picks the more concerning of two statuses, e.g. for a systolic/diastolic pair
  static MetricStatus? worseStatus(MetricStatus? a, MetricStatus? b) =>
      _severity(a) >= _severity(b) ? a : b;

  static int _severity(MetricStatus? status) {
    switch (status) {
      case null:
        return 0;
      case MetricStatus.normal:
        return 1;
      case MetricStatus.warning:
        return 2;
      case MetricStatus.criticalLow:
      case MetricStatus.criticalHigh:
        return 3;
    }
  }

  // Status strings as stored on reading documents
  static String statusLabel(MetricStatus? status) {
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
