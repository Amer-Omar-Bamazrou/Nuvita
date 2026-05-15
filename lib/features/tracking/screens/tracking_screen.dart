import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../medication/models/medication_model.dart';
import '../../medication/services/medication_service.dart';
import '../../medication/screens/medication_screen.dart';
import '../../medication/screens/add_medication_screen.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/services/appointment_service.dart';
import '../../appointments/screens/appointments_screen.dart';
import '../../appointments/screens/add_appointment_screen.dart';
import '../../report/screens/report_screen.dart';
import '../../health/services/health_reading_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isGuest = false;
  bool _isLoading = true;

  List<MedicationModel> _medications = [];
  List<AppointmentModel> _appointments = [];
  int _readingsCount = 0;
  int _activeMedsCount = 0;
  Set<String> _takenKeys = {};

  @override
  void initState() {
    super.initState();
    _isGuest = FirebaseAuth.instance.currentUser == null;
    _loadData();
  }

  Future<void> _loadData() async {
    final meds = await MedicationService.loadAll();
    final activeMeds = meds.where((m) => m.isActive).toList();

    // Check which meds are taken today
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final taken = <String>{};
    for (final med in activeMeds) {
      for (final time in med.times) {
        final key = 'taken_${med.id}_${time}_$todayStr';
        if (prefs.getString(key) == 'true') {
          taken.add(med.id);
        }
      }
    }

    List<AppointmentModel> upcoming = [];
    int readingsCount = 0;

    if (!_isGuest) {
      upcoming = await AppointmentService.getUpcomingAppointments();

      // Count readings in last 30 days
      final uid = FirebaseAuth.instance.currentUser!.uid;
      try {
        final readings = await HealthReadingService.getReadingsLastDays(uid, 30);
        readingsCount = readings.length;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _medications = activeMeds;
      _appointments = upcoming;
      _readingsCount = readingsCount;
      _activeMedsCount = activeMeds.length;
      _takenKeys = taken;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _isLoading = true);
            await _loadData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('My Tracking', style: AppTextStyles.heading1),
                const SizedBox(height: 4),
                Text(
                  'Manage your health tools',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Guest sign-in prompt
                if (_isGuest) ...[
                  _buildGuestBanner(),
                  const SizedBox(height: 20),
                ],

                // Medications card
                _buildSectionLabel('MEDICATIONS'),
                const SizedBox(height: 8),
                _buildMedicationsCard(),
                const SizedBox(height: 20),

                // Appointments card (logged-in only)
                if (!_isGuest) ...[
                  _buildSectionLabel('APPOINTMENTS'),
                  const SizedBox(height: 8),
                  _buildAppointmentsCard(),
                  const SizedBox(height: 20),
                ],

                // Health report card (logged-in only)
                if (!_isGuest) ...[
                  _buildSectionLabel('HEALTH REPORT'),
                  const SizedBox(height: 8),
                  _buildReportCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Guest banner ──────────────────────────────────────────────────────────

  Widget _buildGuestBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in to access all tracking features',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Medications card ──────────────────────────────────────────────────────

  Widget _buildMedicationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _medications.isEmpty ? _buildEmptyMeds() : _buildMedsList(),
    );
  }

  Widget _buildEmptyMeds() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(Icons.medication_rounded,
            size: 40, color: AppColors.primary.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          'No medications added yet',
          style: AppTextStyles.body.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
            );
            _loadData();
          },
          child: const Text(
            'Add Medication',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedsList() {
    final displayMeds = _medications.take(3).toList();
    final remaining = _medications.length - 3;

    return Column(
      children: [
        for (int i = 0; i < displayMeds.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
          _buildMedRow(displayMeds[i]),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 8),
          Text(
            '+$remaining more medication${remaining > 1 ? 's' : ''}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationScreen()),
              );
              _loadData();
            },
            child: const Text(
              'Manage All →',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedRow(MedicationModel med) {
    final isTaken = _takenKeys.contains(med.id);
    final isLow = MedicationService.checkLowSupply(med);

    // Determine status
    Widget statusWidget;
    if (isLow) {
      statusWidget = const Text('⚠️',
          style: TextStyle(fontSize: 16));
    } else if (isTaken) {
      statusWidget = const Text('✅',
          style: TextStyle(fontSize: 16));
    } else {
      statusWidget = const Text('⏳',
          style: TextStyle(fontSize: 16));
    }

    // Next dose time
    final nextTime = med.times.isNotEmpty ? med.times.first : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nextTime.isNotEmpty)
                  Text(
                    'Next: $nextTime',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
          statusWidget,
        ],
      ),
    );
  }

  // ── Appointments card ─────────────────────────────────────────────────────

  Widget _buildAppointmentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _appointments.isEmpty
          ? _buildEmptyAppointments()
          : _buildAppointmentsList(),
    );
  }

  Widget _buildEmptyAppointments() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(Icons.calendar_today_rounded,
            size: 40, color: AppColors.primary.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          'No upcoming appointments',
          style: AppTextStyles.body.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
            );
            _loadData();
          },
          child: const Text(
            'Add Appointment',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
    final displayAppts = _appointments.take(2).toList();

    return Column(
      children: [
        for (int i = 0; i < displayAppts.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
          _buildAppointmentRow(displayAppts[i]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
              );
              _loadData();
            },
            child: const Text(
              'View All →',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentRow(AppointmentModel appt) {
    final badge = _dayBadge(appt.dateTime);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.doctorName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  appt.speciality,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
                Text(
                  _formatDateTime(appt.dateTime),
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          badge,
        ],
      ),
    );
  }

  Widget _dayBadge(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = apptDay.difference(today).inDays;

    String label;
    Color bgColor;

    if (diff == 0) {
      label = 'Today';
      bgColor = AppColors.error;
    } else if (diff == 1) {
      label = 'Tomorrow';
      bgColor = AppColors.warning;
    } else {
      label = 'In $diff days';
      bgColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $hour:$min $amPm';
  }

  // ── Report card ───────────────────────────────────────────────────────────

  Widget _buildReportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Health Report',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Generate and share your health report with your doctor',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$_readingsCount readings • $_activeMedsCount medications',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportScreen()),
                );
              },
              child: const Text(
                'Generate & Share →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
