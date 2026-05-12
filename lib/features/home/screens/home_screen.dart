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
import '../../health/screens/add_reading_list_screen.dart';
import '../../doctor/services/patient_suggestion_service.dart';

// ─── Task model ──────────────────────────────────────────────────────────────

enum TaskType { medication, reading }

class DailyTask {
  final String id;
  final TaskType type;
  final String timeOfDay;
  final String displayName;
  final String? subtitle;
  final String? medicationId;
  final String? metricType;
  bool isCompleted;

  DailyTask({
    required this.id,
    required this.type,
    required this.timeOfDay,
    required this.displayName,
    this.subtitle,
    this.medicationId,
    this.metricType,
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
  bool _showMedTasks = true;
  bool _showReadingTasks = true;
  // One controller per reading task, keyed by task id
  final Map<String, TextEditingController> _readingControllers = {};
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
      title: 'Daily Steps',
      icon: Icons.directions_walk,
      unit: 'steps',
      min: 0,
      max: 100000,
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
    for (final c in _readingControllers.values) {
      c.dispose();
    }
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
    // Manual ISO date string — no intl dependency needed
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Resolve which task categories the user opted into during onboarding.
    // Default to both if prefs are missing (guest or old install).
    final services = await PreferencesService.getSelectedServices();
    final showMeds =
        services.isEmpty || services.contains('medications');
    final showReadings =
        services.isEmpty || services.contains('measurements');

    if (mounted) {
      setState(() {
        _showMedTasks = showMeds;
        _showReadingTasks = showReadings;
      });
    }

    // Step 1 — Medication tasks
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
            type: TaskType.medication,
            timeOfDay: time,
            displayName: med.name,
            subtitle: med.dosage,
            medicationId: med.id,
            isCompleted: taken,
          ));
        }
      }
    }

    // Step 2 — Reading tasks, mapped to the user's disease
    // Only added when the user opted into Measurements during onboarding.
    const metricsByDisease = <String, List<String>>{
      'diabetes': ['bloodSugar', 'weight'],
      'blood_pressure': ['systolic', 'diastolic'],
      'heart': ['heartRate', 'weight'],
    };
    const defaultTimes = <String, String>{
      'bloodSugar': '08:00',
      'systolic': '09:00',
      'diastolic': '09:30',
      'heartRate': '10:00',
      'weight': '07:00',
    };
    const displayNames = <String, String>{
      'bloodSugar': 'Log Blood Sugar',
      'systolic': 'Log Blood Pressure',
      'diastolic': 'Log Diastolic BP',
      'heartRate': 'Log Heart Rate',
      'weight': 'Log Weight',
    };

    final metrics = showReadings
        ? (metricsByDisease[_diseaseType] ?? ['heartRate', 'weight'])
        : <String>[];

    for (final metric in metrics) {
      bool loggedToday = false;
      if (uid != null) {
        try {
          // Query by metricType only to avoid needing a composite index;
          // filter by today's timestamp client-side.
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('readings')
              .where('metricType', isEqualTo: metric)
              .get();
          loggedToday = snap.docs.any((d) {
            final ts = d.data()['timestamp'];
            if (ts is Timestamp) return ts.toDate().isAfter(todayStart);
            return false;
          });
        } catch (_) {}
      }

      tasks.add(DailyTask(
        id: 'reading_$metric',
        type: TaskType.reading,
        timeOfDay: defaultTimes[metric] ?? '09:00',
        displayName: displayNames[metric] ?? 'Log $metric',
        metricType: metric,
        isCompleted: loggedToday,
      ));
    }

    // Step 3 — Incomplete tasks sorted by time first, completed at bottom
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
            color: AppColors.primary.withOpacity(0.1),
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
            color: AppColors.textDark.withOpacity(0.06),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
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
            color: AppColors.primary.withOpacity(0.25),
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
                    color: AppColors.white.withOpacity(0.7),
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
              size: 20,
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
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildTaskCard(_tasks[i]),
          ),
      ],
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    if (task.isCompleted) return _buildCompletedCard(task);
    if (task.type == TaskType.medication) return _buildPendingMedCard(task);
    return _buildPendingReadingCard(task);
  }

  Widget _buildPendingMedCard(DailyTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.06),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mark as Taken',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReadingCard(DailyTask task) {
    final metric = _metricEnumFor(task.metricType ?? '');
    final config = metric != null ? _configs[metric] : null;
    final controller = _readingControllers.putIfAbsent(
        task.id, () => TextEditingController());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.06),
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
              Icon(config?.icon ?? Icons.monitor_heart_rounded,
                  color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(task.displayName, style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter value',
              suffixText: config?.unit ?? '',
              suffixStyle: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.secondary),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _logReading(task, controller),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Log',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(DailyTask task) {
    final isMed = task.type == TaskType.medication;
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
                  Text(
                    isMed ? 'Taken' : 'Logged',
                    style: AppTextStyles.bodySmall,
                  ),
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
              'No outstanding tasks for today',
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
    }

    if (mounted) {
      setState(() {
        task.isCompleted = true;
        _sortTasks();
      });
    }
  }

  Future<void> _logReading(
      DailyTask task, TextEditingController controller) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final value = double.tryParse(text);
    if (value == null) return;

    final metric = _metricEnumFor(task.metricType ?? '');
    if (metric == null) return;

    final config = _configs[metric];

    // Validate realistic range
    if (config != null && (value < config.min || value > config.max)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Value must be between ${config.min.toInt()} and ${config.max.toInt()} ${config.unit}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final provider = context.read<HealthProvider>();
    final historyProvider = context.read<HealthHistoryProvider>();

    provider.updateValue(metric, value);
    final status = provider.getStatus(metric, value);

    // Save to Firestore via HealthReadingService (same path as provider.saveReadingToFirebase)
    final reading = HealthReading(
      id: '',
      metricType: metric.name,
      value: value,
      unit: config?.unit ?? '',
      status: _statusToString(status),
      timestamp: DateTime.now(),
    );
    await HealthReadingService.saveReading(uid, reading);

    // Keep history provider in sync for the daily summary card
    historyProvider.addReading(metric, value);

    controller.clear();
    if (mounted) {
      setState(() {
        task.isCompleted = true;
        _sortTasks();
      });
    }
  }

  HealthMetric? _metricEnumFor(String name) {
    for (final m in HealthMetric.values) {
      if (m.name == name) return m;
    }
    return null;
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
    return FloatingActionButton.extended(
      heroTag: 'fab_home',
      onPressed: _showAddSheet,
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: AppColors.white),
      label: Text("Add Today's Reading", style: AppTextStyles.buttonText),
    );
  }

  // Sheet methods use the State's own context directly — it outlives any sheet
  // or Consumer2 builder context, preventing _dependents.isEmpty assertion errors.
  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Add Today's Entry",
                  style: AppTextStyles.heading3,
                ),
              ),
              if (_showMedTasks)
                _buildSheetOption(
                  icon: Icons.medication_rounded,
                  label: 'Medications',
                  subtitle: 'Add or log a medication',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddMedicationScreen()),
                    ).then((_) => _loadMedSummary());
                  },
                ),
              if (_showReadingTasks)
                _buildSheetOption(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Measurement',
                  subtitle: 'Record a health reading',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showMeasurementSheet();
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(label,
          style: AppTextStyles.label.copyWith(fontSize: 15)),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  Future<void> _showMeasurementSheet() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReadingListScreen(
          diseaseType: _diseaseType,
          onSave: (metric, value, when) => _saveReading(metric, value, when),
        ),
      ),
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
    await HealthReadingService.saveReading(uid, reading);
    historyProvider.addReading(metric, value);

    // Mark the matching task card as done so the list stays in sync.
    // bloodSugarBefore/After also satisfy a generic 'bloodSugar' task.
    final matchNames = {
      metric.name,
      if (metric == HealthMetric.bloodSugarBefore ||
          metric == HealthMetric.bloodSugarAfter)
        'bloodSugar',
    };
    if (mounted) {
      setState(() {
        final idx = _tasks.indexWhere((t) =>
            t.type == TaskType.reading && matchNames.contains(t.metricType));
        if (idx != -1) {
          _tasks[idx].isCompleted = true;
          _sortTasks();
        }
      });
    }
  }
}

