class MedicationModel {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times; // ["08:00", "20:00"]
  final DateTime startDate;
  final bool isActive;
  final String notes;
  final int? pillsRemaining;    // null = pill tracking disabled
  final int pillsPerDose;       // pills consumed per Take Now tap (default 1)
  final bool lowSupplyNotified; // prevents repeat low-supply alerts

  const MedicationModel({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.startDate,
    this.isActive = true,
    this.notes = '',
    this.pillsRemaining,
    this.pillsPerDose = 1,
    this.lowSupplyNotified = false,
  });

  MedicationModel copyWith({
    String? name,
    String? dosage,
    String? frequency,
    List<String>? times,
    DateTime? startDate,
    bool? isActive,
    String? notes,
    int? pillsRemaining,
    int? pillsPerDose,
    bool? lowSupplyNotified,
  }) {
    return MedicationModel(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      pillsRemaining: pillsRemaining ?? this.pillsRemaining,
      pillsPerDose: pillsPerDose ?? this.pillsPerDose,
      lowSupplyNotified: lowSupplyNotified ?? this.lowSupplyNotified,
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
        'pillsRemaining': pillsRemaining,
        'pillsPerDose': pillsPerDose,
        'lowSupplyNotified': lowSupplyNotified,
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
      pillsRemaining: map['pillsRemaining'] as int?,
      pillsPerDose: map['pillsPerDose'] as int? ?? 1,
      lowSupplyNotified: map['lowSupplyNotified'] as bool? ?? false,
    );
  }
}
