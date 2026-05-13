import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/medication_service.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  bool _isLoading = true;
  List<_DayRecord> _days = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meds = await MedicationService.loadAll();
    final activeMeds = meds.where((m) => m.isActive).toList();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Fetch Firestore adherence data if logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, bool> firebaseAdherence = {};
    if (uid != null) {
      firebaseAdherence = await MedicationService.getAdherenceHistory(uid, 7);
    }

    final days = <_DayRecord>[];

    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      int total = 0;
      int taken = 0;

      for (final med in activeMeds) {
        final start = DateTime(
            med.startDate.year, med.startDate.month, med.startDate.day);
        if (start.isAfter(date)) continue;
        for (final time in med.times) {
          total++;
          final prefKey = 'taken_${med.id}_${time}_$dateStr';
          final firebaseKey = '${dateStr}_${med.id}_$time';
          if (prefs.getString(prefKey) == 'true' ||
              firebaseAdherence[firebaseKey] == true) {
            taken++;
          }
        }
      }

      days.add(_DayRecord(date: date, taken: taken, total: total));
    }

    if (mounted) {
      setState(() {
        _days = days;
        _isLoading = false;
      });
    }
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
        title: Text('Adherence History', style: AppTextStyles.heading3),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _days.every((d) => d.total == 0)
              ? _buildEmptyState()
              : _buildList(),
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('No history yet', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'Start tracking your medications to see your daily adherence here.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildDayCard(_days[i]),
    );
  }

  Widget _buildDayCard(_DayRecord day) {
    final pct = day.total > 0 ? (day.taken / day.total * 100).round() : 0;
    final ratio = day.total > 0 ? day.taken / day.total : 0.0;

    Color barColor;
    if (pct == 100) {
      barColor = AppColors.success;
    } else if (pct >= 50) {
      barColor = const Color(0xFFF57C00);
    } else {
      barColor = AppColors.error;
    }

    final isToday = _isToday(day.date);

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
              Expanded(
                child: Text(
                  isToday ? 'Today' : _formatDate(day.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                _dayName(day.date),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.divider.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${day.taken}/${day.total} doses ($pct%)',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: barColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _dayName(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }
}

class _DayRecord {
  final DateTime date;
  final int taken;
  final int total;

  const _DayRecord(
      {required this.date, required this.taken, required this.total});
}
