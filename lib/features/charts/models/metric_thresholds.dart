class MetricThresholds {
  MetricThresholds._();

  // [min, max] inclusive for each band, keyed by Firestore metricType
  static const _normals = <String, List<double>>{
    'systolic':   [90,  120],
    'heartRate':  [60,  100],
    'bloodSugar': [70,  140],
  };

  static const _warnings = <String, List<double>>{
    'systolic':   [121, 139],
    'heartRate':  [101, 120],
    'bloodSugar': [141, 180],
  };

  /// Returns 'Normal', 'Warning', or 'Critical' for a given metricType + value.
  static String getStatus(String metricType, double value) {
    final n = _normals[metricType];
    final w = _warnings[metricType];
    if (n == null || w == null) return 'Logged';
    if (value >= n[0] && value <= n[1]) return 'Normal';
    if (value >= w[0] && value <= w[1]) return 'Warning';
    return 'Critical';
  }

  static (double, double) getNormalRange(String metricType) {
    final r = _normals[metricType] ?? [0, 100];
    return (r[0], r[1]);
  }

  static (double, double) getWarningRange(String metricType) {
    final r = _warnings[metricType] ?? [0, 100];
    return (r[0], r[1]);
  }
}
