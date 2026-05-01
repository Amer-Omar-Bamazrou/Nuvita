import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/register_screen.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../home/screens/main_shell.dart';
import '../models/chart_data_point.dart';
import '../services/chart_data_service.dart';
import '../widgets/health_chart_widget.dart';

// ─── Enums used only within this screen ───────────────────────────────────────

enum _ChartMetric { systolic, heartRate, bloodSugar }

enum _TimeRange { days7, days30, months3 }

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  _ChartMetric _metric = _ChartMetric.heartRate;
  _TimeRange _range = _TimeRange.days7;

  String _diseaseType = 'other';
  bool _loadingDisease = true;
  bool _loadingChart = false;

  List<ChartDataPoint> _dataPoints = [];
  TrendDirection _trend = TrendDirection.stable;
  double _average = 0;
  ChartDataPoint? _personalBest;
  Map<String, dynamic>? _weeklySummary;
  String? _comparisonInsight;

  @override
  void initState() {
    super.initState();
    _loadDisease();
  }

  // ── Disease type ──────────────────────────────────────────────────────────

  Future<void> _loadDisease() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingDisease = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      final disease = profile?['diseaseType'] as String? ?? 'other';

      setState(() {
        _diseaseType = disease;
        _metric = _defaultMetric(disease);
        _loadingDisease = false;
      });
    } catch (_) {
      setState(() => _loadingDisease = false);
    }

    _loadChartData();
  }

  _ChartMetric _defaultMetric(String disease) {
    switch (disease) {
      case 'diabetes':
        return _ChartMetric.bloodSugar;
      case 'blood_pressure':
        return _ChartMetric.systolic;
      default:
        return _ChartMetric.heartRate;
    }
  }

  List<_ChartMetric> get _availableMetrics {
    switch (_diseaseType) {
      case 'blood_pressure':
        return [_ChartMetric.systolic, _ChartMetric.heartRate];
      case 'diabetes':
        return [_ChartMetric.bloodSugar, _ChartMetric.systolic];
      default:
        return [_ChartMetric.heartRate, _ChartMetric.systolic, _ChartMetric.bloodSugar];
    }
  }

  // ── Chart data ────────────────────────────────────────────────────────────

  int get _days {
    switch (_range) {
      case _TimeRange.days7:
        return 7;
      case _TimeRange.days30:
        return 30;
      case _TimeRange.months3:
        return 90;
    }
  }

  Future<void> _loadChartData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loadingChart = true);

    try {
      final metricType = _metricTypeStr(_metric);
      final points = await ChartDataService.getChartData(uid, metricType, _days);

      final trend = ChartDataService.getTrend(points, metricType);
      final avg = points.isEmpty
          ? 0.0
          : points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
      final best = ChartDataService.getPersonalBest(metricType, points);
      final summary = ChartDataService.getWeeklySummary(points);

      // Comparison: only for 30d / 3m view, computed from already-fetched data
      String? comparison;
      if (_range != _TimeRange.days7 && points.length >= 2) {
        comparison = _computeComparison(points, metricType);
      }

      if (!mounted) return;
      setState(() {
        _dataPoints = points;
        _trend = trend;
        _average = avg;
        _personalBest = best;
        _weeklySummary = summary;
        _comparisonInsight = comparison;
        _loadingChart = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingChart = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load chart data. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadChartData,
            ),
          ),
        );
      }
    }
  }

  // Compares last 7 days vs the 7 days before that, using already-fetched data.
  String? _computeComparison(List<ChartDataPoint> points, String metricType) {
    final sevenAgo = DateTime.now().subtract(const Duration(days: 7));
    final fourteenAgo = DateTime.now().subtract(const Duration(days: 14));

    final last7 = points.where((p) => p.date.isAfter(sevenAgo)).toList();
    final prev7 = points
        .where((p) =>
            p.date.isAfter(fourteenAgo) && p.date.isBefore(sevenAgo))
        .toList();

    if (last7.isEmpty || prev7.isEmpty) return null;

    final lastAvg =
        last7.map((p) => p.value).reduce((a, b) => a + b) / last7.length;
    final prevAvg =
        prev7.map((p) => p.value).reduce((a, b) => a + b) / prev7.length;

    if (prevAvg == 0) return null;

    final pct = ((lastAvg - prevAvg) / prevAvg * 100).abs().toStringAsFixed(1);
    final label = ChartDataService.metricLabel(metricType);

    return lastAvg < prevAvg
        ? 'This period your average $label was $pct% lower than the previous 7 days.'
        : 'This period your average $label was $pct% higher than the previous 7 days.';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _metricTypeStr(_ChartMetric m) {
    switch (m) {
      case _ChartMetric.systolic:
        return 'systolic';
      case _ChartMetric.heartRate:
        return 'heartRate';
      case _ChartMetric.bloodSugar:
        return 'bloodSugar';
    }
  }

  String _metricLabel(_ChartMetric m) {
    switch (m) {
      case _ChartMetric.systolic:
        return 'Blood Pressure';
      case _ChartMetric.heartRate:
        return 'Heart Rate';
      case _ChartMetric.bloodSugar:
        return 'Glucose';
    }
  }

  String _metricUnit(_ChartMetric m) {
    switch (m) {
      case _ChartMetric.systolic:
        return 'mmHg';
      case _ChartMetric.heartRate:
        return 'bpm';
      case _ChartMetric.bloodSugar:
        return 'mg/dL';
    }
  }

  String _rangeLabel(_TimeRange r) {
    switch (r) {
      case _TimeRange.days7:
        return '7 Days';
      case _TimeRange.days30:
        return '30 Days';
      case _TimeRange.months3:
        return '3 Months';
    }
  }

  String _formatDay(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]} ${dt.day}/${dt.month}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return _buildGuestView();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text(
          'Health Trends',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _loadingDisease
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricChips(),
                _buildTimeRangeToggle(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  // ── Metric chips ──────────────────────────────────────────────────────────

  Widget _buildMetricChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _availableMetrics.map((m) {
          final selected = m == _metric;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (m == _metric) return;
                setState(() => _metric = m);
                _loadChartData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _metricLabel(m),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Time range toggle ─────────────────────────────────────────────────────

  Widget _buildTimeRangeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: _TimeRange.values.map((r) {
          final selected = r == _range;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (r == _range) return;
                setState(() => _range = r);
                _loadChartData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Text(
                  _rangeLabel(r),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.secondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Content area ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_loadingChart) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_dataPoints.isEmpty) {
      return _buildEmptyState();
    }

    return _buildChartContent();
  }

  Widget _buildEmptyState() {
    // Determine which empty state to show
    final hasAnyReadings =
        context.read<HealthHistoryProvider>().allReadings.isNotEmpty;

    if (!hasAnyReadings) {
      // Type 1: user has never logged anything
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  size: 40,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Not enough data yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log at least 2 readings to see trends',
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Log a Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Type 2: readings exist but none for this metric / period
    final label = _metricLabel(_metric);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 56,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No $label data for this period',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging $label to see trends',
              style: const TextStyle(fontSize: 14, color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendHeaderCard(),
          const SizedBox(height: 12),
          _buildChartCard(),
          const SizedBox(height: 12),
          _buildInsightCard(),
          if (_weeklySummary != null) ...[
            const SizedBox(height: 12),
            _buildWeeklySummaryCard(_weeklySummary!),
          ],
          if (_comparisonInsight != null) ...[
            const SizedBox(height: 12),
            _buildComparisonCard(_comparisonInsight!),
          ],
        ],
      ),
    );
  }

  // ── Trend header card ─────────────────────────────────────────────────────

  Widget _buildTrendHeaderCard() {
    final label = _metricLabel(_metric);
    final unit = _metricUnit(_metric);
    final latest = _dataPoints.isNotEmpty ? _dataPoints.last : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (latest != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: latest.value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Avg ${_average.toStringAsFixed(1)} $unit · ${_rangeLabel(_range)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          _buildTrendIndicator(),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator() {
    switch (_trend) {
      case TrendDirection.improving:
        return Column(
          children: const [
            Icon(Icons.trending_up_rounded, color: Color(0xFF388E3C), size: 36),
            SizedBox(height: 4),
            Text(
              'Improving',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF388E3C),
              ),
            ),
          ],
        );
      case TrendDirection.worsening:
        return Column(
          children: const [
            Icon(Icons.trending_down_rounded, color: AppColors.error, size: 36),
            SizedBox(height: 4),
            Text(
              'Worsening',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        );
      case TrendDirection.stable:
        return Column(
          children: const [
            Icon(Icons.trending_flat_rounded, color: Colors.grey, size: 36),
            SizedBox(height: 4),
            Text(
              'Stable',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        );
    }
  }

  // ── Chart card ────────────────────────────────────────────────────────────

  Widget _buildChartCard() {
    final unit = _metricUnit(_metric);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 0, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend row for personal best indicator
          if (_personalBest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Personal Best',
                    style: TextStyle(fontSize: 11, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          HealthChartWidget(
            dataPoints: _dataPoints,
            metricType: _metricTypeStr(_metric),
            unit: unit,
            personalBest: _personalBest,
          ),
        ],
      ),
    );
  }

  // ── Insight card ──────────────────────────────────────────────────────────

  Widget _buildInsightCard() {
    final insight = ChartDataService.getInsight(
      _metricTypeStr(_metric),
      _trend,
      _average,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insight',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly summary card ───────────────────────────────────────────────────

  Widget _buildWeeklySummaryCard(Map<String, dynamic> summary) {
    final bestDay = summary['bestDay'] as DateTime;
    final worstDay = summary['worstDay'] as DateTime;
    final consistentDay = summary['mostConsistentDay'] as DateTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.star_rounded,
            color: const Color(0xFF388E3C),
            label: 'Best day',
            value: _formatDay(bestDay),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            label: 'Worst day',
            value: _formatDay(worstDay),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.show_chart_rounded,
            color: AppColors.secondary,
            label: 'Most consistent',
            value: _formatDay(consistentDay),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.secondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ── Comparison card ───────────────────────────────────────────────────────

  Widget _buildComparisonCard(String insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Guest view ────────────────────────────────────────────────────────────

  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text(
          'Health Trends',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Charts available for registered users',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account to track your health trends over time',
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
