import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/health/health_metrics.dart';
import '../../../core/services/care_services.dart';
import '../../dashboard/providers/health_provider.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../notifications/screens/suggestions_panel_screen.dart';
import '../../emergency/emergency_service.dart';
import '../../emergency/trend_warning_service.dart';
import '../../medication/services/medication_service.dart';
import '../../medication/services/dose_service.dart';
import '../../medication/services/adherence.dart';
import '../../medication/screens/add_medication_screen.dart';
import '../../health/models/health_reading.dart';
import '../../health/models/reading_entry.dart';
import '../../health/services/health_reading_service.dart';
import '../../health/screens/add_reading_input_screen.dart';
import '../../health/screens/blood_pressure_input_screen.dart';
import '../../appointments/screens/add_appointment_screen.dart';
import '../../doctor/services/patient_suggestion_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/health/conditions.dart';
import '../../disease/services/conditions_service.dart';
import '../../charts/screens/charts_screen.dart';

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

  static final refreshNotifier = ValueNotifier<int>(0);

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
  PatientConditions _conditions = PatientConditions.none;
  int _medScheduleCount = 0;
  List<DailyTask> _tasks = [];
  bool _isLoadingTasks = false;
  int _streakDays = 0;
  Map<String, double> _completionMap = {};
  Map<String, List<Map<String, dynamic>>> _adherenceByDate = {};
  final _suggestionService = PatientSuggestionService();
  StreamSubscription<QuerySnapshot>? _medsSub;

  // Services chosen in onboarding / Profile decide which sections show
  Set<String> _services = {...CareServices.all};

  bool get _medsOn => _services.contains(CareServices.medications);
  bool get _measurementsOn => _services.contains(CareServices.measurements);
  bool get _activitiesOn => _services.contains(CareServices.activities);
  bool get _appointmentsOn => _services.contains(CareServices.appointments);
  bool get _readingsOn => _measurementsOn || _activitiesOn;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadUserProfile();
    _loadMedSummary();
    _listenForMedicationChanges();
    HomeScreen.refreshNotifier.addListener(_onRefreshRequested);
    CareServices.changes.addListener(_loadServices);
    ConditionsService.changes.addListener(_loadUserProfile);
  }

  @override
  void dispose() {
    _medsSub?.cancel();
    HomeScreen.refreshNotifier.removeListener(_onRefreshRequested);
    CareServices.changes.removeListener(_loadServices);
    ConditionsService.changes.removeListener(_loadUserProfile);
    super.dispose();
  }

  Future<void> _loadServices() async {
    final services = await CareServices.load();
    if (mounted) setState(() => _services = services);
  }

  void _listenForMedicationChanges() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _medsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      try {
        final remoteMeds = snapshot.docs
            .map((d) => MedicationService.fromFirestoreDoc(d.data()))
            .toList();
        final localMeds = await MedicationService.loadAll();
        final remoteIds = remoteMeds.map((m) => m.id).toSet();
        final localOnly =
            localMeds.where((m) => !remoteIds.contains(m.id)).toList();
        await MedicationService.saveAll([...remoteMeds, ...localOnly]);
        _loadMedSummary();
        _loadTasks();
      } catch (e) {
        debugPrint('HomeScreen med stream: $e');
      }
    });
  }

  void _onRefreshRequested() {
    _loadMedSummary();
    _loadTasks();
  }

  Future<void> _loadUserProfile() async {
    final savedFirstName = await PreferencesService.getFirstName();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Show UI immediately with local data
    if (mounted) {
      setState(() {
        _userName = savedFirstName ?? '';
        _isLoading = false;
      });
    }

    if (uid == null) {
      _loadTasks();
      return;
    }

    // Fetch Firestore profile in the background and update when ready
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          final firestoreName = profile?['name'] as String? ?? '';
          _userName =
              firestoreName.isNotEmpty ? firestoreName : (savedFirstName ?? '');
          _conditions = PatientConditions.fromProfile(profile);
        });
      }
      if (mounted) {
        context.read<HealthProvider>().loadReadingsFromFirebase(uid);
        context.read<HealthHistoryProvider>().watch(uid);
        TrendWarningService.checkBPTrend(context, uid);
      }
    } catch (_) {
      // Already showing UI with local name — nothing to update
    }

    _loadTasks();
  }

  Future<void> _loadMedSummary() async {
    final meds = await MedicationService.loadAll();
    final today = DateTime.now();
    var count = 0;
    for (final med in meds) {
      if (!isScheduledOn(med, today)) continue;
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

    // Always show medication tasks if the user has active medications
    if (uid != null) {
      final meds = await MedicationService.loadAll();
      final prefs = await SharedPreferences.getInstance();
      for (final med in meds) {
        // Same schedule rules as the adherence figures (weekly and
        // "As needed" medications don't get a task every day)
        if (!isScheduledOn(med, todayStart)) continue;
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
      _loadStreakData();
    }
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.timeOfDay.compareTo(b.timeOfDay);
    });
  }

  String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadStreakData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = DateTime(today.year, today.month, today.day - 60);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('adherence')
          .where('date', isGreaterThanOrEqualTo: _dateStr(from))
          .get();

      final Map<String, List<Map<String, dynamic>>> byDate = {};
      final takenDoses = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        if (date == null) continue;
        byDate.putIfAbsent(date, () => []);
        byDate[date]!.add(data);
        if (data['taken'] == true) takenDoses.add(doc.id);
      }
      // Today's taps may not have reached Firestore yet
      for (final t in _tasks) {
        if (t.isCompleted && t.medicationId != null) {
          takenDoses.add(doseKey(today, t.medicationId!, t.timeOfDay));
        }
      }

      final meds = await MedicationService.loadAll();
      final report = calculateAdherence(
        medications: meds,
        takenDoses: takenDoses,
        from: from,
        to: today,
        now: now,
      );

      // Share of each day's scheduled doses that were taken
      final Map<String, double> cMap = {};
      for (final entry in report.byDay.entries) {
        final c = entry.value;
        if (!c.hasSchedule) continue;
        cMap[_dateStr(entry.key)] = c.taken / (c.expected + c.pending);
      }

      final todayStr = _dateStr(today);
      if (_tasks.isNotEmpty) {
        final completed = _tasks.where((t) => t.isCompleted).length;
        cMap[todayStr] = completed / _tasks.length;
      }

      int streak = 0;
      if (_tasks.isNotEmpty && _tasks.every((t) => t.isCompleted)) streak = 1;

      for (int i = 1; i <= 60; i++) {
        final dayStr =
            _dateStr(DateTime(today.year, today.month, today.day - i));
        if (cMap.containsKey(dayStr) && cMap[dayStr]! >= 1.0) {
          streak++;
        } else {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _streakDays = streak;
          _completionMap = cMap;
          _adherenceByDate = byDate;
        });
      }
    } catch (e) {
      debugPrint('HomeScreen: loadAdherence failed: $e');
    }
  }

  void _updateTodayStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _dateStr(today);

    if (_tasks.isNotEmpty) {
      final completed = _tasks.where((t) => t.isCompleted).length;
      _completionMap[todayStr] = completed / _tasks.length;
    }

    int streak = 0;
    if (_tasks.isNotEmpty && _tasks.every((t) => t.isCompleted)) streak = 1;

    for (int i = 1; i <= 60; i++) {
      final dayStr = _dateStr(DateTime(today.year, today.month, today.day - i));
      if (_completionMap.containsKey(dayStr) && _completionMap[dayStr]! >= 1.0) {
        streak++;
      } else {
        break;
      }
    }

    setState(() => _streakDays = streak);
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
                    if (_medsOn || _readingsOn) ...[
                      _buildDailySummaryCard(historyProvider),
                      const SizedBox(height: 16),
                    ],
                    // Streak and dose tasks belong to the Medications service
                    if (_medsOn) ...[
                      _buildSummaryBanner(),
                      const SizedBox(height: 20),
                      _buildTaskList(),
                    ],
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
        // SOS normally sits on the streak banner; without the Medications
        // service that banner is hidden, so it moves up here
        if (!_medsOn) ...[
          GestureDetector(
            onTap: () => EmergencyService.showEmergencyFlow(context),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.warning_rounded,
                  color: Colors.red, size: 26),
            ),
          ),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SuggestionsPanelScreen(
                diseaseType: _conditions.legacyDiseaseType,
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
          Row(
            children: [
              Text(
                "Today's Summary",
                style: AppTextStyles.label.copyWith(
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (_measurementsOn)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChartsScreen()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.show_chart_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'View trends',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final item in [
                if (_readingsOn)
                  _buildSummaryItem(
                    Icons.monitor_heart_rounded,
                    '$todayCount',
                    'readings today',
                    AppColors.success,
                  ),
                if (_medsOn)
                  _buildSummaryItem(
                    Icons.medication_rounded,
                    '$_medScheduleCount',
                    'meds scheduled',
                    const Color(0xFF1565C0),
                  ),
                if (_readingsOn)
                  _buildSummaryItem(
                    Icons.access_time_rounded,
                    lastText,
                    'last reading',
                    AppColors.secondary,
                  ),
              ].indexed) ...[
                if (item.$1 > 0) const SizedBox(width: 8),
                item.$2,
              ],
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
      final status = provider.getStatus(m, value, context: provider.getContext(m));
      if (status == MetricStatus.warning ||
          status == MetricStatus.criticalLow ||
          status == MetricStatus.criticalHigh) {
        return true;
      }
    }
    return false;
  }

  // ── Streak widget ─────────────────────────────────────────────────────

  Widget _buildSummaryBanner() {
    final completed = _tasks.where((t) => t.isCompleted).length;
    final total = _tasks.length;
    final progress = total > 0 ? completed / total : 0.0;
    final allDone = total > 0 && completed == total;

    return GestureDetector(
      onTap: _showStreakCalendar,
      child: Container(
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
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: _streakDays > 0
                      ? const Color(0xFFFF9800)
                      : AppColors.white.withValues(alpha: 0.4),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Task Streak",
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _streakDays > 0
                            ? '$_streakDays day${_streakDays == 1 ? '' : 's'} streak'
                            : 'Start your streak!',
                        style: AppTextStyles.heading3
                            .copyWith(color: AppColors.white),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completed/$total',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  allDone
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF74B3CE),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Streak calendar sheet ───────────────────────────────────────────────

  void _showStreakCalendar() {
    final now = DateTime.now();
    var displayMonth = DateTime(now.year, now.month);
    String selectedDate = _dateStr(now);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final year = displayMonth.year;
            final month = displayMonth.month;
            final daysInMonth = DateTime(year, month + 1, 0).day;
            final firstWeekday = DateTime(year, month, 1).weekday;
            final isCurrentMonth = year == now.year && month == now.month;

            const monthNames = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December',
            ];

            final isToday = selectedDate == _dateStr(now);
            final List<Widget> taskWidgets = [];
            if (isToday) {
              for (final task in _tasks) {
                taskWidgets.add(_buildCalendarTaskRow(
                  name: task.displayName,
                  time: task.timeOfDay,
                  dosage: task.subtitle ?? '',
                  taken: task.isCompleted,
                ));
              }
            } else if (_adherenceByDate.containsKey(selectedDate)) {
              for (final rec in _adherenceByDate[selectedDate]!) {
                taskWidgets.add(_buildCalendarTaskRow(
                  name: rec['medicationName'] as String? ?? 'Medication',
                  time: rec['timeSlot'] as String? ?? '',
                  dosage: rec['dosage'] as String? ?? '',
                  taken: rec['taken'] as bool? ?? false,
                ));
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      Text(
                        'Task Completion Calendar',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              setSheetState(() {
                                displayMonth = DateTime(year, month - 1);
                              });
                            },
                            icon: const Icon(Icons.chevron_left_rounded,
                                color: AppColors.primary),
                          ),
                          Text(
                            '${monthNames[month - 1]} $year',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: isCurrentMonth
                                ? null
                                : () {
                                    setSheetState(() {
                                      displayMonth =
                                          DateTime(year, month + 1);
                                    });
                                  },
                            icon: Icon(Icons.chevron_right_rounded,
                                color: isCurrentMonth
                                    ? AppColors.divider
                                    : AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                            .map((d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: daysInMonth + firstWeekday - 1,
                        itemBuilder: (_, index) {
                          if (index < firstWeekday - 1) {
                            return const SizedBox();
                          }
                          final day = index - firstWeekday + 2;
                          final dateStr =
                              _dateStr(DateTime(year, month, day));
                          final completion = _completionMap[dateStr];
                          final isSelectedDay = dateStr == selectedDate;
                          final isTodayCell = dateStr == _dateStr(now);
                          final isFuture =
                              DateTime(year, month, day).isAfter(now);

                          Color? dotColor;
                          if (!isFuture && completion != null) {
                            if (completion >= 1.0) {
                              dotColor = const Color(0xFF4CAF50);
                            } else if (completion > 0) {
                              dotColor = const Color(0xFFFF9800);
                            }
                          }

                          return GestureDetector(
                            onTap: isFuture
                                ? null
                                : () {
                                    setSheetState(() {
                                      selectedDate = dateStr;
                                    });
                                  },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelectedDay
                                        ? AppColors.primary
                                        : isTodayCell
                                            ? AppColors.primary
                                                .withValues(alpha: 0.1)
                                            : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          isTodayCell || isSelectedDay
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                      color: isSelectedDay
                                          ? AppColors.white
                                          : isFuture
                                              ? AppColors.secondary
                                                  .withValues(alpha: 0.4)
                                              : AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        dotColor ?? Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendDot(
                              const Color(0xFF4CAF50), 'All done'),
                          const SizedBox(width: 20),
                          _buildLegendDot(
                              const Color(0xFFFF9800), 'Partial'),
                          const SizedBox(width: 20),
                          _buildLegendDot(AppColors.divider, 'No tasks'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: _streakDays > 0
                                  ? const Color(0xFFFF9800)
                                  : AppColors.secondary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _streakDays > 0
                                        ? '$_streakDays day${_streakDays == 1 ? '' : 's'} streak'
                                        : 'No streak yet',
                                    style: AppTextStyles.heading3,
                                  ),
                                  Text(
                                    _streakDays > 0
                                        ? 'Keep going! Consistency is key.'
                                        : 'Complete all tasks to start!',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (taskWidgets.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              isToday ? "Today's Tasks" : 'Tasks',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              selectedDate,
                              style: AppTextStyles.bodySmall
                                  .copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...taskWidgets,
                      ] else ...[
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No tasks recorded for this date',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCalendarTaskRow({
    required String name,
    required String time,
    required String dosage,
    required bool taken,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              taken
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: taken ? const Color(0xFF4CAF50) : AppColors.secondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.label.copyWith(fontSize: 14)),
                  if (dosage.isNotEmpty)
                    Text(dosage,
                        style:
                            AppTextStyles.bodySmall.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Text(time, style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }

  // ── Task list ─────────────────────────────────────────────────────────────

  Widget _buildTaskList() {
    if (_isLoadingTasks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Only show pending tasks — completed ones disappear
    final pending = _tasks.where((t) => !t.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Today's Tasks", style: AppTextStyles.heading3),
            const Spacer(),
            Text(
              '${pending.length} task${pending.length == 1 ? '' : 's'} remaining',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.secondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          _buildAllDoneState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pending.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildPendingMedCard(pending[i]),
          ),
      ],
    );
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

  Widget _buildAllDoneState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events,
              size: 64,
              color: Color(0xFFFFD700),
            ),
            const SizedBox(height: 16),
            Text('All caught up!', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'No outstanding tasks for today. Great job!',
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
    final medId = task.medicationId;
    if (medId == null) return;
    final day = DateTime.now();

    await DoseService.markTaken(
      medicationId: medId,
      timeSlot: task.timeOfDay,
      day: day,
    );

    if (mounted) {
      setState(() {
        task.isCompleted = true;
        _sortTasks();
      });
      _updateTodayStreak();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${task.displayName} marked as taken'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await DoseService.undo(
                medicationId: medId,
                timeSlot: task.timeOfDay,
                day: day,
              );
              if (mounted) {
                setState(() {
                  task.isCompleted = false;
                  _sortTasks();
                });
                _updateTodayStreak();
              }
            },
          ),
        ),
      );
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
        final quickChips = _quickMeasurementChips(sheetCtx);
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
                if (quickChips.isNotEmpty) ...[
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
                    children: quickChips,
                  ),
                ],
                if (quickChips.isNotEmpty && (_medsOn || _appointmentsOn)) ...[
                  const SizedBox(height: 20),
                  Divider(height: 1, color: AppColors.divider),
                ],
                if (_medsOn || _appointmentsOn) ...[
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
                ],
                if (_medsOn)
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
                    ).then((_) {
                      _loadMedSummary();
                      _loadTasks();
                    });
                  },
                ),
                if (_medsOn && _appointmentsOn) const SizedBox(height: 8),
                if (_appointmentsOn)
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

  // Measurements offer the vital signs, Activities offers walking. The
  // patient's conditions decide the order, so e.g. Sugar leads for diabetes.
  List<Widget> _quickMeasurementChips(BuildContext sheetCtx) {
    final chips = <Widget>[];
    for (final metric in _conditions.metricOrder) {
      final walking = metric == HealthMetric.walkingMinutes;
      if (walking ? !_activitiesOn : !_measurementsOn) continue;
      switch (metric) {
        case HealthMetric.bloodSugar:
          chips.add(_buildQuickChip(Icons.water_drop_rounded, const Color(0xFF1976D2), 'Sugar', sheetCtx, HealthMetric.bloodSugar));
        case HealthMetric.systolic:
          // Systolic stands for the blood pressure screen
          chips.add(_buildQuickChip(Icons.favorite_rounded, const Color(0xFFD32F2F), 'BP', sheetCtx, null));
        case HealthMetric.diastolic:
          break;
        case HealthMetric.heartRate:
          chips.add(_buildQuickChip(Icons.monitor_heart_rounded, const Color(0xFFE64A19), 'Heart', sheetCtx, HealthMetric.heartRate));
        case HealthMetric.weight:
          chips.add(_buildQuickChip(Icons.scale_rounded, const Color(0xFF388E3C), 'Weight', sheetCtx, HealthMetric.weight));
        case HealthMetric.walkingMinutes:
          chips.add(_buildQuickChip(Icons.directions_walk_rounded, const Color(0xFF7B1FA2), 'Walking', sheetCtx, HealthMetric.walkingMinutes));
        case HealthMetric.temperature:
          chips.add(_buildQuickChip(Icons.thermostat_rounded, const Color(0xFF0097A7), 'Temp', sheetCtx, HealthMetric.temperature));
      }
    }
    return chips;
  }

  void _navigateToMetric(HealthMetric? metric) async {
    Widget screen;
    if (metric == null) {
      screen = BloodPressureInputScreen(onSave: _saveReadings);
    } else {
      screen = AddReadingInputScreen(
        metric: metric,
        onSave: _saveReadings,
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

  // Saves the readings submitted from a reading screen. They share one time
  // and are written together, then added to the session state with their
  // real Firestore IDs.
  Future<void> _saveReadings(List<ReadingEntry> entries, DateTime when) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const ReadingSaveException(
          'You need an account to save readings. Please sign in or register.');
    }
    if (when.isAfter(DateTime.now())) {
      throw const ReadingSaveException("The reading time can't be in the future.");
    }

    final provider = context.read<HealthProvider>();

    final drafts = entries.map((e) {
      final status = HealthMetrics.evaluate(e.metric, e.value, context: e.context);
      return HealthReading(
        id: '',
        metricType: e.metric.name,
        value: e.value,
        unit: HealthMetrics.of(e.metric).unit,
        status: HealthMetrics.statusLabel(status),
        timestamp: when,
        note: e.note,
        context: e.context,
      );
    }).toList();

    final saved = await HealthReadingService.saveReadings(uid, drafts);

    // History picks the new readings up from its live query, with their
    // Firestore IDs and the time the user chose
    for (final reading in saved) {
      provider.recordReading(reading);

      if (reading.status == 'High' || reading.status == 'Low') {
        NotificationService.showCriticalReadingNotification(
          readingId: reading.id,
          metricName: reading.label,
          value: reading.value,
          unit: reading.unit,
        );
      }
    }
  }
}

