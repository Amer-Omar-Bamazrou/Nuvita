import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.showConfirmDialog = false,
  });

  final AppointmentModel appointment;
  // When true, auto-shows the confirmation dialog on first frame (used by notification tap)
  final bool showConfirmDialog;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late AppointmentModel _apt;

  @override
  void initState() {
    super.initState();
    _apt = widget.appointment;
    if (widget.showConfirmDialog && !_apt.isCompleted && !_apt.isConfirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConfirmDialog());
    }
  }

  Future<void> _showConfirmDialog() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Appointment Confirmation'),
        content: Text(
          'Will you attend your appointment with ${_apt.doctorName} '
          'on ${_formatDate(_apt.dateTime)} at ${_formatTime(_apt.dateTime)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('reschedule'),
            child: const Text('Reschedule'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('confirm'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text("Yes, I'll attend"),
          ),
        ],
      ),
    );

    if (result == 'confirm') {
      await _confirmAttendance();
    }
    // 'reschedule' or barrier dismiss: dialog closes, user stays on this screen
  }

  Future<void> _confirmAttendance() async {
    final updated = _apt.copyWith(isConfirmed: true);
    await AppointmentService.updateAppointment(updated);
    if (!mounted) return;
    setState(() => _apt = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Confirmed')),
    );
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
        title: Text('Appointment Details', style: AppTextStyles.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _apt.doctorName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_apt.speciality, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (_apt.isConfirmed)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Confirmed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _infoRow(
            Icons.schedule_rounded,
            'Date & Time',
            '${_formatDate(_apt.dateTime)}  ·  ${_formatTime(_apt.dateTime)}',
          ),
          if (_apt.location.isNotEmpty) ...[
            _rowDivider(),
            _infoRow(Icons.location_on_rounded, 'Location', _apt.location),
          ],
          _rowDivider(),
          _infoRow(
            Icons.notifications_rounded,
            'Reminder',
            _formatReminder(_apt.reminderMinutes),
          ),
          if (_apt.notes.isNotEmpty) ...[
            _rowDivider(),
            _infoRow(Icons.notes_rounded, 'Notes', _apt.notes),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  String _formatReminder(int minutes) {
    if (minutes < 60) return '$minutes minutes before';
    if (minutes == 60) return '1 hour before';
    if (minutes == 1440) return '1 day before';
    if (minutes == 2880) return '2 days before';
    return '${minutes ~/ 60} hours before';
  }
}
