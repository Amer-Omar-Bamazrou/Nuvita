// Every metric a patient can log. The enum name is the `metricType` key
// stored on each reading document in Firestore.
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

// Status bands for a reading. Metrics without thresholds have no status.
enum MetricStatus { normal, warning, criticalLow, criticalHigh }
