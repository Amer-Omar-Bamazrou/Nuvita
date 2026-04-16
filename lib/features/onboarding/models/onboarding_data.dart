class OnboardingData {
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final List<String> selectedServices;

  const OnboardingData({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.selectedServices,
  });
}
