import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/health/health_metrics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_time_picker.dart';
import '../models/reading_entry.dart';
import '../widgets/status_display.dart';
import '../widgets/value_entry_dialog.dart';

class BloodPressureInputScreen extends StatefulWidget {
  final SaveReadings onSave;

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

  // Pulse is optional; a heart-rate reading is only saved when this is filled in
  final _pulseController = TextEditingController();

  static const _contextChips = ['Resting', 'After exercise', 'After meal', 'Stressed'];

  static final _sysDef = HealthMetrics.of(HealthMetric.systolic);
  static final _diaDef = HealthMetrics.of(HealthMetric.diastolic);
  static final _pulseDef = HealthMetrics.of(HealthMetric.heartRate);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Status ──────────────────────────────────────────────────────

  // The pair shows whichever of systolic and diastolic is more concerning
  (String, Color) get _status => statusDisplay(HealthMetrics.worseStatus(
        HealthMetrics.evaluate(HealthMetric.systolic, _sys),
        HealthMetrics.evaluate(HealthMetric.diastolic, _dia),
      ));

  String get _rangeHint {
    final sys = _sysDef.bands!;
    final dia = _diaDef.bands!;
    return 'Normal range: ${sys.low.toInt()}–${sys.normalMax.toInt()} / '
        '${dia.low.toInt()}–${dia.normalMax.toInt()} mmHg';
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
    final picked = await showNuvitaTimePicker(
      context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _typeValue({required bool systolic}) async {
    final v = await showValueEntryDialog(
      context,
      def: systolic ? _sysDef : _diaDef,
      initial: systolic ? _sys : _dia,
      title: systolic ? 'Enter systolic' : 'Enter diastolic',
    );
    if (v == null || !mounted) return;
    // Steppers move in whole mmHg, so keep typed values whole too
    setState(() {
      if (systolic) {
        _sys = v.roundToDouble();
      } else {
        _dia = v.roundToDouble();
      }
    });
  }

  // ── Submit ──────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_sys <= _dia) {
      _showError('Systolic (upper number) must be higher than diastolic.');
      return;
    }

    double? pulse;
    final pulseText = _pulseController.text.trim();
    if (pulseText.isNotEmpty) {
      pulse = double.tryParse(pulseText);
      if (pulse == null || !_pulseDef.isInRange(pulse)) {
        _showError('Enter a pulse between ${_pulseDef.min.toInt()} and '
            '${_pulseDef.max.toInt()} ${_pulseDef.unit}, or leave it empty.');
        return;
      }
    }

    final when = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (when.isAfter(DateTime.now())) {
      _showError("The reading time can't be in the future.");
      return;
    }

    setState(() => _saving = true);
    try {
      final note = _contextIndex >= 0 ? _contextChips[_contextIndex] : null;
      await widget.onSave([
        ReadingEntry(metric: HealthMetric.systolic, value: _sys, note: note),
        ReadingEntry(metric: HealthMetric.diastolic, value: _dia, note: note),
        if (pulse != null)
          ReadingEntry(metric: HealthMetric.heartRate, value: pulse, note: note),
      ], when);
      if (mounted) Navigator.pop(context, true);
    } on ReadingSaveException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Failed to save reading. Please try again.');
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
                    onType: () => _typeValue(systolic: true),
                    onInc: () {
                      if (_sys < _sysDef.max) { HapticFeedback.selectionClick(); setState(() => _sys++); }
                    },
                    onDec: () {
                      if (_sys > _sysDef.min) { HapticFeedback.selectionClick(); setState(() => _sys--); }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Diastolic stepper
                  _buildBPStepper(
                    label: 'DIASTOLIC',
                    sub: 'Lower number',
                    value: _dia.toInt(),
                    onType: () => _typeValue(systolic: false),
                    onInc: () {
                      if (_dia < _diaDef.max) { HapticFeedback.selectionClick(); setState(() => _dia++); }
                    },
                    onDec: () {
                      if (_dia > _diaDef.min) { HapticFeedback.selectionClick(); setState(() => _dia--); }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Optional pulse
                  _buildPulseCard(),
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
          Text(_rangeHint, style: TextStyle(fontSize: 11, color: AppColors.secondary)),
        ],
      ),
    );
  }

  Widget _buildBPStepper({
    required String label,
    required String sub,
    required int value,
    required VoidCallback onType,
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
              GestureDetector(
                onTap: onType,
                child: Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -0.5)),
              ),
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
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onType,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Type a value',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PULSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.secondary)),
              const SizedBox(height: 2),
              Text('Optional', style: TextStyle(fontSize: 13, color: AppColors.textDark)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
              decoration: InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(fontSize: 22, color: AppColors.secondary.withValues(alpha: 0.5)),
                suffixText: _pulseDef.unit,
                suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
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
