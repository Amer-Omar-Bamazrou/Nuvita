import '../../../core/health/health_metrics.dart';
import '../../appointments/models/appointment_model.dart';
import '../../health/models/health_reading.dart';
import '../../medication/models/medication_model.dart';

// CSV files for Profile → Export my data. Kept free of Firebase so they can
// be tested; the screen fetches the data and shares the files.

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String _number(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// Quotes a cell when needed and stops spreadsheet apps from treating text
// that starts with = + - @ as a formula
String csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (value is String && text.isNotEmpty && '=+-@'.contains(text[0])) {
    text = "'$text";
  }
  final needsQuotes = text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r');
  if (!needsQuotes) return text;
  return '"${text.replaceAll('"', '""')}"';
}

String _csv(List<String> header, Iterable<List<Object?>> rows) {
  final lines = [
    header.map(csvCell).join(','),
    for (final row in rows) row.map(csvCell).join(','),
  ];
  // CRLF line endings, as most spreadsheet apps expect
  return '${lines.join('\r\n')}\r\n';
}

String readingsCsv(List<HealthReading> readings) {
  final sorted = [...readings]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return _csv(
    ['Date', 'Time', 'Metric', 'Context', 'Value', 'Unit', 'Status', 'Note'],
    sorted.map((r) {
      final metric = r.metric;
      return [
        _date(r.timestamp),
        _time(r.timestamp),
        metric == null ? r.metricType : HealthMetrics.of(metric).label,
        r.context == null ? '' : HealthMetrics.contextLabel(r.context!),
        _number(r.value),
        metric == null ? r.unit : HealthMetrics.of(metric).unit,
        r.status,
        r.note ?? '',
      ];
    }),
  );
}

String medicationsCsv(List<MedicationModel> medications) {
  return _csv(
    [
      'Name',
      'Dosage',
      'Frequency',
      'Times',
      'Start date',
      'Active',
      'Pills remaining',
      'Pills per dose',
      'Daily reminders',
      'Notes',
    ],
    medications.map((m) => [
          m.name,
          m.dosage,
          m.frequency,
          m.times.join(' '),
          _date(m.startDate),
          m.isActive ? 'Yes' : 'No',
          m.pillsRemaining?.toString() ?? '',
          m.pillsPerDose.toString(),
          m.reminderEnabled ? 'On' : 'Off',
          m.notes,
        ]),
  );
}

String appointmentsCsv(List<AppointmentModel> appointments) {
  final sorted = [...appointments]
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return _csv(
    [
      'Date',
      'Time',
      'Doctor',
      'Speciality',
      'Location',
      'Reminder (minutes before)',
      'Completed',
      'Confirmed',
      'Notes',
    ],
    sorted.map((a) => [
          _date(a.dateTime),
          _time(a.dateTime),
          a.doctorName,
          a.speciality,
          a.location,
          a.reminderMinutes.toString(),
          a.isCompleted ? 'Yes' : 'No',
          a.isConfirmed ? 'Yes' : 'No',
          a.notes,
        ]),
  );
}
