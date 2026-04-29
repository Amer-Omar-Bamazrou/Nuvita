import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import 'add_appointment_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppointmentModel> _upcoming = [];
  List<AppointmentModel> _past = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final upcoming = await AppointmentService.getUpcomingAppointments();
    final past = await AppointmentService.getPastAppointments();
    if (!mounted) return;
    setState(() {
      _upcoming = upcoming;
      _past = past;
      _isLoading = false;
    });
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _delete(String id) async {
    await AppointmentService.deleteAppointment(id);
    _loadData();
  }

  Future<void> _markDone(String id) async {
    await AppointmentService.markAsCompleted(id);
    _loadData();
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
        title: Text('My Appointments', style: AppTextStyles.heading2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded,
                color: AppColors.primary, size: 28),
            onPressed: _openAddScreen,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUpcomingTab(),
                _buildPastTab(),
              ],
            ),
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcoming.isEmpty) {
      return _buildEmptyState(
        'No upcoming appointments',
        'Tap + to add your first appointment',
        Icons.calendar_today_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _upcoming.length,
      itemBuilder: (context, i) {
        final apt = _upcoming[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: apt.isCompleted
              ? _buildCard(apt, isCompleted: true, isPast: false)
              : _buildDismissibleCard(apt),
        );
      },
    );
  }

  Widget _buildPastTab() {
    if (_past.isEmpty) {
      return _buildEmptyState(
        'No past appointments',
        'Your appointment history will appear here',
        Icons.history_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _past.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCard(_past[i], isCompleted: true, isPast: true),
        );
      },
    );
  }

  // Wraps a pending upcoming card with swipe-to-delete
  Widget _buildDismissibleCard(AppointmentModel apt) {
    return Dismissible(
      key: Key(apt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded,
            color: AppColors.error, size: 26),
      ),
      onDismissed: (_) => _delete(apt.id),
      child: _buildCard(apt, isCompleted: false, isPast: false),
    );
  }

  Widget _buildCard(
    AppointmentModel apt, {
    required bool isCompleted,
    required bool isPast,
  }) {
    final inDays = apt.dateTime.difference(DateTime.now()).inDays;
    final cardColor =
        isCompleted ? Colors.grey.shade100 : Colors.white;
    final textColor = isCompleted ? Colors.grey : AppColors.textDark;
    final subColor = isCompleted ? Colors.grey : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apt.doctorName,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      apt.speciality,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: subColor),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: subColor),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(apt.dateTime)}  •  ${_formatTime(apt.dateTime)}',
                          style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 13, color: subColor),
                        ),
                      ],
                    ),
                    if (apt.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 14, color: subColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              apt.location,
                              style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 13, color: subColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (apt.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        apt.notes,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 12,
                          color: isCompleted
                              ? Colors.grey.shade400
                              : AppColors.secondary.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Day badge only for pending upcoming cards
              if (!isPast && !isCompleted) ...[
                const SizedBox(width: 12),
                _buildDaysBadge(inDays),
              ],
            ],
          ),
          // "Mark as Done" only for pending upcoming cards
          if (!isPast && !isCompleted) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _markDone(apt.id),
                icon: const Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: AppColors.success),
                label: Text(
                  'Mark as Done',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaysBadge(int inDays) {
    final Color badgeColor;
    final String label;

    if (inDays == 0) {
      badgeColor = AppColors.error;
      label = 'Today';
    } else if (inDays == 1) {
      badgeColor = AppColors.warning;
      label = 'Tomorrow';
    } else {
      badgeColor = AppColors.primary;
      label = 'In $inDays days';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.secondary, size: 56),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

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
}
