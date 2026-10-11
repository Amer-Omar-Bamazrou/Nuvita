import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/health/health_metrics.dart';

class HealthReading {
  final String id;
  final String metricType; // HealthMetric.name; legacy keys are mapped on read
  final double value;
  final String unit;
  final String status; // 'Normal', 'Warning', 'Low', 'High', 'Logged'
  final DateTime timestamp;
  final String? note;
  final GlucoseContext? context; // blood sugar only

  const HealthReading({
    required this.id,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.status,
    required this.timestamp,
    this.note,
    this.context,
  });

  HealthMetric? get metric => HealthMetrics.metricForKey(metricType);

  // e.g. "Blood Sugar (Fasting)"; unknown metrics fall back to the raw key
  String get label {
    final m = metric;
    if (m == null) return metricType;
    return HealthMetrics.readingLabel(m, context: context);
  }

  Map<String, dynamic> toMap() {
    return {
      'metricType': metricType,
      'value': value,
      'unit': unit,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      if (note != null) 'note': note,
      if (context != null) 'context': context!.name,
    };
  }

  factory HealthReading.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['timestamp'];
    final DateTime dt = ts is Timestamp
        ? ts.toDate()
        : ts is int
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : DateTime.now();

    // Support old documents that stored the field as 'metric' instead of 'metricType'
    final rawKey =
        map['metricType'] as String? ?? map['metric'] as String? ?? '';
    // Legacy keys such as bloodSugarBefore become bloodSugar plus a context
    final metric = HealthMetrics.metricForKey(rawKey);

    return HealthReading(
      id: id,
      metricType: metric?.name ?? rawKey,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String? ?? '',
      status: _normalizeStatus(map['status'] as String?),
      timestamp: dt,
      note: map['note'] as String?,
      context: HealthMetrics.contextFromName(map['context'] as String?) ??
          HealthMetrics.legacyContextForKey(rawKey),
    );
  }

  // Old documents stored Dart enum names (e.g. 'criticalHigh').
  // Convert those to the display strings used by the new format.
  static String _normalizeStatus(String? raw) {
    switch (raw) {
      case 'normal':
        return 'Normal';
      case 'warning':
        return 'Warning';
      case 'criticalLow':
        return 'Low';
      case 'criticalHigh':
        return 'High';
      case null:
        return 'Logged';
      default:
        return raw; // already in display format
    }
  }
}
