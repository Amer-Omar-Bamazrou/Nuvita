import 'dart:convert';

import 'package:chronic_care_app/features/appointments/models/appointment_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppointmentModel _roundTrip(AppointmentModel a) => AppointmentModel.fromMap(
    jsonDecode(jsonEncode(a.toMap())) as Map<String, dynamic>);

void main() {
  test('every field survives a round-trip', () {
    final original = AppointmentModel(
      id: '1714500000000',
      doctorName: 'Patel',
      speciality: 'Cardiology',
      location: 'Leicester Royal Infirmary',
      dateTime: DateTime(2026, 11, 3, 14, 45),
      notes: 'Bring BP diary',
      reminderMinutes: 1440,
      isCompleted: true,
      isConfirmed: true,
    );

    final copy = _roundTrip(original);

    expect(copy.id, original.id);
    expect(copy.doctorName, original.doctorName);
    expect(copy.speciality, original.speciality);
    expect(copy.location, original.location);
    expect(copy.dateTime, original.dateTime);
    expect(copy.notes, original.notes);
    expect(copy.reminderMinutes, 1440);
    expect(copy.isCompleted, isTrue);
    expect(copy.isConfirmed, isTrue);
  });

  test('missing optional fields fall back to defaults', () {
    final a = AppointmentModel.fromMap({
      'id': 'a',
      'doctorName': 'Patel',
      'speciality': 'GP',
      'dateTime': '2026-11-03T14:45:00.000',
    });
    expect(a.location, '');
    expect(a.notes, '');
    expect(a.reminderMinutes, 60);
    expect(a.isCompleted, isFalse);
    expect(a.isConfirmed, isFalse);
  });

  test('copyWith keeps the id and unchanged fields', () {
    final a = AppointmentModel(
      id: 'a',
      doctorName: 'Patel',
      speciality: 'GP',
      dateTime: DateTime(2026, 11, 3, 14, 45),
      reminderMinutes: 30,
    );
    final moved = a.copyWith(dateTime: DateTime(2026, 11, 10, 9, 0));
    expect(moved.id, 'a');
    expect(moved.reminderMinutes, 30);
    expect(moved.dateTime, DateTime(2026, 11, 10, 9, 0));
  });
}
