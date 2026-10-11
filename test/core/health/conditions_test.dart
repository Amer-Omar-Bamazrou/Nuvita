import 'package:chronic_care_app/core/health/conditions.dart';
import 'package:chronic_care_app/core/health/health_metric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading the profile', () {
    test('the conditions list is used when present', () {
      final c = PatientConditions.fromProfile({
        'conditions': ['diabetes_type2', 'hypertension', 'unknown'],
        'diseaseType': 'heart',
      });
      expect(c.conditions, {Condition.diabetesType2, Condition.hypertension});
      expect(c.hasHeartDisease, isFalse);
    });

    test('old diseaseType values are still understood', () {
      expect(PatientConditions.fromProfile({'diseaseType': 'blood_pressure'})
          .conditions, {Condition.hypertension});
      expect(PatientConditions.fromProfile({'diseaseType': 'heart'})
          .conditions, {Condition.heartDisease});
      expect(PatientConditions.fromProfile({'diseaseType': 'other'})
          .conditions, {Condition.other});

      final diabetes =
          PatientConditions.fromProfile({'diseaseType': 'diabetes'});
      expect(diabetes.isDiabetic, isTrue);
      expect(diabetes.unspecifiedDiabetes, isTrue);
      expect(diabetes.labels, ['Diabetes']);
    });

    test('no profile means no conditions', () {
      expect(PatientConditions.fromProfile(null).isEmpty, isTrue);
      expect(PatientConditions.fromProfile({}).summary, 'General monitoring');
    });
  });

  test('writing keeps diseaseType in step for older readers', () {
    expect(
      const PatientConditions({Condition.hypertension, Condition.diabetesType1})
          .toProfileFields(),
      {
        'conditions': ['diabetes_type1', 'hypertension'],
        'diseaseType': 'diabetes',
      },
    );
    expect(PatientConditions.none.toProfileFields(),
        {'conditions': <String>[], 'diseaseType': 'other'});
  });

  group('defaults', () {
    test('diabetes leads with blood sugar', () {
      const c = PatientConditions({Condition.diabetesType1});
      expect(c.metricOrder.first, HealthMetric.bloodSugar);
      expect(c.defaultChartMetric, HealthMetric.bloodSugar);
    });

    test('hypertension leads with blood pressure', () {
      const c = PatientConditions({Condition.hypertension});
      expect(c.metricOrder.take(2),
          [HealthMetric.systolic, HealthMetric.heartRate]);
      expect(c.defaultChartMetric, HealthMetric.systolic);
    });

    test('heart disease leads with heart rate', () {
      const c = PatientConditions({Condition.heartDisease});
      expect(c.metricOrder.first, HealthMetric.heartRate);
      expect(c.defaultChartMetric, HealthMetric.heartRate);
    });

    test('every metric is still offered, once', () {
      const c = PatientConditions(
          {Condition.heartDisease, Condition.hypertension});
      expect(c.metricOrder.toSet(), HealthMetric.values.toSet());
      expect(c.metricOrder.length, HealthMetric.values.length);
    });

    test('without conditions the usual order and blood pressure chart', () {
      expect(PatientConditions.none.metricOrder.first, HealthMetric.bloodSugar);
      expect(PatientConditions.none.defaultChartMetric, HealthMetric.systolic);
    });
  });
}
