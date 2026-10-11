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
  // Blood sugar bands depend on the reading's context: fasting and before-meal
  // use the old bloodSugarBefore bands, after-meal the old bloodSugarAfter
  // bands, and random (or no context) the old general bloodSugar bands.
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

  // Older documents used these keys. They are still read, never written.
  static const _legacyKeys = <String, (HealthMetric, GlucoseContext?)>{
    'bloodSugarBefore': (HealthMetric.bloodSugar, GlucoseContext.beforeMeal),
    'bloodSugarAfter': (HealthMetric.bloodSugar, GlucoseContext.afterMeal),
  };

  static MetricDefinition of(HealthMetric metric) => _definitions[metric]!;

  // Bands for a reading. Only blood sugar looks at the context.
  static StatusBands? bandsFor(HealthMetric metric, {GlucoseContext? context}) {
    if (metric != HealthMetric.bloodSugar) return of(metric).bands;
    switch (context) {
      case GlucoseContext.fasting:
      case GlucoseContext.beforeMeal:
        return _sugarBeforeMeal;
      case GlucoseContext.afterMeal:
        return _sugarAfterMeal;
      case GlucoseContext.random:
      case null:
        return _sugarRandom;
    }
  }

  static MetricStatus? evaluate(
    HealthMetric metric,
    double value, {
    GlucoseContext? context,
  }) =>
      bandsFor(metric, context: context)?.evaluate(value);

  // Maps a stored metricType string, including legacy keys, to its metric.
  // Returns null for keys the app doesn't know.
  static HealthMetric? metricForKey(String key) {
    final legacy = _legacyKeys[key];
    if (legacy != null) return legacy.$1;
    for (final m in HealthMetric.values) {
      if (m.name == key) return m;
    }
    return null;
  }

  // Context implied by a legacy key, e.g. bloodSugarAfter -> afterMeal
  static GlucoseContext? legacyContextForKey(String key) =>
      _legacyKeys[key]?.$2;

  // Every key a metric may be stored under, for Firestore whereIn queries
  static List<String> storedKeysFor(HealthMetric metric) => [
        metric.name,
        for (final e in _legacyKeys.entries)
          if (e.value.$1 == metric) e.key,
      ];

  static GlucoseContext? contextFromName(String? name) {
    for (final c in GlucoseContext.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static String contextLabel(GlucoseContext context) {
    switch (context) {
      case GlucoseContext.fasting:
        return 'Fasting';
      case GlucoseContext.beforeMeal:
        return 'Before meal';
      case GlucoseContext.afterMeal:
        return 'After meal';
      case GlucoseContext.random:
        return 'Random';
    }
  }

  // Label for one reading, e.g. "Blood Sugar (Fasting)"
  static String readingLabel(HealthMetric metric, {GlucoseContext? context}) {
    final label = of(metric).label;
    if (metric != HealthMetric.bloodSugar || context == null) return label;
    return '$label (${contextLabel(context)})';
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

  // Reverse of statusLabel; 'Logged' and unknown strings give null
  static MetricStatus? statusFromLabel(String? label) {
    switch (label) {
      case 'Normal':
        return MetricStatus.normal;
      case 'Warning':
        return MetricStatus.warning;
      case 'Low':
        return MetricStatus.criticalLow;
      case 'High':
        return MetricStatus.criticalHigh;
      default:
        return null;
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
