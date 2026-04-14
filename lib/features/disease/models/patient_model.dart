class PatientModel {
  final String name;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final bool smoker;
  final bool onMedication;
  final String diseaseType;

  PatientModel({
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.smoker,
    required this.onMedication,
    required this.diseaseType,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'smoker': smoker,
      'onMedication': onMedication,
      'diseaseType': diseaseType,
    };
  }
}
