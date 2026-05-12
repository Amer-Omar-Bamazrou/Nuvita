import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/dashboard/providers/health_provider.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../models/metric_config.dart';
import '../widgets/ruler_picker.dart';

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
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saving = false;

  double get _step {
    switch (widget.metric) {
      case HealthMetric.weight:
      case HealthMetric.temperature:
        return 0.1;
      default:
        return 1.0;
    }
  }

  double get _initialValue {
    final mid = (widget.config.min + widget.config.max) / 2;
    // Sensible defaults per metric
    switch (widget.metric) {
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
      default:
        return mid;
    }
  }

  @override
  void initState() {
    super.initState();
    _value = _initialValue;
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
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
      await widget.onSave(widget.metric, _value, when);
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

  String _displayValue() {
    if (_step >= 1) return _value.toInt().toString();
    return _value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(config.title, style: AppTextStyles.heading2),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),

          // Large value display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _displayValue(),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  config.unit,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Ruler picker
          RulerPicker(
            min: config.min,
            max: config.max,
            step: _step,
            initialValue: _value,
            onChanged: (v) => setState(() => _value = v),
          ),

          const SizedBox(height: 32),

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

          // Track now button
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
}
