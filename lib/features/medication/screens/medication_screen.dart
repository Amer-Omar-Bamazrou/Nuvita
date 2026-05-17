import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/notification_service.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';
import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';
import 'medication_history_screen.dart';

const _orange = Color(0xFFFF6F00);

// ── Schedule entry ─────────────────────────────────────────────────────────────

class _ScheduleEntry {
  final String key; // "${medicationId}_${time}"
  final String medicationId;
  final String medicationName;
  final String dosage;
  final String time;

  const _ScheduleEntry({
    required this.key,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.time,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  List<MedicationModel> _medications = [];
  List<MedicationModel> _lowSupplyMeds = [];
  bool _bannerDismissed = false;
  final Set<String> _takenToday = {};
  bool _isLoading = true;
  bool _streamLoaded = false;
  StreamSubscription<QuerySnapshot>? _firestoreSub;

  @override
  void initState() {
    super.initState();
    _load();
    _listenForRemoteChanges();
  }

  // Listens to the patient's medications collection so that doctor-assigned
  // or doctor-edited medications appear immediately without requiring an app
  // restart. Parses the snapshot directly — no second .get() — to avoid the
  // race condition where _load() overwrites a stale syncFromFirebase result.
  void _listenForRemoteChanges() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _firestoreSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications')
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;
          try {
            final remoteMeds = snapshot.docs
                .map((d) => MedicationService.fromFirestoreDoc(d.data()))
                .toList();
            final localMeds = await MedicationService.loadAll();
            final remoteIds = remoteMeds.map((m) => m.id).toSet();
            final localOnly =
                localMeds.where((m) => !remoteIds.contains(m.id)).toList();
            final merged = [...remoteMeds, ...localOnly];
            await MedicationService.saveAll(merged);
            final lowSupply =
                merged.where(MedicationService.checkLowSupply).toList();
            _streamLoaded = true;
            if (mounted) {
              setState(() {
                _medications = merged;
                _lowSupplyMeds = lowSupply;
                _isLoading = false;
              });
            }
          } catch (e) {
            debugPrint('MedicationScreen stream: $e');
          }
        });
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    unawaited(NotificationService.initialize());

    final meds = await MedicationService.loadAll();
    final lowSupply = await MedicationService.getLowSupplyMedications();

    await _restoreTakenState(meds);

    if (!mounted) return;

    if (_streamLoaded) {
      setState(() {
        _bannerDismissed = false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _medications = meds;
        _lowSupplyMeds = lowSupply;
        _bannerDismissed = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreTakenState(List<MedicationModel> meds) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _takenToday.clear();
    for (final med in meds) {
      if (!med.isActive) continue;
      for (final time in med.times) {
        final prefKey = 'taken_${med.id}_${time}_$todayStr';
        if (prefs.getString(prefKey) == 'true') {
          _takenToday.add('${med.id}_$time');
        }
      }
    }
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.of(context).push<MedicationModel>(
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
    if (result != null) _load();
  }

  Future<void> _openDetailScreen(MedicationModel med) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailScreen(medication: med),
      ),
    );
    // Always reload — user may have edited, deleted, or taken a dose
    _load();
  }

  Future<void> _openEditScreen(MedicationModel med) async {
    final result = await Navigator.of(context).push<MedicationModel>(
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(existing: med),
      ),
    );
    if (result != null) _load();
  }

  Future<void> _toggleActive(MedicationModel med) async {
    final updated = med.copyWith(isActive: !med.isActive);
    await MedicationService.update(updated);
    if (updated.isActive) {
      await NotificationService.scheduleMedicationReminder(updated);
    } else {
      await NotificationService.cancelMedicationReminder(
          updated.id, updated.times.length);
    }
    _load();
  }

  Future<void> _delete(MedicationModel med) async {
    await MedicationService.delete(med.id);
    await NotificationService.cancelMedicationReminder(
        med.id, med.times.length);
    await NotificationService.cancelLowSupplyAlert(med.id);
    if (med.reminderEnabled) {
      await NotificationService.cancelDailyMedicationReminders(
          med.id, med.times);
    }
    _load();
  }

  // All active medications whose start date is today or earlier
  List<_ScheduleEntry> get _todaySchedule {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final entries = <_ScheduleEntry>[];

    for (final med in _medications) {
      if (!med.isActive) continue;
      final start = med.startDate;
      if (DateTime(start.year, start.month, start.day).isAfter(todayDate)) {
        continue;
      }
      for (final time in med.times) {
        entries.add(_ScheduleEntry(
          key: '${med.id}_$time',
          medicationId: med.id,
          medicationName: med.name,
          dosage: med.dosage,
          time: time,
        ));
      }
    }

    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  Map<String, List<_ScheduleEntry>> _groupByPeriod(
      List<_ScheduleEntry> entries) {
    final groups = <String, List<_ScheduleEntry>>{
      'Morning': [],
      'Afternoon': [],
      'Evening': [],
    };
    for (final e in entries) {
      final hour = int.parse(e.time.split(':')[0]);
      if (hour < 12) {
        groups['Morning']!.add(e);
      } else if (hour < 17) {
        groups['Afternoon']!.add(e);
      } else {
        groups['Evening']!.add(e);
      }
    }
    return groups;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('My Medications', style: AppTextStyles.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary),
            tooltip: 'Adherence history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const MedicationHistoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'fab_medications',
          onPressed: _openAddScreen,
          backgroundColor: AppColors.primary,
          elevation: 0,
          tooltip: 'Add medication',
          child: const Icon(Icons.add_rounded, color: AppColors.white, size: 28),
        ),
      ),
      body: _medications.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text('No medications yet', style: AppTextStyles.heading2),
            const SizedBox(height: 12),
            Text(
              'Tap the + button to add your first medication and set daily reminders.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final schedule = _todaySchedule;
    final groups = _groupByPeriod(schedule);
    final takenCount =
        schedule.where((e) => _takenToday.contains(e.key)).length;
    final total = schedule.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Low supply banner ──────────────────────────────────────────────
          if (_lowSupplyMeds.isNotEmpty && !_bannerDismissed)
            _buildLowSupplyBanner(),

          // ── Today header with progress badge ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Schedule", style: AppTextStyles.heading3),
                    const SizedBox(height: 2),
                    Text(_formattedToday(), style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: takenCount == total
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$takenCount / $total done',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: takenCount == total
                          ? AppColors.success
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Schedule groups (Morning / Afternoon / Evening) ────────────────
          if (schedule.isEmpty)
            _buildEmptyScheduleCard()
          else
            for (final period in ['Morning', 'Afternoon', 'Evening'])
              if (groups[period]!.isNotEmpty)
                _buildPeriodGroup(period, groups[period]!),

          const SizedBox(height: 28),

          // ── My Medications list ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Medications', style: AppTextStyles.heading3),
              Text('${_medications.length} added',
                  style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          for (final med in _medications) _buildMedicationCard(med),
        ],
      ),
    );
  }

  // ── Low supply banner ─────────────────────────────────────────────────────────

  Widget _buildLowSupplyBanner() {
    final count = _lowSupplyMeds.length;
    final message = count == 1
        ? '${_lowSupplyMeds[0].name} is running low — only ${_lowSupplyMeds[0].pillsRemaining} pills left.'
        : '$count medications running low';

    return GestureDetector(
      onTap: _showLowSupplyDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: _orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: const Icon(Icons.close_rounded,
                  color: _orange, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showLowSupplyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Low Pill Supply'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _lowSupplyMeds.length,
            itemBuilder: (_, i) {
              final med = _lowSupplyMeds[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.medication_rounded,
                    color: _orange),
                title:
                    Text(med.name, style: AppTextStyles.label),
                subtitle: Text(
                  '${med.pillsRemaining} pills remaining',
                  style: AppTextStyles.bodySmall,
                ),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openEditScreen(med);
                  },
                  child: const Text(
                    'Refill',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Schedule section builders ─────────────────────────────────────────────────

  Widget _buildEmptyScheduleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.divider, size: 34),
          const SizedBox(height: 10),
          Text(
            'Nothing due today',
            style: AppTextStyles.bodySmall
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodGroup(
      String period, List<_ScheduleEntry> entries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              period.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF6E7A82),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.divider.withValues(alpha: 0.6),
                      indent: 84,
                    ),
                  _buildScheduleRow(entries[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isMissed(_ScheduleEntry entry) {
    final now = DateTime.now();
    final parts = entry.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return now.hour > hour || (now.hour == hour && now.minute > minute);
  }

  Future<void> _toggleTaken(_ScheduleEntry entry) async {
    final isTaken = _takenToday.contains(entry.key);
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefKey = 'taken_${entry.medicationId}_${entry.time}_$todayStr';
    final prefs = await SharedPreferences.getInstance();

    if (isTaken) {
      await prefs.remove(prefKey);
      MedicationService.removeDoseFromFirebase(
        medicationId: entry.medicationId,
        timeSlot: entry.time,
        date: todayStr,
      );
      if (mounted) setState(() => _takenToday.remove(entry.key));
    } else {
      await prefs.setString(prefKey, 'true');
      await MedicationService.takeMedication(entry.medicationId);
      MedicationService.saveDoseToFirebase(
        medicationId: entry.medicationId,
        medicationName: entry.medicationName,
        dosage: entry.dosage,
        timeSlot: entry.time,
        date: todayStr,
      );
      if (mounted) {
        setState(() => _takenToday.add(entry.key));
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.medicationName} ${entry.dosage} at ${entry.time} marked as taken.',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColors.white,
              onPressed: () async {
                await prefs.remove(prefKey);
                MedicationService.removeDoseFromFirebase(
                  medicationId: entry.medicationId,
                  timeSlot: entry.time,
                  date: todayStr,
                );
                final med = await MedicationService.getById(entry.medicationId);
                if (med != null && med.pillsRemaining != null) {
                  final restored = med.pillsRemaining! + med.pillsPerDose;
                  final updated = med.copyWith(
                    pillsRemaining: restored,
                    lowSupplyNotified: restored > 7 ? false : med.lowSupplyNotified,
                  );
                  await MedicationService.update(updated);
                  if (restored > 7) {
                    await NotificationService.cancelLowSupplyAlert(med.id);
                  }
                }
                if (mounted) {
                  setState(() => _takenToday.remove(entry.key));
                  _load();
                }
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildScheduleRow(_ScheduleEntry entry) {
    final isTaken = _takenToday.contains(entry.key);
    final missed = !isTaken && _isMissed(entry);

    return Container(
      decoration: missed
          ? const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.error, width: 3)),
            )
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isTaken ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  entry.time,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isTaken
                        ? AppColors.success
                        : missed
                            ? AppColors.error
                            : AppColors.primary,
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.medicationName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                              decoration:
                                  isTaken ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.secondary,
                            ),
                          ),
                        ),
                        if (missed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Missed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        if (isTaken) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Taken',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.dosage,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _toggleTaken(entry),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isTaken ? AppColors.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isTaken ? AppColors.success : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: isTaken ? AppColors.white : AppColors.divider,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Medication card (compact) ─────────────────────────────────────────────────

  Widget _buildMedicationCard(MedicationModel med) {
    final isLow = MedicationService.checkLowSupply(med);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(med.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(med.name),
        onDismissed: (_) => _delete(med),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(IconlyBold.delete,
              color: Colors.white, size: 26),
        ),
        child: GestureDetector(
          onTap: () => _openDetailScreen(med),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: med.isActive ? 1.0 : 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isLow
                          ? _orange.withValues(alpha: 0.12)
                          : med.isActive
                              ? const Color(0xFF1565C0).withValues(alpha: 0.12)
                              : AppColors.divider.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      size: 24,
                      color: isLow
                          ? _orange
                          : med.isActive
                              ? const Color(0xFF1565C0)
                              : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: AppTextStyles.label
                              .copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${med.dosage}  ·  ${med.frequency}',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontSize: 13),
                        ),
                        // Pills remaining hint when tracked and low
                        if (isLow) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${med.pillsRemaining} pills left',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: med.isActive,
                    onChanged: (_) => _toggleActive(med),
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _formattedToday() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  Future<bool> _confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete medication?'),
        content: Text('Remove "$name" and cancel its reminders?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
