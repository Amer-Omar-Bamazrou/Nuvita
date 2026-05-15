import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/notification_service.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';
import 'add_medication_screen.dart';

const _orange = Color(0xFFFF6F00);

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({super.key, required this.medication});

  final MedicationModel medication;

  @override
  State<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  late MedicationModel _med;
  int _takenTodayCount = 0;
  bool _isTaking = false;
  bool _allDosesTaken = false;

  @override
  void initState() {
    super.initState();
    _med = widget.medication;
    _checkTodayDoses();
  }

  Future<void> _checkTodayDoses() async {
    if (_med.times.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    int takenCount = 0;
    for (final time in _med.times) {
      final key = 'taken_${_med.id}_${time}_$todayStr';
      if (prefs.getString(key) == 'true') takenCount++;
    }
    if (mounted) {
      setState(() {
        _takenTodayCount = takenCount;
        _allDosesTaken = takenCount >= _med.times.length;
      });
    }
  }

  // ── Take Now ──────────────────────────────────────────────────────────────

  Future<void> _onTakeNow() async {
    if (_isTaking) return;

    // No pill tracking — just record the tap and warn if overdosing
    if (_med.pillsRemaining == null) {
      setState(() {
        _takenTodayCount++;
        _allDosesTaken = _takenTodayCount >= _med.times.length;
      });
      if (_takenTodayCount > _med.times.length) {
        _showOverdoseWarning();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dose marked as taken')),
        );
      }
      return;
    }

    // Guard: pill count exhausted
    if (_med.pillsRemaining! <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Out of pills. Please refill.')),
        );
      }
      return;
    }

    setState(() => _isTaking = true);

    final updated = await MedicationService.takeMedication(_med.id);
    if (updated == null || !mounted) {
      setState(() => _isTaking = false);
      return;
    }

    _takenTodayCount++;

    // Fire low-supply alert once when count crosses the 7-pill threshold
    if (MedicationService.checkLowSupply(updated) && !updated.lowSupplyNotified) {
      await NotificationService.scheduleLowSupplyAlert(
        updated.id,
        updated.name,
        updated.pillsRemaining!,
      );
      final notified = updated.copyWith(lowSupplyNotified: true);
      await MedicationService.update(notified);
      setState(() {
        _med = notified;
        _isTaking = false;
      });
    } else {
      setState(() {
        _med = updated;
        _isTaking = false;
      });
    }

    _allDosesTaken = _takenTodayCount >= _med.times.length;
    if (_takenTodayCount > _med.times.length) _showOverdoseWarning();
  }

  void _showOverdoseWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You\'ve taken $_takenTodayCount doses today. '
          'This medication is scheduled ${_med.frequency.toLowerCase()}.',
        ),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Reminder toggle ───────────────────────────────────────────────────────

  Future<void> _onReminderToggle(bool value) async {
    final updated = _med.copyWith(reminderEnabled: value);
    setState(() => _med = updated);
    await MedicationService.update(updated);

    if (value) {
      await NotificationService.scheduleDailyMedicationReminder(
        updated.id, updated.name, updated.dosage, updated.times,
        pillsPerDose: updated.pillsPerDose,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set for ${updated.times.join("  ·  ")}')),
        );
      }
    } else {
      await NotificationService.cancelDailyMedicationReminders(
          updated.id, updated.times);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder cancelled')),
        );
      }
    }
  }

  // ── Edit / Delete ─────────────────────────────────────────────────────────

  Future<void> _onEdit() async {
    final updated = await Navigator.of(context).push<MedicationModel>(
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(existing: _med),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _med = updated);
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete medication?'),
        content: Text(
          'Delete "${_med.name}"? This will also cancel its reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await NotificationService.cancelLowSupplyAlert(_med.id);
    await NotificationService.cancelMedicationReminder(
        _med.id, _med.times.length);
    if (_med.reminderEnabled) {
      await NotificationService.cancelDailyMedicationReminders(
          _med.id, _med.times);
    }
    await MedicationService.delete(_med.id);

    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tracking = _med.pillsRemaining != null;
    final outOfPills = tracking && _med.pillsRemaining! <= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Medication Details', style: AppTextStyles.heading3),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: _onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: _onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameCard(),
            const SizedBox(height: 16),
            _buildDetailsCard(),
            if (tracking) ...[
              const SizedBox(height: 16),
              _buildPillsCard(),
            ],
            const SizedBox(height: 28),
            _buildTakeNowButton(outOfPills),
            const SizedBox(height: 16),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _buildNameCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _med.isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.divider.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 30,
              color: _med.isActive ? AppColors.primary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _med.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _med.isActive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _med.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _med.isActive
                          ? AppColors.success
                          : AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _detailRow(Icons.colorize_rounded, 'Dosage', _med.dosage),
          _rowDivider(),
          _detailRow(Icons.repeat_rounded, 'Frequency', _med.frequency),
          _rowDivider(),
          _detailRow(
            Icons.alarm_rounded,
            'Schedule',
            _med.times.isEmpty ? '—' : _med.times.join('  ·  '),
          ),
          _rowDivider(),
          _detailRow(
            Icons.calendar_today_rounded,
            'Start date',
            _formatDate(_med.startDate),
          ),
          if (_med.notes.isNotEmpty) ...[
            _rowDivider(),
            _detailRow(Icons.notes_rounded, 'Notes', _med.notes),
          ],
          if (_med.times.isNotEmpty) ...[
            _rowDivider(),
            _reminderToggleRow(),
          ],
        ],
      ),
    );
  }

  Widget _reminderToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              size: 20, color: AppColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Reminders',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get notified at each dose time',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _med.reminderEnabled,
            onChanged: (val) => _onReminderToggle(val),
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildPillsCard() {
    final pills = _med.pillsRemaining!;
    final isLow = MedicationService.checkLowSupply(_med);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFFF3E0) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLow
            ? Border.all(color: _orange.withValues(alpha: 0.4))
            : null,
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
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
            color: isLow ? _orange : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pills remaining', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  pills == 0
                      ? 'Out of pills'
                      : '$pills pill${pills == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLow ? _orange : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (isLow)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Low supply',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildTakeNowButton(bool outOfPills) {
    final tracking = _med.pillsRemaining != null;
    final canTake = !tracking || !outOfPills;
    final disabled = !canTake || _isTaking || _allDosesTaken;

    String label;
    IconData icon;
    if (_allDosesTaken) {
      label = 'All Doses Taken';
      icon = Icons.check_circle_rounded;
    } else if (outOfPills) {
      label = 'Out of Pills';
      icon = Icons.block_rounded;
    } else {
      label = 'Take Now';
      icon = Icons.check_circle_outline_rounded;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : _onTakeNow,
        icon: _isTaking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.white),
              )
            : Icon(icon, color: AppColors.white),
        label: Text(label, style: AppTextStyles.buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: _allDosesTaken
              ? AppColors.success
              : outOfPills
                  ? AppColors.secondary.withValues(alpha: 0.45)
                  : AppColors.primary,
          disabledBackgroundColor: _allDosesTaken
              ? AppColors.success.withValues(alpha: 0.6)
              : AppColors.secondary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _onEdit,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side:
                  const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() =>
      Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.6));

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
