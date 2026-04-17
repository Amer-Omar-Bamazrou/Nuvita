import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/notification_service.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  String _frequency = 'Once daily';
  // TimeOfDay list — size changes with frequency
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;

  static const _frequencies = ['Once daily', 'Twice daily', 'Three times daily'];
  static const _frequencyTimeCounts = {'Once daily': 1, 'Twice daily': 2, 'Three times daily': 3};

  // Default times per slot
  static const _defaultTimes = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ];

  static const _timeLabels = ['Morning dose', 'Afternoon dose', 'Evening dose'];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(String freq) {
    final count = _frequencyTimeCounts[freq]!;
    setState(() {
      _frequency = freq;
      _times = List.generate(count, (i) => i < _times.length ? _times[i] : _defaultTimes[i]);
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final med = MedicationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      frequency: _frequency,
      times: _times.map(_formatTime).toList(),
      startDate: _startDate,
      notes: _notesController.text.trim(),
    );

    await MedicationService.add(med);
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    await NotificationService.scheduleMedicationReminder(med);

    if (!mounted) return;
    Navigator.of(context).pop(true); // true signals caller to reload
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Add Medication', style: AppTextStyles.heading3),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NuvitaTextField(
                label: 'Medication Name',
                hint: 'e.g. Metformin',
                controller: _nameController,
                prefixIcon: Icons.medication_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Dosage',
                hint: 'e.g. 500mg',
                controller: _dosageController,
                prefixIcon: Icons.colorize_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Dosage is required' : null,
              ),
              const SizedBox(height: 24),
              Text('How often?', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildFrequencySelector(),
              const SizedBox(height: 24),
              Text('Reminder times', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              ...List.generate(
                _times.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTimePicker(i),
                ),
              ),
              const SizedBox(height: 12),
              Text('Start date', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Notes (optional)',
                hint: 'Take with food, avoid grapefruit...',
                controller: _notesController,
                prefixIcon: Icons.notes_rounded,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              NuvitaButton(
                label: 'Save Medication',
                onPressed: _onSave,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      children: _frequencies.map((freq) {
        final isSelected = _frequency == freq;
        return GestureDetector(
          onTap: () => _onFrequencyChanged(freq),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.07)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  freq,
                  style: AppTextStyles.body.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker(int index) {
    final label = _timeLabels[index];
    final time = _times[index];
    final display = time.format(context);

    return GestureDetector(
      onTap: () => _pickTime(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickStartDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starting from', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  _formatDate(_startDate),
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
