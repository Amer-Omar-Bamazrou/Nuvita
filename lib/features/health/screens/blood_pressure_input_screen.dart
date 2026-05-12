import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/dashboard/providers/health_provider.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../widgets/ruler_picker.dart';

// Saves systolic, diastolic, and pulse as three separate readings.
class BloodPressureInputScreen extends StatefulWidget {
  final Future<void> Function(HealthMetric metric, double value, DateTime when) onSave;

  const BloodPressureInputScreen({super.key, required this.onSave});

  @override
  State<BloodPressureInputScreen> createState() => _BloodPressureInputScreenState();
}

enum _BPField { sys, dia, pulse }

class _BloodPressureInputScreenState extends State<BloodPressureInputScreen> {
  _BPField _active = _BPField.sys;

  double _sys = 120;
  double _dia = 80;
  double _pulse = 70;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  double get _activeValue {
    switch (_active) {
      case _BPField.sys:
        return _sys;
      case _BPField.dia:
        return _dia;
      case _BPField.pulse:
        return _pulse;
    }
  }

  void _setActiveValue(double v) {
    setState(() {
      switch (_active) {
        case _BPField.sys:
          _sys = v;
        case _BPField.dia:
          _dia = v;
        case _BPField.pulse:
          _pulse = v;
      }
    });
  }

  (double min, double max) get _activeRange {
    switch (_active) {
      case _BPField.sys:
        return (50, 250);
      case _BPField.dia:
        return (30, 150);
      case _BPField.pulse:
        return (20, 250);
    }
  }

  String get _activeLabel {
    switch (_active) {
      case _BPField.sys:
        return 'Systolic';
      case _BPField.dia:
        return 'Diastolic';
      case _BPField.pulse:
        return 'Pulse';
    }
  }

  String get _formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (_selectedDate == today) return 'Today';
    if (_selectedDate == yesterday) return 'Yesterday';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
        widget.onSave(HealthMetric.heartRate, _pulse, when),
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

  @override
  Widget build(BuildContext context) {
    final (min, max) = _activeRange;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Blood Pressure', style: AppTextStyles.heading2),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Segment selector: Sys / Dia / Pulse
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: _BPField.values.map((field) {
                final selected = _active == field;
                final label = switch (field) {
                  _BPField.sys => 'Sys',
                  _BPField.dia => 'Dia',
                  _BPField.pulse => 'Pulse',
                };
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _active = field),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // Active field label + value
          Text(
            _activeLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _activeValue.toInt().toString(),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'mmHg',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0x66004346),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Ruler — keyed by field so it re-mounts with correct initial value
          KeyedSubtree(
            key: ValueKey(_active),
            child: RulerPicker(
              min: min,
              max: max,
              step: 1,
              initialValue: _activeValue,
              onChanged: _setActiveValue,
            ),
          ),

          const SizedBox(height: 28),

          // Summary: all three values
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _summaryChip('Sys', _sys.toInt(), _active == _BPField.sys),
                const SizedBox(width: 10),
                _summaryChip('Dia', _dia.toInt(), _active == _BPField.dia),
                const SizedBox(width: 10),
                _summaryChip('Pulse', _pulse.toInt(), _active == _BPField.pulse),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Date & Time rows
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary, size: 20),
                  title: const Text('Date'),
                  trailing: Text(
                    _formattedDate,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: _pickDate,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.access_time_rounded,
                      color: AppColors.primary, size: 20),
                  title: const Text('Time'),
                  trailing: Text(
                    _formattedTime,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: NuvitaButton(
              label: 'Track now',
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int value, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _active = switch (label) {
            'Sys' => _BPField.sys,
            'Dia' => _BPField.dia,
            _ => _BPField.pulse,
          };
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primary : Colors.grey.shade200,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
