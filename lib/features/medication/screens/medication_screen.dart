import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/notification_service.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';
import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';

const _orange = Color(0xFFFF6F00);

// ── Schedule entry ─────────────────────────────────────────────────────────────

class _ScheduleEntry {
  final String key; // "${medicationId}_${time}"
  final String medicationName;
  final String dosage;
  final String time;

  const _ScheduleEntry({
    required this.key,
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
  // Session-only taken state — resets each app restart (acceptable for daily use)
  final Set<String> _takenToday = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotificationService.initialize();

    // Sync from Firestore first so local cache is up-to-date on app start
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await MedicationService.syncFromFirebase(user.uid);
    }

    final meds = await MedicationService.loadAll();
    final lowSupply = await MedicationService.getLowSupplyMedications();

    if (mounted) {
      setState(() {
        _medications = meds;
        _lowSupplyMeds = lowSupply;
        _bannerDismissed = false; // re-evaluate on each load
        _isLoading = false;
      });
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddScreen,
        backgroundColor: AppColors.primary,
        tooltip: 'Add medication',
        child: const Icon(Icons.add_rounded, color: AppColors.white, size: 28),
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 52,
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
                        ? AppColors.success.withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.08),
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
        ? '⚠️ ${_lowSupplyMeds[0].name} has ${_lowSupplyMeds[0].pillsRemaining} pills remaining'
        : '⚠️ $count medications running low';

    return GestureDetector(
      onTap: _showLowSupplyDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
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
    const periodIcons = {
      'Morning': Icons.wb_sunny_outlined,
      'Afternoon': Icons.wb_cloudy_outlined,
      'Evening': Icons.nights_stay_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(periodIcons[period], size: 14,
                    color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(
                  period,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withOpacity(0.06),
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
                      color: AppColors.divider.withOpacity(0.6),
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

  Widget _buildScheduleRow(_ScheduleEntry entry) {
    final isTaken = _takenToday.contains(entry.key);

    return AnimatedOpacity(
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
                  color: isTaken ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.divider),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
              onTap: () => setState(() {
                if (isTaken) {
                  _takenToday.remove(entry.key);
                } else {
                  _takenToday.add(entry.key);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isTaken ? AppColors.success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isTaken
                        ? AppColors.success
                        : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color:
                      isTaken ? AppColors.white : AppColors.divider,
                ),
              ),
            ),
          ],
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
          child: const Icon(Icons.delete_rounded,
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
                    color: AppColors.textDark.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pill icon — orange tint when supply is low
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isLow
                          ? _orange.withOpacity(0.12)
                          : med.isActive
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.divider.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      size: 24,
                      color: isLow
                          ? _orange
                          : med.isActive
                              ? AppColors.primary
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
                    activeColor: AppColors.primary,
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
