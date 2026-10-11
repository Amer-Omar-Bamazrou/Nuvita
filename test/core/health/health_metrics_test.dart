import 'package:chronic_care_app/core/health/health_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

// Clinical thresholds are pinned here on purpose: a change to any band should
// fail these tests and go through clinical review.
void main() {
  // low / normalMax / warningMax for each evaluated metric
  void expectBands(
    String name,
    MetricStatus? Function(double v) evaluate, {
    required double low,
    required double normalMax,
    required double warningMax,
    double step = 0.1,
  }) {
    group(name, () {
      test('just below low is criticalLow', () {
        expect(evaluate(low - step), MetricStatus.criticalLow);
      });
      test('low itself is normal', () {
        expect(evaluate(low), MetricStatus.normal);
      });
      test('normal max is normal', () {
        expect(evaluate(normalMax), MetricStatus.normal);
      });
      test('just above normal max is warning', () {
        expect(evaluate(normalMax + step), MetricStatus.warning);
      });
      test('warning max is warning', () {
        expect(evaluate(warningMax), MetricStatus.warning);
      });
      test('just above warning max is criticalHigh', () {
        expect(evaluate(warningMax + step), MetricStatus.criticalHigh);
      });
    });
  }

  group('status bands', () {
    expectBands(
      'blood sugar, no context (random bands)',
      (v) => HealthMetrics.evaluate(HealthMetric.bloodSugar, v),
      low: 70,
      normalMax: 180,
      warningMax: 300,
    );
    expectBands(
      'blood sugar, random',
      (v) => HealthMetrics.evaluate(HealthMetric.bloodSugar, v,
          context: GlucoseContext.random),
      low: 70,
      normalMax: 180,
      warningMax: 300,
    );
    expectBands(
      'blood sugar, fasting',
      (v) => HealthMetrics.evaluate(HealthMetric.bloodSugar, v,
          context: GlucoseContext.fasting),
      low: 70,
      normalMax: 99,
      warningMax: 125,
    );
    expectBands(
      'blood sugar, before meal',
      (v) => HealthMetrics.evaluate(HealthMetric.bloodSugar, v,
          context: GlucoseContext.beforeMeal),
      low: 70,
      normalMax: 99,
      warningMax: 125,
    );
    expectBands(
      'blood sugar, after meal',
      (v) => HealthMetrics.evaluate(HealthMetric.bloodSugar, v,
          context: GlucoseContext.afterMeal),
      low: 70,
      normalMax: 140,
      warningMax: 199,
    );
    expectBands(
      'systolic',
      (v) => HealthMetrics.evaluate(HealthMetric.systolic, v),
      low: 90,
      normalMax: 120,
      warningMax: 140,
    );
    expectBands(
      'diastolic',
      (v) => HealthMetrics.evaluate(HealthMetric.diastolic, v),
      low: 60,
      normalMax: 80,
      warningMax: 90,
    );
    expectBands(
      'heart rate',
      (v) => HealthMetrics.evaluate(HealthMetric.heartRate, v),
      low: 50,
      normalMax: 100,
      warningMax: 120,
    );
    expectBands(
      'temperature',
      (v) => HealthMetrics.evaluate(HealthMetric.temperature, v),
      low: 35.5,
      normalMax: 37.5,
      warningMax: 38.5,
    );

    test('weight and walking minutes have no status', () {
      expect(HealthMetrics.evaluate(HealthMetric.weight, 80), isNull);
      expect(HealthMetrics.evaluate(HealthMetric.walkingMinutes, 0), isNull);
      expect(HealthMetrics.bandsFor(HealthMetric.weight), isNull);
      expect(HealthMetrics.bandsFor(HealthMetric.walkingMinutes), isNull);
    });

    test('context is ignored for metrics other than blood sugar', () {
      expect(
        HealthMetrics.evaluate(HealthMetric.systolic, 130,
            context: GlucoseContext.fasting),
        MetricStatus.warning,
      );
    });
  });

  group('definitions', () {
    test('every metric has a label, unit and a sensible input range', () {
      for (final m in HealthMetric.values) {
        final def = HealthMetrics.of(m);
        expect(def.key, m.name);
        expect(def.label, isNotEmpty);
        expect(def.unit, isNotEmpty);
        expect(def.min, lessThan(def.max));
      }
    });

    test('input ranges', () {
      void range(HealthMetric m, double min, double max) {
        final def = HealthMetrics.of(m);
        expect([def.min, def.max], [min, max], reason: m.name);
        expect(def.isInRange(min), isTrue);
        expect(def.isInRange(max), isTrue);
        expect(def.isInRange(min - 0.1), isFalse);
        expect(def.isInRange(max + 0.1), isFalse);
      }

      range(HealthMetric.bloodSugar, 20, 600);
      range(HealthMetric.systolic, 50, 250);
      range(HealthMetric.diastolic, 30, 150);
      range(HealthMetric.heartRate, 20, 250);
      range(HealthMetric.weight, 20, 300);
      range(HealthMetric.walkingMinutes, 0, 300);
      range(HealthMetric.temperature, 30, 45);
    });

    test('walking is minutes, temperature is Celsius', () {
      expect(HealthMetrics.of(HealthMetric.walkingMinutes).label, 'Walking');
      expect(HealthMetrics.of(HealthMetric.walkingMinutes).unit, 'min');
      expect(HealthMetrics.of(HealthMetric.temperature).unit, '°C');
      expect(HealthMetrics.of(HealthMetric.temperature).decimals, 1);
    });
  });

  group('stored keys', () {
    test('current keys map to their metric', () {
      for (final m in HealthMetric.values) {
        expect(HealthMetrics.metricForKey(m.name), m);
      }
    });

    test('legacy keys map to the current metric and context', () {
      expect(HealthMetrics.metricForKey('bloodSugarBefore'),
          HealthMetric.bloodSugar);
      expect(HealthMetrics.legacyContextForKey('bloodSugarBefore'),
          GlucoseContext.beforeMeal);
      expect(HealthMetrics.metricForKey('bloodSugarAfter'),
          HealthMetric.bloodSugar);
      expect(HealthMetrics.legacyContextForKey('bloodSugarAfter'),
          GlucoseContext.afterMeal);
      expect(HealthMetrics.metricForKey('steps'), HealthMetric.walkingMinutes);
      expect(HealthMetrics.legacyContextForKey('steps'), isNull);
    });

    test('unknown keys are not mapped', () {
      expect(HealthMetrics.metricForKey('cholesterol'), isNull);
      expect(HealthMetrics.labelForKey('cholesterol'), 'cholesterol');
      expect(HealthMetrics.unitForKey('cholesterol'), '');
    });

    test('storedKeysFor includes legacy aliases for queries', () {
      expect(HealthMetrics.storedKeysFor(HealthMetric.bloodSugar),
          unorderedEquals(['bloodSugar', 'bloodSugarBefore', 'bloodSugarAfter']));
      expect(HealthMetrics.storedKeysFor(HealthMetric.walkingMinutes),
          unorderedEquals(['walkingMinutes', 'steps']));
      expect(HealthMetrics.storedKeysFor(HealthMetric.weight), ['weight']);
    });
  });

  group('labels and statuses', () {
    test('reading label shows blood sugar context only', () {
      expect(
        HealthMetrics.readingLabel(HealthMetric.bloodSugar,
            context: GlucoseContext.fasting),
        'Blood Sugar (Fasting)',
      );
      expect(HealthMetrics.readingLabel(HealthMetric.bloodSugar),
          'Blood Sugar');
      expect(HealthMetrics.readingLabel(HealthMetric.weight), 'Weight');
    });

    test('status labels round-trip', () {
      for (final s in MetricStatus.values) {
        expect(HealthMetrics.statusFromLabel(HealthMetrics.statusLabel(s)), s);
      }
      expect(HealthMetrics.statusLabel(null), 'Logged');
      expect(HealthMetrics.statusFromLabel('Logged'), isNull);
    });

    test('worseStatus picks the more concerning one', () {
      expect(
        HealthMetrics.worseStatus(MetricStatus.normal, MetricStatus.warning),
        MetricStatus.warning,
      );
      expect(
        HealthMetrics.worseStatus(
            MetricStatus.criticalLow, MetricStatus.warning),
        MetricStatus.criticalLow,
      );
      expect(HealthMetrics.worseStatus(null, MetricStatus.normal),
          MetricStatus.normal);
    });
  });
}
