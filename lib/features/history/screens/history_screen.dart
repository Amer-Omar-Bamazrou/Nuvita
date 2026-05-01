import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../charts/screens/charts_screen.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../dashboard/providers/health_provider.dart';
import '../../health/models/health_reading.dart';
import '../../home/screens/main_shell.dart';

// Filter chip definition — null metrics means "All"
class _FilterOption {
  final String label;
  final Set<HealthMetric>? metrics;
  const _FilterOption(this.label, this.metrics);
}

const _filters = [
  _FilterOption('All', null),
  _FilterOption('Blood Sugar', {HealthMetric.bloodSugar}),
  _FilterOption('Blood Pressure', {HealthMetric.systolic, HealthMetric.diastolic}),
  _FilterOption('Heart Rate', {HealthMetric.heartRate}),
  _FilterOption('Weight', {HealthMetric.weight}),
  _FilterOption('Steps', {HealthMetric.steps}),
];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _activeFilter = 0;

  @override
  void initState() {
    super.initState();
    // Trigger a load in case HomeScreen hasn't done it yet (e.g. deep-link)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        context.read<HealthHistoryProvider>().loadReadings(uid);
      }
    });
  }

  // ── Display helpers (now take String since HealthReading uses metricType) ──

  String _metricLabel(String metricType) {
    switch (metricType) {
      case 'bloodSugar':
        return 'Blood Sugar';
      case 'systolic':
        return 'Systolic BP';
      case 'diastolic':
        return 'Diastolic BP';
      case 'heartRate':
        return 'Heart Rate';
      case 'weight':
        return 'Weight';
      case 'steps':
        return 'Steps';
      default:
        return metricType;
    }
  }

  String _metricUnit(String metricType) {
    switch (metricType) {
      case 'bloodSugar':
        return 'mg/dL';
      case 'systolic':
      case 'diastolic':
        return 'mmHg';
      case 'heartRate':
        return 'bpm';
      case 'weight':
        return 'kg';
      case 'steps':
        return 'steps';
      default:
        return '';
    }
  }

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

  // Status strings are already display-ready ('Normal', 'Warning', 'Low', 'High', 'Logged')
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

  // Groups a newest-first list of readings into Today / Yesterday / date strings.
  // No reversal needed — the provider already keeps the list newest-first.
  Map<String, List<HealthReading>> _groupByDate(
      List<HealthReading> readings) {
    final map = <String, List<HealthReading>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final r in readings) {
      final day = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChartsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<HealthHistoryProvider>(
        builder: (context, provider, _) {
          final filtered =
              provider.filteredReadings(_filters[_activeFilter].metrics);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final isLoading = uid != null && !provider.isLoaded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              if (provider.allReadings.isNotEmpty) _buildSummaryCard(provider),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildReadingsList(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                _filters[i].label,
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

  Widget _buildSummaryCard(HealthHistoryProvider provider) {
    final lastTime = provider.lastReadingTime;
    final timeStr = lastTime != null ? _formatTime(lastTime) : '--';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: AppColors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Readings',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${provider.todayCount} ${provider.todayCount == 1 ? 'reading' : 'readings'} logged',
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
                  color: AppColors.white.withOpacity(0.75),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 2),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 44,
                color: AppColors.divider,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No readings yet',
              style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Log your first health reading\nfrom the home screen.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Log First Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsList(List<HealthReading> readings) {
    final grouped = _groupByDate(readings);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _countItems(grouped),
      itemBuilder: (context, index) {
        return _buildItemAtIndex(grouped, index);
      },
    );
  }

  int _countItems(Map<String, List<HealthReading>> grouped) {
    int count = 0;
    for (final group in grouped.values) {
      count += 1 + group.length;
    }
    return count;
  }

  Widget _buildItemAtIndex(
      Map<String, List<HealthReading>> grouped, int index) {
    int cursor = 0;
    for (final entry in grouped.entries) {
      if (index == cursor) return _buildDateHeader(entry.key);
      cursor++;
      final groupReadings = entry.value;
      if (index < cursor + groupReadings.length) {
        return _buildReadingTile(groupReadings[index - cursor]);
      }
      cursor += groupReadings.length;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Metric icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_metricIcon(reading.metricType), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          // Metric name + status badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _metricLabel(reading.metricType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reading.status, // already a display-ready string
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
          // Value + time
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
    );
  }
}
