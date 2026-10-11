import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'preferences_service.dart';

// The parts of the app a patient chose in onboarding or in Profile → My
// services. They decide which sections Home and Tracking show and which
// reminders are scheduled. Nothing selected (onboarding skipped) means all.
class CareServices {
  CareServices._();

  static const medications = 'medications';
  static const measurements = 'measurements';
  static const activities = 'activities';
  static const appointments = 'appointments';

  static const all = {medications, measurements, activities, appointments};

  // Bumped whenever the selection changes so open screens can reload
  static final changes = ValueNotifier<int>(0);

  // Known ids only; an empty selection falls back to everything
  static Set<String> effective(Iterable<String> stored) {
    final known = stored.where(all.contains).toSet();
    return known.isEmpty ? {...all} : known;
  }

  static Future<Set<String>> load() async =>
      effective(await PreferencesService.getSelectedServices());

  static Future<bool> isEnabled(String id) async => (await load()).contains(id);

  // Saves locally and, when signed in, on the user's Firestore profile
  static Future<void> save(String? uid, Set<String> ids) async {
    final list = ids.where(all.contains).toList();
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profile': {'services': list},
      }, SetOptions(merge: true));
    }
    await PreferencesService.saveSelectedServices(list);
    changes.value++;
  }

  // After sign-in the local cache is empty (sign-out clears it), so copy the
  // selection stored on the profile document back into it
  static Future<void> restoreFromUserDoc(Map<String, dynamic>? userDoc) async {
    final profile = userDoc?['profile'] as Map<String, dynamic>?;
    final stored = profile?['services'];
    if (stored is! List) return;
    await PreferencesService.saveSelectedServices(
        stored.whereType<String>().where(all.contains).toList());
    changes.value++;
  }
}
