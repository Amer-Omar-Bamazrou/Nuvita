import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../models/medication_model.dart';
import 'medication_service.dart';

// The one place that records a dose as taken or undoes it. Home, the
// Medication screen, the detail screen's Take Now and the notification
// actions all go through here so the taken flag, the adherence record, the
// pill count and the low-supply alert always change together.
class DoseService {
  DoseService._();

  static String dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  // Local per-day flag read by Home, Tracking and the medication screens
  static String takenKey(String medicationId, String timeSlot, String date) =>
      'taken_${medicationId}_${timeSlot}_$date';

  static Future<bool> isTaken(String medicationId, String timeSlot,
      {DateTime? day}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = takenKey(medicationId, timeSlot, dateKey(day ?? DateTime.now()));
    return prefs.getString(key) == 'true';
  }

  // Earliest of today's slots not yet taken, or null when all are done.
  // Medications without set times ("As needed") use the current time.
  static Future<String?> nextUntakenSlot(MedicationModel med) async {
    if (med.times.isEmpty) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    final sorted = [...med.times]..sort();
    for (final time in sorted) {
      if (!await isTaken(med.id, time)) return time;
    }
    return null;
  }

  // Marks one dose as taken. Does nothing if that slot is already taken, so a
  // notification action and an in-app tap can't take pills off twice.
  // Returns the updated medication, or null if it no longer exists.
  static Future<MedicationModel?> markTaken({
    required String medicationId,
    required String timeSlot,
    DateTime? day,
  }) async {
    final date = dateKey(day ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final key = takenKey(medicationId, timeSlot, date);
    if (prefs.getString(key) == 'true') {
      return MedicationService.getById(medicationId);
    }

    var med = await MedicationService.takeMedication(medicationId);
    if (med == null) return null;
    await prefs.setString(key, 'true');

    await MedicationService.saveDoseToFirebase(
      medicationId: med.id,
      medicationName: med.name,
      dosage: med.dosage,
      timeSlot: timeSlot,
      date: date,
    );

    // Raise the low-supply alert once when the count reaches the threshold
    if (MedicationService.checkLowSupply(med) && !med.lowSupplyNotified) {
      await NotificationService.scheduleLowSupplyAlert(
          med.id, med.name, med.pillsRemaining!);
      med = med.copyWith(lowSupplyNotified: true);
      await MedicationService.update(med);
    }
    return med;
  }

  // Reverses markTaken: clears the flag, deletes the adherence record and puts
  // the pills back. Does nothing if that slot wasn't marked as taken.
  static Future<MedicationModel?> undo({
    required String medicationId,
    required String timeSlot,
    DateTime? day,
  }) async {
    final date = dateKey(day ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final key = takenKey(medicationId, timeSlot, date);
    if (prefs.getString(key) != 'true') {
      return MedicationService.getById(medicationId);
    }

    await prefs.remove(key);
    await MedicationService.removeDoseFromFirebase(
      medicationId: medicationId,
      timeSlot: timeSlot,
      date: date,
    );

    final med = await MedicationService.getById(medicationId);
    if (med == null || med.pillsRemaining == null) return med;

    final restored = med.copyWith(
      pillsRemaining: med.pillsRemaining! + med.pillsPerDose,
    );
    // Back above the threshold: clear the alert so it can fire again later
    final updated = MedicationService.checkLowSupply(restored)
        ? restored
        : restored.copyWith(lowSupplyNotified: false);
    await MedicationService.update(updated);
    if (!MedicationService.checkLowSupply(updated)) {
      await NotificationService.cancelLowSupplyAlert(updated.id);
    }
    return updated;
  }
}
