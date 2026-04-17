import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_model.dart';

class MedicationService {
  static const _key = 'medications_list';

  static Future<List<MedicationModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((m) => MedicationModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveAll(List<MedicationModel> meds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(meds.map((m) => m.toMap()).toList()),
    );
  }

  static Future<void> add(MedicationModel med) async {
    final meds = await loadAll();
    meds.add(med);
    await _saveAll(meds);
  }

  static Future<void> delete(String id) async {
    final meds = await loadAll();
    meds.removeWhere((m) => m.id == id);
    await _saveAll(meds);
  }

  static Future<void> update(MedicationModel updated) async {
    final meds = await loadAll();
    final i = meds.indexWhere((m) => m.id == updated.id);
    if (i != -1) {
      meds[i] = updated;
      await _saveAll(meds);
    }
  }
}
