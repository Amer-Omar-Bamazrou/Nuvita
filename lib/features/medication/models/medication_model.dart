class MedicationModel {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times; // ["08:00", "20:00"]
  final DateTime startDate;
  final bool isActive;
  final String notes;

  const MedicationModel({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.startDate,
    this.isActive = true,
    this.notes = '',
  });

  MedicationModel copyWith({bool? isActive}) {
    return MedicationModel(
      id: id,
      name: name,
      dosage: dosage,
      frequency: frequency,
      times: times,
      startDate: startDate,
      isActive: isActive ?? this.isActive,
      notes: notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'times': times,
        'startDate': startDate.toIso8601String(),
        'isActive': isActive,
        'notes': notes,
      };

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      frequency: map['frequency'] as String,
      times: List<String>.from(map['times'] as List),
      startDate: DateTime.parse(map['startDate'] as String),
      isActive: map['isActive'] as bool? ?? true,
      notes: map['notes'] as String? ?? '',
    );
  }
}
