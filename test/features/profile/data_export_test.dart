import 'package:chronic_care_app/core/health/health_metrics.dart';
import 'package:chronic_care_app/features/appointments/models/appointment_model.dart';
import 'package:chronic_care_app/features/health/models/health_reading.dart';
import 'package:chronic_care_app/features/medication/models/medication_model.dart';
import 'package:chronic_care_app/features/profile/services/data_export.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _lines(String csv) => csv.trimRight().split('\r\n');

void main() {
  group('csvCell', () {
    test('plain text is left alone', () {
      expect(csvCell('Metformin'), 'Metformin');
      expect(csvCell(42), '42');
      expect(csvCell(null), '');
    });

    test('commas, quotes and new lines are quoted', () {
      expect(csvCell('Take with food, twice'), '"Take with food, twice"');
      expect(csvCell('the "blue" pill'), '"the ""blue"" pill"');
      expect(csvCell('line one\nline two'), '"line one\nline two"');
    });

    test('text that looks like a formula is neutralised', () {
      expect(csvCell('=SUM(A1:A2)'), "'=SUM(A1:A2)");
      expect(csvCell('+44 7700 900000'), "'+44 7700 900000");
    });
  });

  test('readings: oldest first, current labels, context and note', () {
    final csv = readingsCsv([
      HealthReading(
        id: 'b',
        metricType: 'bloodSugar',
        value: 142,
        unit: 'mg/dL',
        status: 'Warning',
        timestamp: DateTime(2026, 6, 2, 7, 5),
        note: 'Before breakfast',
        context: GlucoseContext.fasting,
      ),
      HealthReading(
        id: 'a',
        metricType: 'temperature',
        value: 37.8,
        unit: '°C',
        status: 'Warning',
        timestamp: DateTime(2026, 6, 1, 21, 30),
      ),
    ]);
    expect(_lines(csv), [
      'Date,Time,Metric,Context,Value,Unit,Status,Note',
      '2026-06-01,21:30,Temperature,,37.8,°C,Warning,',
      '2026-06-02,07:05,Blood Sugar,Fasting,142,mg/dL,Warning,Before breakfast',
    ]);
  });

  test('medications', () {
    final csv = medicationsCsv([
      MedicationModel(
        id: '1',
        name: 'Metformin',
        dosage: '500mg',
        frequency: 'Twice daily',
        times: const ['08:00', '20:00'],
        startDate: DateTime(2026, 4, 1),
        pillsRemaining: 20,
        notes: 'With food, morning and evening',
        reminderEnabled: true,
      ),
    ]);
    expect(_lines(csv)[1],
        'Metformin,500mg,Twice daily,08:00 20:00,2026-04-01,Yes,20,1,On,'
        '"With food, morning and evening"');
  });

  test('appointments: soonest first', () {
    final csv = appointmentsCsv([
      AppointmentModel(
        id: '2',
        doctorName: 'Okafor',
        speciality: 'Cardiology',
        dateTime: DateTime(2026, 12, 1, 9, 0),
      ),
      AppointmentModel(
        id: '1',
        doctorName: 'Patel',
        speciality: 'GP',
        location: 'Clinic 2',
        dateTime: DateTime(2026, 11, 3, 14, 45),
        isCompleted: true,
      ),
    ]);
    final lines = _lines(csv);
    expect(lines, hasLength(3));
    expect(lines[1], '2026-11-03,14:45,Patel,GP,Clinic 2,60,Yes,No,');
    expect(lines[2], startsWith('2026-12-01,09:00,Okafor'));
  });

  test('empty data still gives a header row', () {
    expect(_lines(readingsCsv(const [])), hasLength(1));
    expect(_lines(medicationsCsv(const [])), hasLength(1));
    expect(_lines(appointmentsCsv(const [])), hasLength(1));
  });
}
