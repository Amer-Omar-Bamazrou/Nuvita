import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/dashboard/providers/health_provider.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../models/metric_config.dart';

class AddReadingInputScreen extends StatefulWidget {
  final HealthMetric metric;
  final MetricConfig config;
  final Future<void> Function(HealthMetric metric, double value, DateTime when) onSave;

  const AddReadingInputScreen({
    super.key,
    required this.metric,
    required this.config,
    required this.onSave,
  });

  @override
  State<AddReadingInputScreen> createState() => _AddReadingInputScreenState();
}

class _AddReadingInputScreenState extends State<AddReadingInputScreen> {
  late double _value;
  late HealthMetric _metric;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saving = false;
  int _contextIndex = -1;

  double get _step {
    switch (_metric) {
      case HealthMetric.weight:
      case HealthMetric.temperature:
        return 0.1;
      default:
        return 1.0;
    }
  }

  double get _initialValue {
    switch (_metric) {
      case HealthMetric.bloodSugarBefore:
      case HealthMetric.bloodSugarAfter:
      case HealthMetric.bloodSugar:
        return 100;
      case HealthMetric.systolic:
        return 120;
      case HealthMetric.diastolic:
        return 80;
      case HealthMetric.heartRate:
        return 70;
      case HealthMetric.weight:
        return 70;
      case HealthMetric.temperature:
        return 36.5;
      case HealthMetric.steps:
        return 30;
    }
  }

  @override
  void initState() {
    super.initState();
    _metric = widget.metric;
    _value = _initialValue;
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  // ── Display helpers ─────────────────────────────────────────────

  String _displayValue() {
    if (_step >= 1) return _value.toInt().toString();
    return _value.toStringAsFixed(1);
  }

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

  // ── Metric visuals ──────────────────────────────────────────────

  IconData get _metricIcon {
    switch (_metric) {
      case HealthMetric.temperature:
        return Icons.thermostat_rounded;
      case HealthMetric.weight:
        return Icons.scale_rounded;
      case HealthMetric.heartRate:
        return Icons.monitor_heart_rounded;
      case HealthMetric.bloodSugarBefore:
      case HealthMetric.bloodSugarAfter:
      case HealthMetric.bloodSugar:
        return Icons.water_drop_rounded;
      case HealthMetric.steps:
        return Icons.directions_walk_rounded;
      default:
        return widget.config.icon;
    }
  }

  Color get _metricColor {
    switch (_metric) {
      case HealthMetric.temperature:
        return const Color(0xFF0097A7);
      case HealthMetric.weight:
        return const Color(0xFF388E3C);
      case HealthMetric.heartRate:
        return const Color(0xFFE64A19);
      case HealthMetric.bloodSugarBefore:
      case HealthMetric.bloodSugarAfter:
      case HealthMetric.bloodSugar:
        return const Color(0xFF1976D2);
      case HealthMetric.steps:
        return const Color(0xFF7B1FA2);
      default:
        return AppColors.primary;
    }
  }

  String get _kicker {
    switch (_metric) {
      case HealthMetric.temperature:
        return 'BODY TEMPERATURE';
      case HealthMetric.weight:
        return 'BODY WEIGHT';
      case HealthMetric.heartRate:
        return 'HEART RATE';
      case HealthMetric.bloodSugarBefore:
        return 'FASTING BLOOD SUGAR';
      case HealthMetric.bloodSugarAfter:
        return 'POST-MEAL BLOOD SUGAR';
      case HealthMetric.bloodSugar:
        return 'BLOOD SUGAR';
      case HealthMetric.steps:
        return 'WALKING MINUTES';
      default:
        return widget.config.title.toUpperCase();
    }
  }

  (String label, Color color) get _status {
    switch (_metric) {
      case HealthMetric.temperature:
        if (_value >= 36.1 && _value <= 37.2) return ('Normal range', AppColors.success);
        if (_value < 36.1) return ('Low', AppColors.warning);
        if (_value <= 38.0) return ('Slightly high', AppColors.warning);
        return ('High', AppColors.error);
      case HealthMetric.weight:
        return ('Steady', AppColors.success);
      case HealthMetric.heartRate:
        if (_value >= 60 && _value <= 100) return ('Normal range', AppColors.success);
        if (_value < 60) return ('Low', AppColors.warning);
        return ('High', AppColors.warning);
      case HealthMetric.bloodSugarBefore:
        if (_value >= 70 && _value <= 100) return ('Normal', AppColors.success);
        if (_value < 70) return ('Low', AppColors.warning);
        if (_value <= 126) return ('Slightly high', AppColors.warning);
        return ('High', AppColors.error);
      case HealthMetric.bloodSugarAfter:
      case HealthMetric.bloodSugar:
        if (_value < 140) return ('Normal', AppColors.success);
        if (_value <= 180) return ('Slightly high', AppColors.warning);
        return ('High', AppColors.error);
      case HealthMetric.steps:
        if (_value >= 30) return ('Great', AppColors.success);
        if (_value >= 15) return ('Good', AppColors.success);
        return ('Low activity', AppColors.warning);
      default:
        return ('Recorded', AppColors.success);
    }
  }

  String? get _rangeHint {
    switch (_metric) {
      case HealthMetric.temperature:
        return 'Healthy range: 36.1 – 37.2 °C';
      case HealthMetric.heartRate:
        return 'Healthy range: 60 – 100 BPM';
      case HealthMetric.bloodSugarBefore:
        return 'Aim for 70 – 100 mg/dL fasting';
      case HealthMetric.bloodSugarAfter:
        return 'Aim for under 180 mg/dL 2h after eating';
      case HealthMetric.steps:
        return 'Aim for at least 30 minutes daily';
      default:
        return null;
    }
  }

  List<String> get _contextChips {
    switch (_metric) {
      case HealthMetric.temperature:
        return ['Resting', 'After exercise', 'After meal', 'Feeling unwell'];
      case HealthMetric.heartRate:
        return ['Resting', 'After exercise', 'After meal', 'Stressed'];
      case HealthMetric.bloodSugarBefore:
        return ['Just woke up', 'Before breakfast', 'Before lunch', 'Before dinner'];
      case HealthMetric.bloodSugarAfter:
        return ['After breakfast', 'After lunch', 'After dinner', 'After snack'];
      case HealthMetric.steps:
        return ['Walking', 'Jogging', 'Errands', 'Exercise'];
      default:
        return [];
    }
  }

  bool get _isBloodSugar =>
      _metric == HealthMetric.bloodSugarBefore ||
      _metric == HealthMetric.bloodSugarAfter;

  // ── Pickers ─────────────────────────────────────────────────────

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

  void _showTypeValueDialog() {
    final controller = TextEditingController(text: _displayValue());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter value', style: AppTextStyles.heading3),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: widget.config.unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= widget.config.min && v <= widget.config.max) {
                setState(() => _value = v);
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      await widget.onSave(_metric, _value, when);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save reading. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _increment() {
    final next = _value + _step;
    if (next <= widget.config.max) {
      HapticFeedback.selectionClick();
      setState(() => _value = double.parse(next.toStringAsFixed(1)));
    }
  }

  void _decrement() {
    final next = _value - _step;
    if (next >= widget.config.min) {
      HapticFeedback.selectionClick();
      setState(() => _value = double.parse(next.toStringAsFixed(1)));
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status;
    final chips = _contextChips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.config.title, style: AppTextStyles.heading2.copyWith(fontSize: 18)),
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
                  // Blood sugar meal toggle
                  if (_isBloodSugar) ...[
                    _buildMealToggle(),
                    const SizedBox(height: 14),
                  ],

                  // Hero card
                  _buildHeroCard(statusLabel, statusColor),
                  const SizedBox(height: 14),

                  // Date / Time card
                  _buildDateTimeCard(),

                  // Context chips
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildContextChips(chips),
                  ],
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

  Widget _buildMealToggle() {
    final isBefore = _metric == HealthMetric.bloodSugarBefore;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _mealTab('Before Meal', isBefore, () {
            if (!isBefore) {
              setState(() {
                _metric = HealthMetric.bloodSugarBefore;
                _contextIndex = -1;
              });
            }
          }),
          _mealTab('After Meal', !isBefore, () {
            if (isBefore) {
              setState(() {
                _metric = HealthMetric.bloodSugarAfter;
                _contextIndex = -1;
              });
            }
          }),
        ],
      ),
    );
  }

  Widget _mealTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(String statusLabel, Color statusColor) {
    final hint = _rangeHint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _metricColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_metricIcon, size: 22, color: _metricColor),
          ),
          const SizedBox(height: 8),

          // Kicker
          Text(
            _kicker,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Value
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _displayValue(),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.config.unit,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),

          // Status badge
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
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ],
            ),
          ),

          // Range hint
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: TextStyle(fontSize: 11, color: AppColors.secondary)),
          ],

          // Stepper
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepperButton(Icons.remove_rounded, false, _decrement),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '± ${_step >= 1 ? _step.toInt() : _step.toStringAsFixed(1)} ${widget.config.unit}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              _stepperButton(Icons.add_rounded, true, _increment),
            ],
          ),

          // Type a value
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showTypeValueDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Type a value',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, bool filled, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
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
        child: Icon(icon, size: 28, color: filled ? Colors.white : AppColors.primary),
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
          _dateTimeRow(
            icon: Icons.calendar_month_rounded,
            label: 'Date',
            value: _formattedDate,
            onTap: _pickDate,
          ),
          Divider(height: 1, indent: 70, endIndent: 16, color: AppColors.divider),
          _dateTimeRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: _formattedTime,
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }

  Widget _dateTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
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

  Widget _buildContextChips(List<String> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'ADD CONTEXT (OPTIONAL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: const Color(0xFF6E7A82),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(chips.length, (i) {
            final selected = _contextIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _contextIndex = selected ? -1 : i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Text(
                  chips[i],
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
