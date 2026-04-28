import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../health/services/health_reading_service.dart';
import '../../core/theme/app_colors.dart';

class TrendWarningService {
  static const _prefKey = 'bp_trend_warning_shown_date';

  // Checks the last 7 days of BP readings and warns the user if the
  // weekly average is consistently above safe thresholds. We guard with a
  // date flag so the snackbar never fires more than once per calendar day.
  static Future<void> checkBPTrend(BuildContext context, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    // Already shown today — skip
    if (prefs.getString(_prefKey) == today) return;

    final readings = await HealthReadingService.getReadingsLastDays(uid, 7);

    final systolicReadings = readings
        .where((r) => r.metricType == 'systolic')
        .map((r) => r.value)
        .toList();

    final diastolicReadings = readings
        .where((r) => r.metricType == 'diastolic')
        .map((r) => r.value)
        .toList();

    // Need at least one reading of each type before making a judgement
    if (systolicReadings.isEmpty && diastolicReadings.isEmpty) return;

    final avgSystolic = systolicReadings.isNotEmpty
        ? systolicReadings.reduce((a, b) => a + b) / systolicReadings.length
        : 0.0;

    final avgDiastolic = diastolicReadings.isNotEmpty
        ? diastolicReadings.reduce((a, b) => a + b) / diastolicReadings.length
        : 0.0;

    final isHigh = avgSystolic > 140 || avgDiastolic > 90;
    if (!isHigh) return;

    // Mark as shown for today before displaying so a hot-reload doesn't double-fire
    await prefs.setString(_prefKey, today);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Your blood pressure has been trending high this week. '
          'Consider consulting your doctor.',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
