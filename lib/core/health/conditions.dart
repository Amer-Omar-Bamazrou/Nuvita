import 'health_metric.dart';

// Long-term conditions a patient can record. The id is the value stored in
// the user document's `profile.conditions` list.
enum Condition {
  diabetesType1('diabetes_type1', 'Diabetes type 1'),
  diabetesType2('diabetes_type2', 'Diabetes type 2'),
  hypertension('hypertension', 'Hypertension'),
  heartDisease('heart_disease', 'Heart disease'),
  other('other', 'Other');

  const Condition(this.id, this.label);

  final String id;
  final String label;

  static Condition? fromId(String id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

// A patient's conditions, read from the profile. Older profiles only have a
// single `diseaseType`; it is still understood but never written on its own.
class PatientConditions {
  final Set<Condition> conditions;

  // The old 'diabetes' disease type didn't say which type
  final bool unspecifiedDiabetes;

  const PatientConditions(this.conditions, {this.unspecifiedDiabetes = false});

  static const none = PatientConditions({});

  factory PatientConditions.fromProfile(Map<String, dynamic>? profile) {
    final stored = profile?['conditions'];
    if (stored is List) {
      return PatientConditions(stored
          .whereType<String>()
          .map(Condition.fromId)
          .whereType<Condition>()
          .toSet());
    }
    switch (profile?['diseaseType']) {
      case 'diabetes':
        return const PatientConditions({}, unspecifiedDiabetes: true);
      case 'blood_pressure':
        return const PatientConditions({Condition.hypertension});
      case 'heart':
        return const PatientConditions({Condition.heartDisease});
      case 'other':
        return const PatientConditions({Condition.other});
      default:
        return none;
    }
  }

  bool get isEmpty => conditions.isEmpty && !unspecifiedDiabetes;

  bool get isDiabetic =>
      unspecifiedDiabetes ||
      conditions.contains(Condition.diabetesType1) ||
      conditions.contains(Condition.diabetesType2);

  bool get hasHypertension => conditions.contains(Condition.hypertension);

  bool get hasHeartDisease => conditions.contains(Condition.heartDisease);

  // Display labels in a fixed order
  List<String> get labels => [
        if (unspecifiedDiabetes) 'Diabetes',
        for (final c in Condition.values)
          if (conditions.contains(c)) c.label,
      ];

  String get summary => isEmpty ? 'General monitoring' : labels.join(', ');

  // The single disease type older screens and alert documents read
  String get legacyDiseaseType {
    if (isDiabetic) return 'diabetes';
    if (hasHypertension) return 'blood_pressure';
    if (hasHeartDisease) return 'heart';
    return 'other';
  }

  // Profile fields to write; diseaseType is kept in step for older readers
  Map<String, dynamic> toProfileFields() => {
        'conditions': [
          for (final c in Condition.values)
            if (conditions.contains(c)) c.id,
        ],
        'diseaseType': legacyDiseaseType,
      };

  // Metrics in the order Home offers them: the ones these conditions are
  // monitored with come first, the rest keep their usual order.
  List<HealthMetric> get metricOrder {
    final first = <HealthMetric>[
      if (isDiabetic) HealthMetric.bloodSugar,
      if (hasHypertension) ...[HealthMetric.systolic, HealthMetric.heartRate],
      if (hasHeartDisease) ...[HealthMetric.heartRate, HealthMetric.systolic],
    ];
    const usual = [
      HealthMetric.bloodSugar,
      HealthMetric.systolic,
      HealthMetric.diastolic,
      HealthMetric.heartRate,
      HealthMetric.weight,
      HealthMetric.walkingMinutes,
      HealthMetric.temperature,
    ];
    return {...first, ...usual}.toList();
  }

  // Chart shown first on the patient's Charts screen and the doctor's
  // patient detail. Systolic stands for the combined blood pressure chart.
  HealthMetric get defaultChartMetric {
    if (isDiabetic) return HealthMetric.bloodSugar;
    if (hasHypertension) return HealthMetric.systolic;
    if (hasHeartDisease) return HealthMetric.heartRate;
    return HealthMetric.systolic;
  }
}
