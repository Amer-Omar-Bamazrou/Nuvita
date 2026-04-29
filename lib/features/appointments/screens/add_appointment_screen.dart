import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';

class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _specialityController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Default to tomorrow so the date picker opens in a sensible state
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _reminderMinutes = 60;
  bool _isSaving = false;

  static const _reminderOptions = [
    {'label': '15 minutes before', 'value': 15},
    {'label': '30 minutes before', 'value': 30},
    {'label': '1 hour before', 'value': 60},
    {'label': '1 day before', 'value': 1440},
    {'label': '2 days before', 'value': 2880},
  ];

  @override
  void dispose() {
    _doctorController.dispose();
    _specialityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final appointmentDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointment = AppointmentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      doctorName: _doctorController.text.trim(),
      speciality: _specialityController.text.trim(),
      location: _locationController.text.trim(),
      dateTime: appointmentDateTime,
      notes: _notesController.text.trim(),
      reminderMinutes: _reminderMinutes,
    );

    await AppointmentService.saveAppointment(appointment);
    await AppointmentService.scheduleReminder(appointment);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
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
        title: Text('Add Appointment', style: AppTextStyles.heading3),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NuvitaTextField(
                label: 'Doctor Name',
                hint: 'e.g. Dr. Smith',
                controller: _doctorController,
                prefixIcon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Doctor name is required'
                    : null,
              ),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Speciality',
                hint: 'e.g. Cardiologist',
                controller: _specialityController,
                prefixIcon: Icons.medical_services_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Speciality is required'
                    : null,
              ),
              const SizedBox(height: 24),
              Text('Date & Time', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildPickerRow(
                icon: Icons.calendar_today_rounded,
                label: 'Appointment date',
                value: _formatDate(_selectedDate),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              _buildPickerRow(
                icon: Icons.schedule_rounded,
                label: 'Appointment time',
                value: _formatTime(_selectedTime),
                onTap: _pickTime,
              ),
              const SizedBox(height: 24),
              Text('Reminder', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildReminderDropdown(),
              const SizedBox(height: 24),
              NuvitaTextField(
                label: 'Location (optional)',
                hint: 'e.g. City Hospital, Room 3B',
                controller: _locationController,
                prefixIcon: Icons.location_on_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Notes (optional)',
                hint: 'Bring test results, fasting required...',
                controller: _notesController,
                prefixIcon: Icons.notes_rounded,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              NuvitaButton(
                label: 'Save Appointment',
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

  Widget _buildPickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.heading3.copyWith(fontSize: 16)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _reminderMinutes,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.secondary),
          style: AppTextStyles.body.copyWith(color: AppColors.textDark),
          items: _reminderOptions.map((option) {
            return DropdownMenuItem<int>(
              value: option['value'] as int,
              child: Text(option['label'] as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _reminderMinutes = value);
          },
        ),
      ),
    );
  }
}
