import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/preferences_service.dart';
import '../../dashboard/providers/health_provider.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../notifications/screens/suggestions_panel_screen.dart';
import '../../emergency/emergency_service.dart';
import '../../emergency/trend_warning_service.dart';
import '../../medication/services/medication_service.dart';
import '../../medication/screens/add_medication_screen.dart';
import '../../health/models/health_reading.dart';
import '../../health/models/metric_config.dart';
import '../../health/services/health_reading_service.dart';
import '../../health/screens/add_reading_input_screen.dart';
import '../../health/screens/blood_pressure_input_screen.dart';
import '../../appointments/screens/add_appointment_screen.dart';
import '../../doctor/services/patient_suggestion_service.dart';
import '../../../core/services/notification_service.dart';

// ─── Task model ──────────────────────────────────────────────────────────────

class DailyTask {
  final String id;
  final String timeOfDay;
  final String displayName;
  final String? subtitle;
  final String? medicationId;
  bool isCompleted;

  DailyTask({
    required this.id,
    required this.timeOfDay,
    required this.displayName,
    this.subtitle,
    this.medicationId,
    this.isCompleted = false,
  });
}

// ─── Screen entry point ───────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider scoped to this screen — readings are local session state
    return ChangeNotifierProvider(
      create: (_) => HealthProvider(),
      child: const _HomeBody(),
    );
  }
}

// ─── Screen body ──────────────────────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  bool _isLoading = true;
  String _userName = '';
  String _diseaseType = 'other';
  int _medScheduleCount = 0;
  List<DailyTask> _tasks = [];
  bool _isLoadingTasks = false;
  final _suggestionService = PatientSuggestionService();

  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart Condition',
    'other': 'General Monitoring',
  };

  // Metric config used for reading task validation and units
  static const _configs = <HealthMetric, MetricConfig>{
    HealthMetric.bloodSugar: MetricConfig(
      title: 'Blood Sugar',
      icon: Icons.water_drop,
      unit: 'mg/dL',
      min: 20,
      max: 600,
    ),
    HealthMetric.bloodSugarBefore: MetricConfig(
      title: 'Blood Sugar (Before Meal)',
      icon: Icons.water_drop,
      unit: 'mg/dL',
      min: 20,
      max: 600,
    ),
    HealthMetric.bloodSugarAfter: MetricConfig(
      title: 'Blood Sugar (After Meal)',
      icon: Icons.water_drop_outlined,
      unit: 'mg/dL',
      min: 20,
      max: 600,
    ),
    HealthMetric.systolic: MetricConfig(
      title: 'Systolic BP',
      icon: Icons.favorite,
      unit: 'mmHg',
      min: 50,
      max: 250,
    ),
    HealthMetric.diastolic: MetricConfig(
      title: 'Diastolic BP',
      icon: Icons.favorite_border,
      unit: 'mmHg',
      min: 30,
      max: 150,
    ),
    HealthMetric.heartRate: MetricConfig(
      title: 'Heart Rate',
      icon: Icons.monitor_heart,
      unit: 'BPM',
      min: 20,
      max: 250,
    ),
    HealthMetric.weight: MetricConfig(
      title: 'Weight',
      icon: Icons.scale,
      unit: 'kg',
      min: 20,
      max: 300,
    ),
    HealthMetric.steps: MetricConfig(
      title: 'Walking',
      icon: Icons.directions_walk,
      unit: 'min',
      min: 0,
      max: 300,
    ),
    HealthMetric.temperature: MetricConfig(
      title: 'Temperature',
      icon: Icons.thermostat,
      unit: '°C',
      min: 30,
      max: 45,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadMedSummary();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final savedFirstName = await PreferencesService.getFirstName();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _userName = savedFirstName ?? '';
        _isLoading = false;
      });
      // Still build guest task prompt
      _loadTasks();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      setState(() {
        final firestoreName = profile?['name'] as String? ?? '';
        _userName =
            firestoreName.isNotEmpty ? firestoreName : (savedFirstName ?? '');
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
        _isLoading = false;
      });
      if (mounted) {
        context.read<HealthProvider>().loadReadingsFromFirebase(uid);
        context.read<HealthHistoryProvider>().loadReadings(uid);
        TrendWarningService.checkBPTrend(context, uid);
      }
    } catch (_) {
      setState(() {
        _userName = savedFirstName ?? '';
        _isLoading = false;
      });
    }

    // Load tasks after disease type is known
    _loadTasks();
  }

  Future<void> _loadMedSummary() async {
    final meds = await MedicationService.loadAll();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    var count = 0;
    for (final med in meds) {
      if (!med.isActive) continue;
      final start = med.startDate;
      if (DateTime(start.year, start.month, start.day).isAfter(todayDate)) {
        continue;
      }
      count += med.times.length;
    }
    if (mounted) setState(() => _medScheduleCount = count);
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final tasks = <DailyTask>[];
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final services = await PreferencesService.getSelectedServices();
    final showMeds =
        services.isEmpty || services.contains('medications');

    // Medication tasks only
    if (uid != null && showMeds) {
      final meds = await MedicationService.loadAll();
      final prefs = await SharedPreferences.getInstance();
      for (final med in meds) {
        if (!med.isActive) continue;
        final start = med.startDate;
        if (DateTime(start.year, start.month, start.day).isAfter(todayStart)) {
          continue;
        }
        for (final time in med.times) {
          final prefKey = 'taken_${med.id}_${time}_$todayStr';
          final taken = prefs.getString(prefKey) == 'true';
          tasks.add(DailyTask(
            id: '${med.id}_$time',
            timeOfDay: time,
            displayName: med.name,
            subtitle: med.dosage,
            medicationId: med.id,
            isCompleted: taken,
          ));
        }
      }
    }

    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.timeOfDay.compareTo(b.timeOfDay);
    });

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
      });
    }
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.timeOfDay.compareTo(b.timeOfDay);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _formattedDate {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
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

    return Consumer2<HealthProvider, HealthHistoryProvider>(
      builder: (context, provider, historyProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadMedSummary();
                await _loadTasks();
              },
              child: SingleChildScrollView(
                // Ensures RefreshIndicator works even when content is short
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(provider),
                    const SizedBox(height: 16),
                    _buildDailySummaryCard(historyProvider),
                    const SizedBox(height: 16),
                    _buildSummaryBanner(),
                    const SizedBox(height: 6),
                    _buildSimulateButton(context),
                    const SizedBox(height: 20),
                    _buildTaskList(),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _buildFAB(context),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  // ── Header: greeting + date + notification icon ───────────────────────────

  Widget _buildHeader(HealthProvider provider) {
    final firstName = _userName.trim().split(' ').first;
    final hasWarning = _hasConcerningReadings(provider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                firstName.isEmpty ? 'Welcome' : firstName,
                style: AppTextStyles.heading1,
              ),
              const SizedBox(height: 4),
              Text(_formattedDate, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SuggestionsPanelScreen(
                diseaseType: _diseaseType,
                currentReadings: {
                  for (final m in HealthMetric.values)
                    m.name: context.read<HealthProvider>().getValue(m),
                },
              ),
            ),
          ),
          child: uid == null
              ? _buildBellIcon(hasWarning)
              : StreamBuilder<int>(
                  stream: _suggestionService.listenToUnreadCount(uid),
                  builder: (context, snap) {
                    final showBadge = (snap.data ?? 0) > 0 || hasWarning;
                    return _buildBellIcon(showBadge);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBellIcon(bool hasBadge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.notifications_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        if (hasBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  // ── Daily summary card ────────────────────────────────────────────────────

  Widget _buildDailySummaryCard(HealthHistoryProvider historyProvider) {
    final todayCount = historyProvider.todayCount;
    final lastTime = historyProvider.lastReadingTime;
    final lastText = _formatLastReadingTime(lastTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Text(
            "Today's Summary",
            style: AppTextStyles.label.copyWith(
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSummaryItem(
                Icons.monitor_heart_rounded,
                '$todayCount',
                'readings today',
                AppColors.success,
              ),
              const SizedBox(width: 8),
              _buildSummaryItem(
                Icons.medication_rounded,
                '$_medScheduleCount',
                'meds scheduled',
                const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              _buildSummaryItem(
                Icons.access_time_rounded,
                lastText,
                'last reading',
                AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.label.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastReadingTime(DateTime? time) {
    if (time == null) return 'No reading';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _hasConcerningReadings(HealthProvider provider) {
    for (final m in HealthMetric.values) {
      final value = provider.getValue(m);
      if (value == null) continue;
      final status = provider.getStatus(m, value);
      if (status == MetricStatus.warning ||
          status == MetricStatus.criticalLow ||
          status == MetricStatus.criticalHigh) {
        return true;
      }
    }
    return false;
  }

  // ── Summary banner: "Managing: Blood Pressure" ───────────────────────────

  Widget _buildSummaryBanner() {
    final label = _diseaseLabels[_diseaseType] ?? 'General Monitoring';
    final emoji = switch (_diseaseType) {
      'diabetes' => '🩸',
      'blood_pressure' => '💉',
      'heart' => '❤️',
      _ => '➕',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managing',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style:
                      AppTextStyles.heading3.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
          // SOS button — tap to start emergency countdown
          GestureDetector(
            onTap: () => EmergencyService.showEmergencyFlow(context),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ── Simulate critical reading — quick testing shortcut ───────────────────

  Widget _buildSimulateButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => EmergencyService.showEmergencyFlow(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Simulate Critical Reading',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  // ── Task list ─────────────────────────────────────────────────────────────

  Widget _buildTaskList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Guest user — no tasks to show
    if (uid == null) return _buildGuestTaskPrompt();

    if (_isLoadingTasks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final remaining = _tasks.where((t) => !t.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Today's Tasks", style: AppTextStyles.heading3),
            const Spacer(),
            Text(
              '$remaining task${remaining == 1 ? '' : 's'} remaining',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.secondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (remaining == 0)
          _buildAllDoneState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildTaskCard(_tasks[i]),
          ),
      ],
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    if (task.isCompleted) return _buildCompletedCard(task);
    return _buildPendingMedCard(task);
  }

  Widget _buildPendingMedCard(DailyTask task) {
    return Container(
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
              Text(
                task.timeOfDay,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Icon(Icons.medication_rounded,
                  color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(task.displayName, style: AppTextStyles.heading3),
          if (task.subtitle != null && task.subtitle!.isNotEmpty)
            Text(task.subtitle!,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _markMedTaken(task),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: AppColors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Mark as Taken',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(DailyTask task) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF388E3C), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.displayName,
                    style: AppTextStyles.label.copyWith(
                        color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const Text('Taken', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Text(task.timeOfDay, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDoneState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: Color(0xFF388E3C),
            ),
            const SizedBox(height: 16),
            Text('All caught up!', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'No medications scheduled for today.\nUse the + button to log a reading.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestTaskPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.task_alt_outlined,
                color: AppColors.primary, size: 56),
            const SizedBox(height: 16),
            Text(
              'Sign in to see your daily tasks',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your medications and readings\nwill appear here',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Task actions ──────────────────────────────────────────────────────────

  Future<void> _markMedTaken(DailyTask task) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final prefKey = 'taken_${task.medicationId}_${task.timeOfDay}_$todayStr';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, 'true');

    if (task.medicationId != null) {
      await MedicationService.takeMedication(task.medicationId!);
      MedicationService.saveDoseToFirebase(
        medicationId: task.medicationId!,
        medicationName: task.displayName,
        dosage: task.subtitle ?? '',
        timeSlot: task.timeOfDay,
        date: todayStr,
      );
    }

    if (mounted) {
      setState(() {
        task.isCompleted = true;
        _sortTasks();
      });
    }
  }

  String _statusToString(MetricStatus? status) {
    switch (status) {
      case MetricStatus.normal:
        return 'Normal';
      case MetricStatus.warning:
        return 'Warning';
      case MetricStatus.criticalLow:
        return 'Low';
      case MetricStatus.criticalHigh:
        return 'High';
      case null:
        return 'Logged';
    }
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext _) {
    return SizedBox(
      height: 52,
      child: FloatingActionButton.extended(
        heroTag: 'fab_home',
        onPressed: _showAddSheet,
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        icon: const Icon(Icons.add_rounded, color: AppColors.white, size: 22),
        label: Text(
          "Add Today's Reading",
          style: AppTextStyles.buttonText.copyWith(fontSize: 15),
        ),
      ),
    );
  }

  // Sheet methods use the State's own context directly — it outlives any sheet
  // or Consumer2 builder context, preventing _dependents.isEmpty assertion errors.
  void _showAddSheet() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateLabel = '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x2E004346),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "Add Today's Entry",
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'What would you like to log right now?',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'QUICK MEASUREMENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: const Color(0xFF6E7A82),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.15,
                  children: [
                    _buildQuickChip(Icons.water_drop_rounded, const Color(0xFF1976D2), 'Sugar', sheetCtx, HealthMetric.bloodSugarBefore),
                    _buildQuickChip(Icons.favorite_rounded, const Color(0xFFD32F2F), 'BP', sheetCtx, null),
                    _buildQuickChip(Icons.monitor_heart_rounded, const Color(0xFFE64A19), 'Heart', sheetCtx, HealthMetric.heartRate),
                    _buildQuickChip(Icons.scale_rounded, const Color(0xFF388E3C), 'Weight', sheetCtx, HealthMetric.weight),
                    _buildQuickChip(Icons.directions_walk_rounded, const Color(0xFF7B1FA2), 'Steps', sheetCtx, HealthMetric.steps),
                    _buildQuickChip(Icons.thermostat_rounded, const Color(0xFF0097A7), 'Temp', sheetCtx, HealthMetric.temperature),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 16),
                Text(
                  'OTHER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: const Color(0xFF6E7A82),
                  ),
                ),
                const SizedBox(height: 10),
                _buildOtherRow(
                  icon: Icons.medication_rounded,
                  color: AppColors.card,
                  label: 'Medication',
                  subtitle: 'Log a dose or add a new med',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddMedicationScreen()),
                    ).then((_) => _loadMedSummary());
                  },
                ),
                const SizedBox(height: 8),
                _buildOtherRow(
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF00695C),
                  label: 'Appointment',
                  subtitle: 'Book or note a visit',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddAppointmentScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToMetric(HealthMetric? metric) async {
    Widget screen;
    if (metric == null) {
      screen = BloodPressureInputScreen(onSave: _saveReading);
    } else {
      final config = _configs[metric]!;
      screen = AddReadingInputScreen(
        metric: metric,
        config: config,
        onSave: _saveReading,
      );
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reading saved successfully'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuickChip(IconData icon, Color color, String label, BuildContext sheetCtx, HealthMetric? metric) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigateToMetric(metric);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherRow({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  // Saves a reading submitted via the new full-screen reading flow.
  // Also marks the matching task card as completed if one exists.
  Future<void> _saveReading(HealthMetric metric, double value, DateTime when) async {
    final config = _configs[metric];

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final provider = context.read<HealthProvider>();
    final historyProvider = context.read<HealthHistoryProvider>();

    provider.updateValue(metric, value);
    final status = provider.getStatus(metric, value);

    final reading = HealthReading(
      id: '',
      metricType: metric.name,
      value: value,
      unit: config?.unit ?? '',
      status: _statusToString(status),
      timestamp: when,
    );
    final readingId = await HealthReadingService.saveReading(uid, reading);
    historyProvider.addReading(metric, value);

    // Fire critical reading notification
    final statusStr = _statusToString(status);
    if (statusStr == 'High' || statusStr == 'Low') {
      NotificationService.showCriticalReadingNotification(
        readingId: readingId,
        metricName: config?.title ?? metric.name,
        value: value,
        unit: config?.unit ?? '',
      );
    }
  }
}

