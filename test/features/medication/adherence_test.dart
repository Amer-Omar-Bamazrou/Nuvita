import 'package:chronic_care_app/features/medication/models/medication_model.dart';
import 'package:chronic_care_app/features/medication/services/adherence.dart';
import 'package:flutter_test/flutter_test.dart';

MedicationModel _med(
  String id, {
  List<String> times = const ['08:00', '20:00'],
  String frequency = 'Twice daily',
  DateTime? start,
  bool active = true,
}) =>
    MedicationModel(
      id: id,
      name: id,
      dosage: '1 tablet',
      frequency: frequency,
      times: times,
      startDate: start ?? DateTime(2026, 1, 1),
      isActive: active,
    );

void main() {
  // Wednesday 10 June 2026, midday
  final now = DateTime(2026, 6, 10, 12, 0);
  final today = DateTime(2026, 6, 10);

  group('doses not yet due today', () {
    test('a later dose today is pending, not missed', () {
      final report = calculateAdherence(
        medications: [_med('a')],
        takenDoses: {doseKey(today, 'a', '08:00')},
        from: today,
        to: today,
        now: now,
      );
      final t = report.total;
      expect(t.expected, 1); // only 08:00 was due
      expect(t.taken, 1);
      expect(t.missed, 0);
      expect(t.pending, 1); // 20:00
      expect(t.rate, 1.0);
      expect(t.isComplete, isFalse);
    });

    test('a due dose that was not taken is missed', () {
      final t = calculateAdherence(
        medications: [_med('a')],
        takenDoses: {},
        from: today,
        to: today,
        now: now,
      ).total;
      expect(t.expected, 1);
      expect(t.missed, 1);
      expect(t.pending, 1);
      expect(t.rate, 0);
    });

    test('a dose due exactly now counts as due', () {
      final t = calculateAdherence(
        medications: [_med('a', times: const ['12:00'])],
        takenDoses: {},
        from: today,
        to: today,
        now: now,
      ).total;
      expect(t.missed, 1);
      expect(t.pending, 0);
    });

    test('taking a dose early counts it as taken', () {
      final t = calculateAdherence(
        medications: [_med('a')],
        takenDoses: {
          doseKey(today, 'a', '08:00'),
          doseKey(today, 'a', '20:00'),
        },
        from: today,
        to: today,
        now: now,
      ).total;
      expect(t.expected, 2);
      expect(t.taken, 2);
      expect(t.pending, 0);
      expect(t.isComplete, isTrue);
    });

    test('before any dose is due there is no rate', () {
      final t = calculateAdherence(
        medications: [_med('a')],
        takenDoses: {},
        from: today,
        to: today,
        now: DateTime(2026, 6, 10, 7, 0),
      ).total;
      expect(t.expected, 0);
      expect(t.pending, 2);
      expect(t.rate, isNull);
    });
  });

  group('ranges', () {
    test('a medication started mid-range only counts from its start date', () {
      final report = calculateAdherence(
        medications: [_med('a', start: DateTime(2026, 6, 8, 15, 30))],
        takenDoses: {
          doseKey(DateTime(2026, 6, 8), 'a', '08:00'),
          doseKey(DateTime(2026, 6, 9), 'a', '08:00'),
          doseKey(DateTime(2026, 6, 9), 'a', '20:00'),
        },
        from: DateTime(2026, 6, 4),
        to: today,
        now: now,
      );

      // 4–7 June: nothing scheduled
      for (var d = 4; d <= 7; d++) {
        expect(report.byDay[DateTime(2026, 6, d)]!.hasSchedule, isFalse,
            reason: 'June $d');
      }
      // 8 June: 08:00 taken, 20:00 missed
      final june8 = report.byDay[DateTime(2026, 6, 8)]!;
      expect([june8.expected, june8.taken, june8.missed], [2, 1, 1]);
      // 9 June: both taken
      expect(report.byDay[DateTime(2026, 6, 9)]!.isComplete, isTrue);

      final t = report.total;
      expect(t.expected, 5); // 2 + 2 + today's 08:00
      expect(t.taken, 3);
      expect(t.missed, 2);
      expect(t.pending, 1);
      expect(report.byDay.length, 7);
    });

    test('a dose recorded before the start date is ignored', () {
      final t = calculateAdherence(
        medications: [_med('a', start: today)],
        takenDoses: {doseKey(DateTime(2026, 6, 9), 'a', '08:00')},
        from: DateTime(2026, 6, 9),
        to: today,
        now: now,
      ).total;
      expect(t.taken, 0);
      expect(t.expected, 1);
    });

    test('doses for times no longer on the schedule are ignored', () {
      final t = calculateAdherence(
        medications: [_med('a', times: const ['09:00'])],
        takenDoses: {doseKey(today, 'a', '07:30')},
        from: today,
        to: today,
        now: now,
      ).total;
      expect(t.taken, 0);
      expect(t.missed, 1);
    });
  });

  group('excluded medications', () {
    test('an inactive medication contributes nothing', () {
      final report = calculateAdherence(
        medications: [_med('a', active: false)],
        takenDoses: {doseKey(today, 'a', '08:00')},
        from: DateTime(2026, 6, 1),
        to: today,
        now: now,
      );
      final t = report.total;
      expect([t.expected, t.taken, t.missed, t.pending], [0, 0, 0, 0]);
      expect(isScheduledOn(_med('a', active: false), today), isFalse);
    });

    test('"As needed" medications are excluded', () {
      final t = calculateAdherence(
        medications: [
          _med('prn', frequency: 'As needed', times: const ['08:00']),
          _med('b', times: const ['08:00']),
        ],
        takenDoses: {},
        from: today,
        to: today,
        now: now,
      ).total;
      expect(t.expected, 1); // only "b"
      expect(t.missed, 1);
    });

    test('weekly medications count only on their start weekday', () {
      // Started Wednesday 3 June; due again Wednesday 10 June
      final weekly = _med('w',
          frequency: 'Weekly',
          times: const ['08:00'],
          start: DateTime(2026, 6, 3));
      final report = calculateAdherence(
        medications: [weekly],
        takenDoses: {doseKey(DateTime(2026, 6, 3), 'w', '08:00')},
        from: DateTime(2026, 6, 3),
        to: today,
        now: now,
      );
      final scheduledDays = report.byDay.entries
          .where((e) => e.value.hasSchedule)
          .map((e) => e.key)
          .toList();
      expect(scheduledDays, [DateTime(2026, 6, 3), DateTime(2026, 6, 10)]);
      expect(report.total.taken, 1);
      expect(report.total.missed, 1);
    });
  });

  test('days are not lost or doubled across a daylight-saving change', () {
    // UK clocks went forward on 29 March 2026 and back on 25 October 2026
    final spring = calculateAdherence(
      medications: [_med('a', times: const ['08:00'])],
      takenDoses: {},
      from: DateTime(2026, 3, 27),
      to: DateTime(2026, 3, 31),
      now: DateTime(2026, 4, 1),
    );
    expect(spring.byDay.length, 5);
    expect(spring.total.expected, 5);

    final autumn = calculateAdherence(
      medications: [_med('a', times: const ['08:00'])],
      takenDoses: {},
      from: DateTime(2026, 10, 23),
      to: DateTime(2026, 10, 27),
      now: DateTime(2026, 10, 28),
    );
    expect(autumn.byDay.length, 5);
    expect(autumn.total.expected, 5);
  });

  test('doseKey matches the adherence document ID format', () {
    expect(doseKey(DateTime(2026, 6, 1), 'med42', '08:00'),
        '2026-06-01_med42_08:00');
  });
}
