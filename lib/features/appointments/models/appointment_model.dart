class AppointmentModel {
  final String id;
  final String doctorName;
  final String speciality;
  final String location;
  final DateTime dateTime;
  final String notes;
  final int reminderMinutes;
  final bool isCompleted;

  const AppointmentModel({
    required this.id,
    required this.doctorName,
    required this.speciality,
    this.location = '',
    required this.dateTime,
    this.notes = '',
    this.reminderMinutes = 60,
    this.isCompleted = false,
  });

  AppointmentModel copyWith({bool? isCompleted}) {
    return AppointmentModel(
      id: id,
      doctorName: doctorName,
      speciality: speciality,
      location: location,
      dateTime: dateTime,
      notes: notes,
      reminderMinutes: reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctorName': doctorName,
        'speciality': speciality,
        'location': location,
        'dateTime': dateTime.toIso8601String(),
        'notes': notes,
        'reminderMinutes': reminderMinutes,
        'isCompleted': isCompleted,
      };

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] as String,
      doctorName: map['doctorName'] as String,
      speciality: map['speciality'] as String,
      location: map['location'] as String? ?? '',
      dateTime: DateTime.parse(map['dateTime'] as String),
      notes: map['notes'] as String? ?? '',
      reminderMinutes: map['reminderMinutes'] as int? ?? 60,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}
