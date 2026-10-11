import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/health/health_metrics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../charts/screens/charts_screen.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';
import '../../home/screens/main_shell.dart';
import '../../../shared/widgets/nuvita_time_picker.dart';

class _FilterOption {
  final String label;
  final Set<HealthMetric>? metrics;
  const _FilterOption(this.label, this.metrics);
}

const _filterOptions = [
  _FilterOption('Blood Sugar', {HealthMetric.bloodSugar}),
  _FilterOption('Blood Pressure', {HealthMetric.systolic, HealthMetric.diastolic}),
  _FilterOption('Heart Rate', {HealthMetric.heartRate}),
  _FilterOption('Weight', {HealthMetric.weight}),
  _FilterOption('Steps', {HealthMetric.steps}),
];

class _DisplayItem {
  final HealthReading primary;
  final HealthReading? paired;

  const _DisplayItem(this.primary, [this.paired]);

  bool get isBloodPressurePair => paired != null;
  HealthReading get systolic =>
      primary.metricType == 'systolic' ? primary : paired!;
  HealthReading get diastolic =>
      primary.metricType == 'diastolic' ? primary : paired!;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<int> _activeFilters = {};
  bool _showHint = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        context.read<HealthHistoryProvider>().loadReadings(uid);
      }
    });
    _checkHint();
  }

  Future<void> _checkHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('history_hint_shown') != true) {
      if (mounted) setState(() => _showHint = true);
      await prefs.setBool('history_hint_shown', true);
    }
  }

  // Build the combined metric set from active filters
  Set<HealthMetric>? get _combinedMetrics {
    if (_activeFilters.isEmpty) return null;
    final combined = <HealthMetric>{};
    for (final i in _activeFilters) {
      combined.addAll(_filterOptions[i].metrics!);
    }
    return combined;
  }

  // ── Display helpers ──

  String _metricUnit(String metricType) => HealthMetrics.unitForKey(metricType);

  IconData _metricIcon(String metricType) {
    switch (metricType) {
      case 'bloodSugar':
        return Icons.water_drop_rounded;
      case 'systolic':
      case 'diastolic':
        return Icons.favorite_rounded;
      case 'heartRate':
        return Icons.monitor_heart_rounded;
      case 'weight':
        return Icons.scale_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  Color _metricColor(String metricType) {
    switch (metricType) {
      case 'bloodSugar':
        return const Color(0xFF1976D2);
      case 'systolic':
      case 'diastolic':
        return const Color(0xFFD32F2F);
      case 'heartRate':
        return const Color(0xFFE64A19);
      case 'weight':
        return const Color(0xFF388E3C);
      case 'steps':
        return const Color(0xFF7B1FA2);
      default:
        return AppColors.secondary;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Normal':
        return AppColors.success;
      case 'Warning':
        return AppColors.warning;
      case 'Low':
      case 'High':
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatLastEntry(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(dt.year, dt.month, dt.day);
    final time = _formatTime(dt);

    if (entryDay == today) return time;
    if (entryDay == today.subtract(const Duration(days: 1))) {
      return 'Yest $time';
    }
    return '${_monthName(dt.month)} ${dt.day}';
  }

  Map<String, List<HealthReading>> _groupByDate(List<HealthReading> readings) {
    final map = <String, List<HealthReading>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final r in readings) {
      final day =
          DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      String key;
      if (day == today) {
        key = 'Today';
      } else if (day == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${_monthName(day.month)} ${day.day}, ${day.year}';
      }
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  Map<String, List<_DisplayItem>> _groupAndMerge(List<HealthReading> readings) {
    final grouped = _groupByDate(readings);
    return grouped
        .map((key, list) => MapEntry(key, _mergeReadingsInGroup(list)));
  }

  List<_DisplayItem> _mergeReadingsInGroup(List<HealthReading> readings) {
    final items = <_DisplayItem>[];
    final used = List.filled(readings.length, false);

    for (int i = 0; i < readings.length; i++) {
      if (used[i]) continue;
      used[i] = true;

      final r = readings[i];
      if (r.metricType == 'systolic' || r.metricType == 'diastolic') {
        final targetType =
            r.metricType == 'systolic' ? 'diastolic' : 'systolic';
        int matchIdx = -1;
        for (int j = i + 1; j < readings.length; j++) {
          if (!used[j] &&
              readings[j].metricType == targetType &&
              _sameMinute(readings[j].timestamp, r.timestamp)) {
            matchIdx = j;
            break;
          }
        }

        if (matchIdx != -1) {
          used[matchIdx] = true;
          final sys =
              r.metricType == 'systolic' ? r : readings[matchIdx];
          final dia =
              r.metricType == 'diastolic' ? r : readings[matchIdx];
          items.add(_DisplayItem(sys, dia));
        } else {
          items.add(_DisplayItem(r));
        }
      } else {
        items.add(_DisplayItem(r));
      }
    }

    return items;
  }

  bool _sameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  String _worseBPStatus(String s1, String s2) {
    const severity = {
      'Normal': 0,
      'Logged': 0,
      'Warning': 1,
      'Low': 2,
      'High': 2,
    };
    return (severity[s1] ?? 0) >= (severity[s2] ?? 0) ? s1 : s2;
  }

  // ── Delete ──

  void _deleteReading(HealthReading reading) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final provider = context.read<HealthHistoryProvider>();

    provider.removeReading(reading);

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('Reading deleted'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () => provider.restoreReading(reading),
            ),
          ),
        )
        .closed
        .then((reason) {
      if (reason != SnackBarClosedReason.action &&
          uid != null &&
          reading.id.isNotEmpty) {
        HealthReadingService.deleteReading(uid, reading.id);
      }
    });
  }

  void _deleteBPReading(HealthReading systolic, HealthReading diastolic) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final provider = context.read<HealthHistoryProvider>();

    provider.removeReading(systolic);
    provider.removeReading(diastolic);

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('Blood pressure reading deleted'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                provider.restoreReading(systolic);
                provider.restoreReading(diastolic);
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (reason != SnackBarClosedReason.action && uid != null) {
        if (systolic.id.isNotEmpty) {
          HealthReadingService.deleteReading(uid, systolic.id);
        }
        if (diastolic.id.isNotEmpty) {
          HealthReadingService.deleteReading(uid, diastolic.id);
        }
      }
    });
  }

  // ── Edit ──

  Future<void> _showEditSheet(HealthReading reading) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditReadingSheet(
        reading: reading,
        metricLabel: reading.label,
        unit: _metricUnit(reading.metricType),
        validRange: _validRange(reading.metricType),
      ),
    );

    if (result != null && mounted) {
      _saveEdit(
        reading,
        result['value'] as double,
        result['timestamp'] as DateTime,
      );
    }
  }

  Future<void> _saveEdit(
      HealthReading reading, double newValue, DateTime newTimestamp) async {
    final newStatus = _statusForValue(reading, newValue);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final provider = context.read<HealthHistoryProvider>();

    final timestampChanged = reading.timestamp != newTimestamp;
    provider.patchReading(reading, newValue, newStatus,
        newTimestamp: timestampChanged ? newTimestamp : null);

    if (uid != null && reading.id.isNotEmpty) {
      try {
        await HealthReadingService.updateReading(
          uid,
          reading.id,
          newValue,
          newStatus,
          timestamp: timestampChanged ? newTimestamp : null,
        );
      } catch (e) {
        debugPrint('HistoryScreen._saveEdit: $e');
      }
    }
  }

  Future<void> _showEditBPSheet(_DisplayItem item) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditBPSheet(
        systolic: item.systolic,
        diastolic: item.diastolic,
      ),
    );

    if (result != null && mounted) {
      _saveBPEdit(
        item,
        result['systolicValue'] as double,
        result['diastolicValue'] as double,
        result['timestamp'] as DateTime,
      );
    }
  }

  Future<void> _saveBPEdit(_DisplayItem item, double sysValue,
      double diaValue, DateTime newTimestamp) async {
    final sysStatus = _statusForValue(item.systolic, sysValue);
    final diaStatus = _statusForValue(item.diastolic, diaValue);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final provider = context.read<HealthHistoryProvider>();

    final timestampChanged = item.systolic.timestamp != newTimestamp;
    provider.patchReading(item.systolic, sysValue, sysStatus,
        newTimestamp: timestampChanged ? newTimestamp : null);
    provider.patchReading(item.diastolic, diaValue, diaStatus,
        newTimestamp: timestampChanged ? newTimestamp : null);

    if (uid != null) {
      try {
        final futures = <Future>[];
        if (item.systolic.id.isNotEmpty) {
          futures.add(HealthReadingService.updateReading(
            uid, item.systolic.id, sysValue, sysStatus,
            timestamp: timestampChanged ? newTimestamp : null,
          ));
        }
        if (item.diastolic.id.isNotEmpty) {
          futures.add(HealthReadingService.updateReading(
            uid, item.diastolic.id, diaValue, diaStatus,
            timestamp: timestampChanged ? newTimestamp : null,
          ));
        }
        await Future.wait(futures);
      } catch (e) {
        debugPrint('HistoryScreen._saveBPEdit: $e');
      }
    }
  }

  String _statusForValue(HealthReading reading, double value) {
    final metric = reading.metric;
    if (metric == null) return 'Logged';
    return HealthMetrics.statusLabel(
        HealthMetrics.evaluate(metric, value, context: reading.context));
  }

  List<double> _validRange(String metricType) {
    final metric = HealthMetrics.metricForKey(metricType);
    if (metric == null) return [0, 99999];
    final def = HealthMetrics.of(metric);
    return [def.min, def.max];
  }

  // ── Pull to refresh ──

  Future<void> _onRefresh() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await context.read<HealthHistoryProvider>().forceReload(uid);
  }

  // ── Load more ──

  Future<void> _onLoadMore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingMore = true);
    await context.read<HealthHistoryProvider>().loadMore(uid);
    if (mounted) setState(() => _loadingMore = false);
  }

  // ── Chart filter pass ──

  void _openCharts() {
    String? preselected;
    if (_activeFilters.length == 1) {
      final label = _filterOptions[_activeFilters.first].label;
      switch (label) {
        case 'Blood Sugar':
          preselected = 'bloodSugar';
          break;
        case 'Blood Pressure':
          preselected = 'systolic';
          break;
        case 'Heart Rate':
          preselected = 'heartRate';
          break;
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ChartsScreen(preselectedMetric: preselected)),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'My Health History',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded, color: AppColors.white),
            tooltip: 'View Trends',
            onPressed: _openCharts,
          ),
        ],
      ),
      body: Consumer<HealthHistoryProvider>(
        builder: (context, provider, _) {
          final filtered = provider.filteredReadings(_combinedMetrics);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final isLoading = uid != null && !provider.isLoaded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              if (provider.allReadings.isNotEmpty)
                _buildSummaryCard(filtered),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _onRefresh,
                        child: filtered.isEmpty
                            ? _buildEmptyState()
                            : _buildReadingsList(filtered, provider),
                      ),
              ),
              if (_showHint)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Text(
                      '\u{1F4A1} Tip: Swipe left to delete, long press to edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasActive = _activeFilters.isNotEmpty;

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filterOptions.length + (hasActive ? 1 : 0),
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          // "Clear" chip at end
          if (hasActive && i == _filterOptions.length) {
            return GestureDetector(
              onTap: () => setState(() => _activeFilters.clear()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close_rounded,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final selected = _activeFilters.contains(i);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _activeFilters.remove(i);
                } else {
                  _activeFilters.add(i);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _filterOptions[i].label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.white : AppColors.textDark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(List<HealthReading> filtered) {
    final now = DateTime.now();
    final todayCount = filtered
        .where((r) =>
            r.timestamp.year == now.year &&
            r.timestamp.month == now.month &&
            r.timestamp.day == now.day)
        .length;
    final lastTime =
        filtered.isNotEmpty ? filtered.first.timestamp : null;
    final timeStr = lastTime != null ? _formatLastEntry(lastTime, now) : '--';

    final title = _activeFilters.isEmpty
        ? 'Today\'s Readings'
        : _activeFilters.length == 1
            ? '${_filterOptions[_activeFilters.first].label} Today'
            : 'Filtered Readings Today';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$todayCount ${todayCount == 1 ? 'reading' : 'readings'} logged',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Last entry',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No readings yet',
                    style:
                        AppTextStyles.heading3.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your health readings will appear here\nonce you start logging them from\nthe home screen',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingsList(
      List<HealthReading> readings, HealthHistoryProvider provider) {
    final grouped = _groupAndMerge(readings);
    final itemCount =
        _countItems(grouped) + (provider.hasMore ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final dataCount = _countItems(grouped);

        // "Load older readings" button
        if (index == dataCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _onLoadMore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Load older readings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        }

        return _buildItemAtIndex(grouped, index);
      },
    );
  }

  int _countItems(Map<String, List<_DisplayItem>> grouped) {
    int count = 0;
    for (final group in grouped.values) {
      count += 1 + group.length;
    }
    return count;
  }

  Widget _buildItemAtIndex(
      Map<String, List<_DisplayItem>> grouped, int index) {
    int cursor = 0;
    for (final entry in grouped.entries) {
      if (index == cursor) return _buildDateHeader(entry.key);
      cursor++;
      final groupItems = entry.value;
      if (index < cursor + groupItems.length) {
        final item = groupItems[index - cursor];
        if (item.isBloodPressurePair) {
          return _buildBPTile(item);
        }
        return _buildReadingTile(item.primary);
      }
      cursor += groupItems.length;
    }
    return const SizedBox.shrink();
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildReadingTile(HealthReading reading) {
    final color = _metricColor(reading.metricType);
    final statusColor = _statusColor(reading.status);

    return Dismissible(
      key: ValueKey(
        reading.id.isNotEmpty
            ? reading.id
            : '${reading.metricType}_${reading.timestamp.millisecondsSinceEpoch}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteReading(reading),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            const Icon(IconlyBold.delete, color: Colors.white, size: 26),
      ),
      child: GestureDetector(
        onLongPress: () => _showEditSheet(reading),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_metricIcon(reading.metricType),
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        reading.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: reading.value % 1 == 0
                              ? reading.value.toInt().toString()
                              : reading.value.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_metricUnit(reading.metricType)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(reading.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBPTile(_DisplayItem item) {
    final sys = item.systolic;
    final dia = item.diastolic;
    const color = Color(0xFFD32F2F);
    final status = _worseBPStatus(sys.status, dia.status);
    final statusColor = _statusColor(status);

    final sysStr = sys.value % 1 == 0
        ? sys.value.toInt().toString()
        : sys.value.toStringAsFixed(1);
    final diaStr = dia.value % 1 == 0
        ? dia.value.toInt().toString()
        : dia.value.toStringAsFixed(1);

    return Dismissible(
      key: ValueKey(
        'bp_${sys.id}_${dia.id}_${sys.timestamp.millisecondsSinceEpoch}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteBPReading(sys, dia),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            const Icon(IconlyBold.delete, color: Colors.white, size: 26),
      ),
      child: GestureDetector(
        onLongPress: () => _showEditBPSheet(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blood Pressure',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$sysStr/$diaStr',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const TextSpan(
                          text: ' mmHg',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(sys.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit reading sheet ──

class _EditReadingSheet extends StatefulWidget {
  final HealthReading reading;
  final String metricLabel;
  final String unit;
  final List<double> validRange;

  const _EditReadingSheet({
    required this.reading,
    required this.metricLabel,
    required this.unit,
    required this.validRange,
  });

  @override
  State<_EditReadingSheet> createState() => _EditReadingSheetState();
}

class _EditReadingSheetState extends State<_EditReadingSheet> {
  late final TextEditingController _controller;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final v = widget.reading.value;
    _controller = TextEditingController(
      text: v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1),
    );
    _selectedDate = DateTime(
      widget.reading.timestamp.year,
      widget.reading.timestamp.month,
      widget.reading.timestamp.day,
    );
    _selectedTime = TimeOfDay(
      hour: widget.reading.timestamp.hour,
      minute: widget.reading.timestamp.minute,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showNuvitaTimePicker(
      context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDateDisplay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (dt == today) return 'Today';
    if (dt == yesterday) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTimeDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.reading.value;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Edit ${widget.metricLabel}',
                style: AppTextStyles.heading3,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.secondary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current: ${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)} ${widget.unit}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: InputDecoration(
              labelText: 'New value',
              labelStyle: const TextStyle(color: AppColors.secondary),
              suffixText: widget.unit,
              suffixStyle:
                  const TextStyle(color: AppColors.secondary, fontSize: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          _buildDateTimeRow(
            label: 'Date',
            value: _formatDateDisplay(_selectedDate),
            icon: Icons.calendar_today_rounded,
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          _buildDateTimeRow(
            label: 'Time',
            value: _formatTimeDisplay(_selectedTime),
            icon: Icons.access_time_rounded,
            onTap: _pickTime,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  void _onSave() {
    final raw = double.tryParse(_controller.text.trim());
    final range = widget.validRange;
    if (raw == null || raw < range[0] || raw > range[1]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a value between ${range[0].toInt()} and ${range[1].toInt()} ${widget.unit}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    Navigator.pop(context, {
      'value': raw,
      'timestamp': combined,
    });
  }
}

// ── Edit blood pressure sheet ──

class _EditBPSheet extends StatefulWidget {
  final HealthReading systolic;
  final HealthReading diastolic;

  const _EditBPSheet({
    required this.systolic,
    required this.diastolic,
  });

  @override
  State<_EditBPSheet> createState() => _EditBPSheetState();
}

class _EditBPSheetState extends State<_EditBPSheet> {
  late final TextEditingController _sysController;
  late final TextEditingController _diaController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final sv = widget.systolic.value;
    final dv = widget.diastolic.value;
    _sysController = TextEditingController(
      text: sv % 1 == 0 ? sv.toInt().toString() : sv.toStringAsFixed(1),
    );
    _diaController = TextEditingController(
      text: dv % 1 == 0 ? dv.toInt().toString() : dv.toStringAsFixed(1),
    );
    _selectedDate = DateTime(
      widget.systolic.timestamp.year,
      widget.systolic.timestamp.month,
      widget.systolic.timestamp.day,
    );
    _selectedTime = TimeOfDay(
      hour: widget.systolic.timestamp.hour,
      minute: widget.systolic.timestamp.minute,
    );
  }

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showNuvitaTimePicker(
      context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatDateDisplay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (dt == today) return 'Today';
    if (dt == yesterday) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTimeDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final sv = widget.systolic.value;
    final dv = widget.diastolic.value;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Edit Blood Pressure', style: AppTextStyles.heading3),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.secondary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current: ${sv % 1 == 0 ? sv.toInt() : sv.toStringAsFixed(1)}/${dv % 1 == 0 ? dv.toInt() : dv.toStringAsFixed(1)} mmHg',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sysController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.textDark),
                  decoration: InputDecoration(
                    labelText: 'Systolic',
                    labelStyle:
                        const TextStyle(color: AppColors.secondary),
                    suffixText: 'mmHg',
                    suffixStyle: const TextStyle(
                        color: AppColors.secondary, fontSize: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _diaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.textDark),
                  decoration: InputDecoration(
                    labelText: 'Diastolic',
                    labelStyle:
                        const TextStyle(color: AppColors.secondary),
                    suffixText: 'mmHg',
                    suffixStyle: const TextStyle(
                        color: AppColors.secondary, fontSize: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateTimeRow(
            label: 'Date',
            value: _formatDateDisplay(_selectedDate),
            icon: Icons.calendar_today_rounded,
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          _buildDateTimeRow(
            label: 'Time',
            value: _formatTimeDisplay(_selectedTime),
            icon: Icons.access_time_rounded,
            onTap: _pickTime,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  void _onSave() {
    final rawSys = double.tryParse(_sysController.text.trim());
    final rawDia = double.tryParse(_diaController.text.trim());
    final sysDef = HealthMetrics.of(HealthMetric.systolic);
    final diaDef = HealthMetrics.of(HealthMetric.diastolic);

    if (rawSys == null || !sysDef.isInRange(rawSys)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Enter systolic between ${sysDef.min.toInt()} and ${sysDef.max.toInt()} mmHg'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (rawDia == null || !diaDef.isInRange(rawDia)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Enter diastolic between ${diaDef.min.toInt()} and ${diaDef.max.toInt()} mmHg'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    Navigator.pop(context, {
      'systolicValue': rawSys,
      'diastolicValue': rawDia,
      'timestamp': combined,
    });
  }
}
