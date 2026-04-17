import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../dashboard/providers/health_provider.dart';
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
  int _activeFilter = 0; // index into _filters

  // Display label for a metric
  String _metricLabel(HealthMetric m) {
    if (m == HealthMetric.bloodSugar) return 'Blood Sugar';
    if (m == HealthMetric.systolic) return 'Systolic BP';
    if (m == HealthMetric.diastolic) return 'Diastolic BP';
    if (m == HealthMetric.heartRate) return 'Heart Rate';
    if (m == HealthMetric.weight) return 'Weight';
    if (m == HealthMetric.steps) return 'Steps';
    return '';
  }

  String _metricUnit(HealthMetric m) {
    if (m == HealthMetric.bloodSugar) return 'mg/dL';
    if (m == HealthMetric.systolic) return 'mmHg';
    if (m == HealthMetric.diastolic) return 'mmHg';
    if (m == HealthMetric.heartRate) return 'bpm';
    if (m == HealthMetric.weight) return 'kg';
    if (m == HealthMetric.steps) return 'steps';
    return '';
  }

  IconData _metricIcon(HealthMetric m) {
    if (m == HealthMetric.bloodSugar) return Icons.water_drop_rounded;
    if (m == HealthMetric.systolic || m == HealthMetric.diastolic) {
      return Icons.favorite_rounded;
    }
    if (m == HealthMetric.heartRate) return Icons.monitor_heart_rounded;
    if (m == HealthMetric.weight) return Icons.scale_rounded;
    if (m == HealthMetric.steps) return Icons.directions_walk_rounded;
    return Icons.health_and_safety_rounded;
  }

  Color _metricColor(HealthMetric m) {
    if (m == HealthMetric.bloodSugar) return const Color(0xFF1976D2);
    if (m == HealthMetric.systolic || m == HealthMetric.diastolic) {
      return const Color(0xFFD32F2F);
    }
    if (m == HealthMetric.heartRate) return const Color(0xFFE64A19);
    if (m == HealthMetric.weight) return const Color(0xFF388E3C);
    if (m == HealthMetric.steps) return const Color(0xFF7B1FA2);
    return AppColors.secondary;
  }

  // Badge colour based on status
  Color _statusColor(MetricStatus? status) {
    if (status == null) return AppColors.secondary;
    if (status == MetricStatus.normal) return AppColors.success;
    if (status == MetricStatus.warning) return AppColors.warning;
    return AppColors.error;
  }

  String _statusLabel(MetricStatus? status) {
    if (status == null) return 'Logged';
    if (status == MetricStatus.normal) return 'Normal';
    if (status == MetricStatus.warning) return 'Warning';
    if (status == MetricStatus.criticalLow) return 'Low';
    return 'High';
  }

  // Format time as "9:04 AM"
  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Group a sorted list of readings into Today / Yesterday / date strings
  LinkedHashMap<String, List<HealthReading>> _groupByDate(
      List<HealthReading> readings) {
    final map = LinkedHashMap<String, List<HealthReading>>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Reverse so newest first
    for (final r in readings.reversed) {
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
      ),
      body: Consumer<HealthHistoryProvider>(
        builder: (context, provider, _) {
          final filtered = provider.filteredReadings(_filters[_activeFilter].metrics);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              if (provider.allReadings.isNotEmpty) _buildSummaryCard(provider),
              Expanded(
                child: filtered.isEmpty
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  // Navigate to MainShell at Home tab (index 0)
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

  // Total item count = sum of (1 header + n readings) per group
  int _countItems(LinkedHashMap<String, List<HealthReading>> grouped) {
    int count = 0;
    for (final group in grouped.values) {
      count += 1 + group.length;
    }
    return count;
  }

  Widget _buildItemAtIndex(
      LinkedHashMap<String, List<HealthReading>> grouped, int index) {
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
    final color = _metricColor(reading.metric);
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
            child: Icon(_metricIcon(reading.metric), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          // Name + status badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _metricLabel(reading.metric),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(reading.status),
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
                      text: ' ${_metricUnit(reading.metric)}',
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
