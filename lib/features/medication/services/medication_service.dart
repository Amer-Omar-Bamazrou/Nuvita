import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_model.dart';

class MedicationService {
  static const _key = 'medications_list';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _medsRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications');
  }

  // ── SharedPreferences ──────────────────────────────────────────────────────

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

  // ── Firestore helpers ──────────────────────────────────────────────────────

  static Map<String, dynamic> _toFirestoreMap(MedicationModel med) {
    return {
      'id': med.id,
      'name': med.name,
      'dosage': med.dosage,
      'frequency': med.frequency,
      'times': med.times,
      'startDate': Timestamp.fromDate(med.startDate),
      'isActive': med.isActive,
      'notes': med.notes,
      'pillsRemaining': med.pillsRemaining,
      'pillsPerDose': med.pillsPerDose,
      'lowSupplyNotified': med.lowSupplyNotified,
    };
  }

  static MedicationModel _fromFirestoreDoc(Map<String, dynamic> data) {
    // Firestore stores startDate as Timestamp; handle ISO string fallback
    final startDate = data['startDate'] is Timestamp
        ? (data['startDate'] as Timestamp).toDate()
        : DateTime.parse(data['startDate'] as String);
    return MedicationModel(
      id: data['id'] as String,
      name: data['name'] as String,
      dosage: data['dosage'] as String,
      frequency: data['frequency'] as String,
      times: List<String>.from(data['times'] as List),
      startDate: startDate,
      isActive: data['isActive'] as bool? ?? true,
      notes: data['notes'] as String? ?? '',
      pillsRemaining: data['pillsRemaining'] as int?,
      pillsPerDose: data['pillsPerDose'] as int? ?? 1,
      lowSupplyNotified: data['lowSupplyNotified'] as bool? ?? false,
    );
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  // Pull medications from Firestore and merge with local cache.
  // Firestore wins on same-ID conflicts; local-only entries are preserved.
  static Future<void> syncFromFirebase(String uid) async {
    try {
      final snapshot = await _medsRef(uid).get();
      final remoteMeds =
          snapshot.docs.map((doc) => _fromFirestoreDoc(doc.data())).toList();

      final localMeds = await loadAll();
      final remoteIds = remoteMeds.map((m) => m.id).toSet();
      final localOnly = localMeds.where((m) => !remoteIds.contains(m.id)).toList();

      await _saveAll([...remoteMeds, ...localOnly]);
    } catch (e) {
      debugPrint('MedicationService.syncFromFirebase: $e');
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  static Future<void> add(MedicationModel med) async {
    final meds = await loadAll();
    meds.add(med);
    await _saveAll(meds);

    final uid = _uid;
    if (uid != null) {
      try {
        await _medsRef(uid).doc(med.id).set(_toFirestoreMap(med));
      } catch (e) {
        debugPrint('MedicationService.add: $e');
      }
    }
  }

  static Future<void> delete(String id) async {
    final meds = await loadAll();
    meds.removeWhere((m) => m.id == id);
    await _saveAll(meds);

    final uid = _uid;
    if (uid != null) {
      try {
        await _medsRef(uid).doc(id).delete();
      } catch (e) {
        debugPrint('MedicationService.delete: $e');
      }
    }
  }

  static Future<void> update(MedicationModel updated) async {
    final meds = await loadAll();
    final i = meds.indexWhere((m) => m.id == updated.id);
    if (i != -1) {
      meds[i] = updated;
      await _saveAll(meds);

      final uid = _uid;
      if (uid != null) {
        try {
          await _medsRef(uid).doc(updated.id).set(_toFirestoreMap(updated));
        } catch (e) {
          debugPrint('MedicationService.update: $e');
        }
      }
    }
  }

  // ── Pills tracking ─────────────────────────────────────────────────────────

  // Decrements pillsRemaining by pillsPerDose and persists.
  // Returns the updated model, or the original if pills are not tracked.
  static Future<MedicationModel?> takeMedication(String id) async {
    final meds = await loadAll();
    final i = meds.indexWhere((m) => m.id == id);
    if (i == -1) return null;

    final med = meds[i];
    if (med.pillsRemaining == null) return med;

    final newCount = (med.pillsRemaining! - med.pillsPerDose).clamp(0, 999999);
    final updated = med.copyWith(pillsRemaining: newCount);
    meds[i] = updated;
    await _saveAll(meds);

    final uid = _uid;
    if (uid != null) {
      try {
        await _medsRef(uid).doc(updated.id).set(_toFirestoreMap(updated));
      } catch (e) {
        debugPrint('MedicationService.takeMedication: $e');
      }
    }
    return updated;
  }

  // True when a medication is active, tracked, and has 7 or fewer pills left.
  static bool checkLowSupply(MedicationModel med) {
    return med.isActive &&
        med.pillsRemaining != null &&
        med.pillsRemaining! <= 7;
  }

  static Future<List<MedicationModel>> getLowSupplyMedications() async {
    final meds = await loadAll();
    return meds.where(checkLowSupply).toList();
  }

  // Update pill count directly (e.g. after a refill from the edit screen).
  // Resets lowSupplyNotified when count goes above the threshold.
  static Future<void> updatePillsRemaining(String id, int newCount) async {
    final meds = await loadAll();
    final i = meds.indexWhere((m) => m.id == id);
    if (i == -1) return;

    final med = meds[i];
    final resetFlag = newCount > 7;
    final updated = med.copyWith(
      pillsRemaining: newCount,
      lowSupplyNotified: resetFlag ? false : med.lowSupplyNotified,
    );
    meds[i] = updated;
    await _saveAll(meds);

    final uid = _uid;
    if (uid != null) {
      try {
        await _medsRef(uid).doc(updated.id).set(_toFirestoreMap(updated));
      } catch (e) {
        debugPrint('MedicationService.updatePillsRemaining: $e');
      }
    }
  }
}
