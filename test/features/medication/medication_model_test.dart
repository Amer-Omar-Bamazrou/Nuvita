import 'dart:convert';

import 'package:chronic_care_app/features/medication/models/medication_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Medications are stored in SharedPreferences as JSON, so the round-trip goes
// through jsonEncode/jsonDecode like the real storage does.
MedicationModel _roundTrip(MedicationModel m) => MedicationModel.fromMap(
    jsonDecode(jsonEncode(m.toMap())) as Map<String, dynamic>);

void main() {
  test('every field survives a round-trip', () {
    final original = MedicationModel(
      id: '1714500000000',
      name: 'Metformin',
      dosage: '500mg',
      frequency: 'Twice daily',
      times: const ['08:00', '20:00'],
      startDate: DateTime(2026, 4, 1, 9, 30),
      isActive: false,
      notes: 'Take with food',
      pillsRemaining: 42,
      pillsPerDose: 2,
      lowSupplyNotified: true,
      reminderEnabled: true,
    );

    final copy = _roundTrip(original);

    expect(copy.id, original.id);
    expect(copy.name, original.name);
    expect(copy.dosage, original.dosage);
    expect(copy.frequency, original.frequency);
    expect(copy.times, original.times);
    expect(copy.startDate, original.startDate);
    expect(copy.isActive, isFalse);
    expect(copy.notes, original.notes);
    expect(copy.pillsRemaining, 42);
    expect(copy.pillsPerDose, 2);
    expect(copy.lowSupplyNotified, isTrue);
    expect(copy.reminderEnabled, isTrue);
  });

  test('untracked pills stay null', () {
    final copy = _roundTrip(MedicationModel(
      id: 'a',
      name: 'Aspirin',
      dosage: '75mg',
      frequency: 'Once daily',
      times: const ['09:00'],
      startDate: DateTime(2026, 1, 1),
    ));
    expect(copy.pillsRemaining, isNull);
  });

  test('missing optional fields fall back to defaults', () {
    final m = MedicationModel.fromMap({
      'id': 'a',
      'name': 'Aspirin',
      'dosage': '75mg',
      'frequency': 'Once daily',
      'times': ['09:00'],
      'startDate': '2026-01-01T00:00:00.000',
    });
    expect(m.isActive, isTrue);
    expect(m.notes, '');
    expect(m.pillsRemaining, isNull);
    expect(m.pillsPerDose, 1);
    expect(m.lowSupplyNotified, isFalse);
    expect(m.reminderEnabled, isFalse);
  });

  test('copyWith keeps unchanged fields', () {
    final m = MedicationModel(
      id: 'a',
      name: 'Aspirin',
      dosage: '75mg',
      frequency: 'Once daily',
      times: const ['09:00'],
      startDate: DateTime(2026, 1, 1),
      isActive: false,
      pillsPerDose: 3,
      reminderEnabled: true,
    );
    final changed = m.copyWith(pillsRemaining: 10);
    expect(changed.isActive, isFalse);
    expect(changed.pillsPerDose, 3);
    expect(changed.reminderEnabled, isTrue);
    expect(changed.pillsRemaining, 10);
  });
}
