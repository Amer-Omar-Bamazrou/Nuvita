import 'package:chronic_care_app/core/health/health_metrics.dart';
import 'package:chronic_care_app/features/health/models/blood_pressure_pair.dart';
import 'package:chronic_care_app/features/health/models/health_reading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _doc(String key, {Object? status, Object? context}) => {
      'metricType': key,
      'value': 110,
      'unit': 'mg/dL',
      'status': ?status,
      'timestamp': Timestamp.fromDate(DateTime(2026, 5, 4, 8, 30)),
      'context': ?context,
    };

void main() {
  group('HealthReading.fromMap legacy keys', () {
    test('bloodSugarBefore becomes bloodSugar before a meal', () {
      final r = HealthReading.fromMap('a', _doc('bloodSugarBefore'));
      expect(r.metricType, 'bloodSugar');
      expect(r.metric, HealthMetric.bloodSugar);
      expect(r.context, GlucoseContext.beforeMeal);
      expect(r.label, 'Blood Sugar (Before meal)');
    });

    test('bloodSugarAfter becomes bloodSugar after a meal', () {
      final r = HealthReading.fromMap('a', _doc('bloodSugarAfter'));
      expect(r.metricType, 'bloodSugar');
      expect(r.context, GlucoseContext.afterMeal);
    });

    test('steps becomes walkingMinutes', () {
      final r = HealthReading.fromMap('a', _doc('steps'));
      expect(r.metricType, 'walkingMinutes');
      expect(r.metric, HealthMetric.walkingMinutes);
      expect(r.context, isNull);
    });

    test('a stored context wins over the one implied by a legacy key', () {
      final r = HealthReading.fromMap(
          'a', _doc('bloodSugarAfter', context: 'random'));
      expect(r.context, GlucoseContext.random);
    });

    test('new blood sugar documents read their context field', () {
      final r =
          HealthReading.fromMap('a', _doc('bloodSugar', context: 'fasting'));
      expect(r.metricType, 'bloodSugar');
      expect(r.context, GlucoseContext.fasting);
    });

    test('unknown context strings are ignored', () {
      final r =
          HealthReading.fromMap('a', _doc('bloodSugar', context: 'brunch'));
      expect(r.context, isNull);
    });

    test("old 'metric' field is read when 'metricType' is missing", () {
      final map = _doc('x')..remove('metricType');
      map['metric'] = 'heartRate';
      final r = HealthReading.fromMap('a', map);
      expect(r.metricType, 'heartRate');
    });

    test('unknown metric keys are kept as-is', () {
      final r = HealthReading.fromMap('a', _doc('cholesterol'));
      expect(r.metricType, 'cholesterol');
      expect(r.metric, isNull);
      expect(r.label, 'cholesterol');
    });
  });

  group('HealthReading.fromMap status mapping', () {
    final cases = {
      'normal': 'Normal',
      'warning': 'Warning',
      'criticalLow': 'Low',
      'criticalHigh': 'High',
      'Normal': 'Normal',
      'High': 'High',
      'Logged': 'Logged',
    };
    cases.forEach((stored, expected) {
      test('$stored -> $expected', () {
        final r = HealthReading.fromMap('a', _doc('heartRate', status: stored));
        expect(r.status, expected);
      });
    });

    test('missing status is Logged', () {
      final r = HealthReading.fromMap('a', _doc('heartRate'));
      expect(r.status, 'Logged');
    });
  });

  group('HealthReading timestamps and round-trip', () {
    test('Timestamp and epoch millis are both read', () {
      final when = DateTime(2026, 5, 4, 8, 30);
      final fromTs = HealthReading.fromMap('a', _doc('weight'));
      final fromInt = HealthReading.fromMap(
          'a', _doc('weight')..['timestamp'] = when.millisecondsSinceEpoch);
      expect(fromTs.timestamp, when);
      expect(fromInt.timestamp, when);
    });

    test('toMap then fromMap keeps every field', () {
      final original = HealthReading(
        id: 'r1',
        metricType: 'bloodSugar',
        value: 142,
        unit: 'mg/dL',
        status: 'Warning',
        timestamp: DateTime(2026, 2, 1, 7, 15),
        note: 'Before breakfast',
        context: GlucoseContext.fasting,
      );
      final map = original.toMap();
      expect(map['context'], 'fasting');
      final copy = HealthReading.fromMap('r1', map);
      expect(copy.id, 'r1');
      expect(copy.metricType, 'bloodSugar');
      expect(copy.value, 142);
      expect(copy.unit, 'mg/dL');
      expect(copy.status, 'Warning');
      expect(copy.timestamp, original.timestamp);
      expect(copy.note, 'Before breakfast');
      expect(copy.context, GlucoseContext.fasting);
    });

    test('toMap leaves out context and note when absent', () {
      final map = HealthReading(
        id: '',
        metricType: 'weight',
        value: 70,
        unit: 'kg',
        status: 'Logged',
        timestamp: DateTime(2026),
      ).toMap();
      expect(map.containsKey('context'), isFalse);
      expect(map.containsKey('note'), isFalse);
    });
  });

  group('pairBloodPressure', () {
    HealthReading r(String key, double v, DateTime t, String status) =>
        HealthReading(
          id: '$key$v',
          metricType: key,
          value: v,
          unit: 'mmHg',
          status: status,
          timestamp: t,
        );

    test('pairs systolic and diastolic from the same minute', () {
      final t = DateTime(2026, 3, 1, 9, 0);
      final pairs = pairBloodPressure([
        r('systolic', 135, t, 'Warning'),
        r('heartRate', 70, t, 'Normal'),
        r('diastolic', 85, t.add(const Duration(seconds: 20)), 'Warning'),
        r('systolic', 118, DateTime(2026, 3, 1, 8, 0), 'Normal'),
      ]);
      expect(pairs, hasLength(2));
      expect(pairs[0].systolic!.value, 135);
      expect(pairs[0].diastolic!.value, 85);
      expect(pairs[1].systolic!.value, 118);
      expect(pairs[1].diastolic, isNull);
    });

    test('the pair status is the worse of the two', () {
      final t = DateTime(2026, 3, 1, 9, 0);
      final pair = pairBloodPressure([
        r('systolic', 150, t, 'High'),
        r('diastolic', 78, t, 'Normal'),
      ]).single;
      expect(pair.status, 'High');
    });
  });
}
