import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/dashboard/providers/health_provider.dart';
import '../../../shared/widgets/nuvita_button.dart';

class BloodPressureInputScreen extends StatefulWidget {
  final Future<void> Function(HealthMetric metric, double value, DateTime when) onSave;

  const BloodPressureInputScreen({super.key, required this.onSave});

  @override
  State<BloodPressureInputScreen> createState() => _BloodPressureInputScreenState();
}

class _BloodPressureInputScreenState extends State<BloodPressureInputScreen> {
  double _sys = 120;
  double _dia = 80;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saving = false;
  int _contextIndex = -1;

  static const _contextChips = ['Resting', 'After exercise', 'After meal', 'Stressed'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  // ── Status ──────────────────────────────────────────────────────

  (String, Color) get _status {
    if (_sys < 120 && _dia < 80) return ('Normal', AppColors.success);
    if (_sys <= 129 && _dia < 80) return ('Elevated', AppColors.warning);
    if (_sys <= 139 || _dia <= 89) return ('High Stage 1', AppColors.warning);
    return ('High Stage 2', AppColors.error);
  }

  // ── Date / time ─────────────────────────────────────────────────

  String get _formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (_selectedDate == today) return 'Today · ${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    if (_selectedDate == yesterday) return 'Yesterday · ${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String get _formattedTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Submit ──────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final when = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      await Future.wait([
        widget.onSave(HealthMetric.systolic, _sys, when),
        widget.onSave(HealthMetric.diastolic, _dia, when),
        widget.onSave(HealthMetric.heartRate, 70, when),
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save reading. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Blood Pressure', style: AppTextStyles.heading2.copyWith(fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero card
                  _buildHeroCard(statusLabel, statusColor),
                  const SizedBox(height: 14),

                  // Systolic stepper
                  _buildBPStepper(
                    label: 'SYSTOLIC',
                    sub: 'Upper number',
                    value: _sys.toInt(),
                    onInc: () {
                      if (_sys < 250) { HapticFeedback.selectionClick(); setState(() => _sys++); }
                    },
                    onDec: () {
                      if (_sys > 50) { HapticFeedback.selectionClick(); setState(() => _sys--); }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Diastolic stepper
                  _buildBPStepper(
                    label: 'DIASTOLIC',
                    sub: 'Lower number',
                    value: _dia.toInt(),
                    onInc: () {
                      if (_dia < 150) { HapticFeedback.selectionClick(); setState(() => _dia++); }
                    },
                    onDec: () {
                      if (_dia > 30) { HapticFeedback.selectionClick(); setState(() => _dia--); }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Date/Time
                  _buildDateTimeCard(),
                  const SizedBox(height: 14),

                  // Context chips
                  _buildContextChips(),
                ],
              ),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: NuvitaButton(
              label: 'Save Reading',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────

  Widget _buildHeroCard(String statusLabel, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_rounded, size: 22, color: Color(0xFFD32F2F)),
          ),
          const SizedBox(height: 8),
          Text(
            'BLOOD PRESSURE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_sys.toInt()}',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -2, height: 1),
              ),
              Text(' / ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: AppColors.secondary, height: 1)),
              Text(
                '${_dia.toInt()}',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -2, height: 1),
              ),
              const SizedBox(width: 4),
              Text('mmHg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Healthy range: under 120 / 80 mmHg', style: TextStyle(fontSize: 11, color: AppColors.secondary)),
        ],
      ),
    );
  }

  Widget _buildBPStepper({
    required String label,
    required String sub,
    required int value,
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.secondary)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 13, color: AppColors.textDark)),
                ],
              ),
              const Spacer(),
              Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepperBtn(Icons.remove_rounded, false, onDec),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '± 1 mmHg',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.secondary),
                ),
              ),
              _stepperBtn(Icons.add_rounded, true, onInc),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(IconData icon, bool filled, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: filled ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: filled ? Colors.white : AppColors.primary),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _dtRow(Icons.calendar_month_rounded, 'Date', _formattedDate, _pickDate),
          Divider(height: 1, indent: 70, endIndent: 16, color: AppColors.divider),
          _dtRow(Icons.schedule_rounded, 'Time', _formattedTime, _pickTime),
        ],
      ),
    );
  }

  Widget _dtRow(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: AppColors.secondary)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildContextChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'ADD CONTEXT (OPTIONAL)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: const Color(0xFF6E7A82)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_contextChips.length, (i) {
            final selected = _contextIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _contextIndex = selected ? -1 : i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                ),
                child: Text(
                  _contextChips[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
