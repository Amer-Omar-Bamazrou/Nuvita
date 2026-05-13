class AppointmentModel {
  final String id;
  final String doctorName;
  final String speciality;
  final String location;
  final DateTime dateTime;
  final String notes;
  final int reminderMinutes;
  final bool isCompleted;
  final bool isConfirmed; // user confirmed attendance via notification tap

  const AppointmentModel({
    required this.id,
    required this.doctorName,

    required this.speciality,
    this.location = '',
    required this.dateTime,
    this.notes = '',
    this.reminderMinutes = 60,
    this.isCompleted = false,
    this.isConfirmed = false,
  });

  AppointmentModel copyWith({
    String? doctorName,
    String? speciality,
    String? location,
    DateTime? dateTime,
    String? notes,
    int? reminderMinutes,
    bool? isCompleted,
    bool? isConfirmed,
  }) {
    return AppointmentModel(
      id: id,
      doctorName: doctorName ?? this.doctorName,
      speciality: speciality ?? this.speciality,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      notes: notes ?? this.notes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      isConfirmed: isConfirmed ?? this.isConfirmed,
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
        'isConfirmed': isConfirmed,
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
      isConfirmed: map['isConfirmed'] as bool? ?? false,
    );
  }
}
