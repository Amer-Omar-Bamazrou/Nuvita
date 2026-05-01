import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chart_data_point.dart';
import '../models/metric_thresholds.dart';

class ChartDataService {
  ChartDataService._();

  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('readings');

  /// Fetches readings for a given metricType from the last [days] days.
  /// Results are sorted oldest → newest (ascending) so fl_chart renders left to right.
  /// Filtering by date and metricType is done client-side to avoid composite indexes.
  static Future<List<ChartDataPoint>> getChartData(
    String uid,
    String metricType,
    int days,
  ) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snap = await _col(uid)
        .orderBy('timestamp', descending: false)
        .get();

    return snap.docs.where((d) {
      final data = d.data();
      final stored = data['metricType'] as String? ?? '';
      if (stored != metricType) return false;

      final ts = data['timestamp'];
      final DateTime dt =
          ts is Timestamp ? ts.toDate() : DateTime.now();
      return dt.isAfter(cutoff);
    }).map((d) {
      final data = d.data();
      final ts = data['timestamp'];
      final DateTime dt =
          ts is Timestamp ? ts.toDate() : DateTime.now();
      final double value = (data['value'] as num?)?.toDouble() ?? 0.0;
      final String status = data['status'] as String? ?? 'Logged';
      return ChartDataPoint(date: dt, value: value, status: status);
    }).toList();
  }

  /// Splits data in half and compares averages.
  /// For heart rate: closer to 75 = improving.
  /// For all others: lower second half = improving.
  /// < 5% difference in averages = stable.
  static TrendDirection getTrend(
    List<ChartDataPoint> points,
    String metricType,
  ) {
    if (points.length < 2) return TrendDirection.stable;

    final mid = points.length ~/ 2;
    final firstHalf = points.sublist(0, mid);
    final secondHalf = points.sublist(mid);

    final firstAvg =
        firstHalf.map((p) => p.value).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg =
        secondHalf.map((p) => p.value).reduce((a, b) => a + b) / secondHalf.length;

    final diff = (secondAvg - firstAvg).abs();
    final stableThreshold = firstAvg * 0.05;
    if (diff < stableThreshold) return TrendDirection.stable;

    if (metricType == 'heartRate') {
      // A reading closer to the resting-heart-rate target of 75 is better
      final firstDist = (firstAvg - 75).abs();
      final secondDist = (secondAvg - 75).abs();
      return secondDist < firstDist
          ? TrendDirection.improving
          : TrendDirection.worsening;
    }

    return secondAvg < firstAvg
        ? TrendDirection.improving
        : TrendDirection.worsening;
  }

  /// Average of all readings for the metric over the last 7 days.
  static Future<double> getWeeklyAverage(String uid, String metricType) async {
    final points = await getChartData(uid, metricType, 7);
    if (points.isEmpty) return 0.0;
    return points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
  }

  /// Returns a human-readable insight based on the trend + threshold status of [average].
  static String getInsight(
    String metricType,
    TrendDirection trend,
    double average,
  ) {
    final status = MetricThresholds.getStatus(metricType, average);
    final label = metricLabel(metricType);

    if (trend == TrendDirection.improving && status == 'Normal') {
      return 'Great progress! Your $label has been improving. Keep up your current routine.';
    }
    if (trend == TrendDirection.worsening && status == 'Warning') {
      return 'Your $label has been trending higher. Consider reviewing your habits and consulting your doctor.';
    }
    if (trend == TrendDirection.stable && status == 'Normal') {
      return 'Your $label is stable and within normal range. Well done!';
    }
    if (trend == TrendDirection.stable && status == 'Critical') {
      return 'Your $label remains concerning. Please consult your doctor.';
    }
    if (trend == TrendDirection.improving) {
      return 'Your $label is trending in the right direction. Keep monitoring closely.';
    }
    if (trend == TrendDirection.worsening) {
      return 'Your $label has been trending up. Consider lifestyle adjustments and speak to your doctor.';
    }
    return 'Your $label readings have been recorded. Keep logging for better insights.';
  }

  /// Returns the "personal best" data point:
  /// - Heart rate: reading closest to the healthy resting target of 75 bpm.
  /// - BP / glucose: lowest recorded value.
  static ChartDataPoint? getPersonalBest(
    String metricType,
    List<ChartDataPoint> points,
  ) {
    if (points.isEmpty) return null;

    if (metricType == 'heartRate') {
      return points.reduce(
        (a, b) => (a.value - 75).abs() < (b.value - 75).abs() ? a : b,
      );
    }
    return points.reduce((a, b) => a.value < b.value ? a : b);
  }

  /// Groups points by calendar day and returns best / worst / most-consistent days.
  /// Returns null when data spans fewer than 7 days.
  static Map<String, dynamic>? getWeeklySummary(List<ChartDataPoint> points) {
    if (points.length < 2) return null;

    final span = points.last.date.difference(points.first.date).inDays;
    if (span < 7) return null;

    // Group values by calendar day
    final byDay = <DateTime, List<double>>{};
    for (final p in points) {
      final day = DateTime(p.date.year, p.date.month, p.date.day);
      byDay.putIfAbsent(day, () => []).add(p.value);
    }
    if (byDay.length < 3) return null;

    final stats = byDay.entries.map((e) {
      final vals = e.value;
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      final variance =
          vals.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / vals.length;
      final stdDev = sqrt(variance);
      return _DayStat(e.key, avg, stdDev);
    }).toList();

    final bestDay = stats.reduce((a, b) => a.avg < b.avg ? a : b);
    final worstDay = stats.reduce((a, b) => a.avg > b.avg ? a : b);
    final mostConsistentDay = stats.reduce(
      (a, b) => a.stdDev < b.stdDev ? a : b,
    );

    return {
      'bestDay': bestDay.day,
      'worstDay': worstDay.day,
      'mostConsistentDay': mostConsistentDay.day,
    };
  }

  /// Compares the last 7 days average against the previous 7 days.
  /// Intended to be called only for 30-day or 3-month view ranges.
  /// Returns null when there is insufficient data for both windows.
  static Future<String?> getComparisonInsight(
    String uid,
    String metricType,
  ) async {
    final all = await getChartData(uid, metricType, 14);
    final sevenAgo = DateTime.now().subtract(const Duration(days: 7));
    final fourteenAgo = DateTime.now().subtract(const Duration(days: 14));

    final last7 = all.where((p) => p.date.isAfter(sevenAgo)).toList();
    final prev7 = all
        .where((p) => p.date.isAfter(fourteenAgo) && p.date.isBefore(sevenAgo))
        .toList();

    if (last7.isEmpty || prev7.isEmpty) return null;

    final lastAvg =
        last7.map((p) => p.value).reduce((a, b) => a + b) / last7.length;
    final prevAvg =
        prev7.map((p) => p.value).reduce((a, b) => a + b) / prev7.length;

    if (prevAvg == 0) return null;

    final pct = ((lastAvg - prevAvg) / prevAvg * 100).abs().toStringAsFixed(1);
    final label = metricLabel(metricType);

    return lastAvg < prevAvg
        ? 'This period your average $label was $pct% lower than the previous 7 days.'
        : 'This period your average $label was $pct% higher than the previous 7 days.';
  }

  /// Lowercase label used inside insight sentences.
  static String metricLabel(String metricType) {
    switch (metricType) {
      case 'systolic':
        return 'blood pressure';
      case 'heartRate':
        return 'heart rate';
      case 'bloodSugar':
        return 'blood sugar';
      default:
        return metricType;
    }
  }
}

// Internal helper — not exposed outside this file
class _DayStat {
  final DateTime day;
  final double avg;
  final double stdDev;
  _DayStat(this.day, this.avg, this.stdDev);
}
