import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyFirstName = 'onboarding_first_name';
  static const _keyLastName = 'onboarding_last_name';
  static const _keyGender = 'onboarding_gender';
  static const _keyDob = 'onboarding_dob';
  static const _keyServices = 'onboarding_services';

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  static Future<void> saveOnboardingData({
    required String firstName,
    required String lastName,
    required String gender,
    required DateTime dob,
    required List<String> services,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirstName, firstName);
    await prefs.setString(_keyLastName, lastName);
    await prefs.setString(_keyGender, gender);
    await prefs.setString(_keyDob, dob.toIso8601String());
    await prefs.setString(_keyServices, services.join(','));
  }

  static Future<String?> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFirstName);
  }

  static Future<String?> getLastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastName);
  }

  static Future<String?> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender);
  }

  static Future<DateTime?> getDateOfBirth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDob);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<List<String>> getSelectedServices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyServices);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
