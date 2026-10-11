// Every metric a patient can log. The enum name is the `metricType` key
// stored on each reading document in Firestore.
enum HealthMetric {
  bloodSugar,
  systolic,
  diastolic,
  heartRate,
  weight,
  walkingMinutes, // stored as 'steps' before it was renamed
  temperature,
}

// Status bands for a reading. Metrics without thresholds have no status.
enum MetricStatus { normal, warning, criticalLow, criticalHigh }

// When a blood sugar reading was taken, stored in the reading's `context`
// field. The enum name is the stored value.
enum GlucoseContext { fasting, beforeMeal, afterMeal, random }
