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

  static Future<MedicationModel?> getById(String id) async {
    final meds = await loadAll();
    try {
      return meds.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
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
      'reminderEnabled': med.reminderEnabled,
    };
  }

  // Public so the medication screen can parse stream snapshots directly
  // without a second .get() round-trip.
  static MedicationModel fromFirestoreDoc(Map<String, dynamic> data) =>
      _fromFirestoreDoc(data);

  static Future<void> saveAll(List<MedicationModel> meds) => _saveAll(meds);

  static MedicationModel _fromFirestoreDoc(Map<String, dynamic> data) {
    DateTime startDate;
    if (data['startDate'] is Timestamp) {
      startDate = (data['startDate'] as Timestamp).toDate();
    } else if (data['startDate'] is String) {
      startDate = DateTime.tryParse(data['startDate'] as String) ?? DateTime.now();
    } else {
      startDate = DateTime.now();
    }

    return MedicationModel(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown',
      dosage: data['dosage'] as String? ?? '',
      frequency: data['frequency'] as String? ?? 'Once daily',
      times: data['times'] != null
          ? List<String>.from(data['times'] as List)
          : [],
      startDate: startDate,
      isActive: data['isActive'] as bool? ?? true,
      notes: data['notes'] as String? ?? '',
      pillsRemaining: data['pillsRemaining'] as int?,
      pillsPerDose: data['pillsPerDose'] as int? ?? 1,
      lowSupplyNotified: data['lowSupplyNotified'] as bool? ?? false,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
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

  // ── Adherence tracking ─────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _adherenceRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('adherence');
  }

  static Future<void> saveDoseToFirebase({
    required String medicationId,
    required String medicationName,
    required String dosage,
    required String timeSlot,
    required String date,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final docId = '${date}_${medicationId}_$timeSlot';
    try {
      await _adherenceRef(uid).doc(docId).set({
        'medicationId': medicationId,
        'medicationName': medicationName,
        'dosage': dosage,
        'timeSlot': timeSlot,
        'date': date,
        'taken': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('MedicationService.saveDoseToFirebase: $e');
    }
  }

  static Future<void> removeDoseFromFirebase({
    required String medicationId,
    required String timeSlot,
    required String date,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final docId = '${date}_${medicationId}_$timeSlot';
    try {
      await _adherenceRef(uid).doc(docId).delete();
    } catch (e) {
      debugPrint('MedicationService.removeDoseFromFirebase: $e');
    }
  }

  static Future<Map<String, bool>> getAdherenceHistory(
      String uid, int days) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    try {
      final snap = await _adherenceRef(uid)
          .where('date',
              isGreaterThanOrEqualTo:
                  '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}')
          .get();
      final result = <String, bool>{};
      for (final doc in snap.docs) {
        result[doc.id] = (doc.data()['taken'] as bool?) ?? false;
      }
      return result;
    } catch (e) {
      debugPrint('MedicationService.getAdherenceHistory: $e');
      return {};
    }
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
