import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../health/services/health_reading_service.dart';
import '../../lifestyle/services/lifestyle_engine.dart';
import '../../lifestyle/models/lifestyle_suggestion.dart';

class SuggestionsPanelScreen extends StatefulWidget {
  final String diseaseType;
  // Snapshot of current session readings from HealthProvider (used for guest path)
  final Map<String, double?> currentReadings;

  const SuggestionsPanelScreen({
    super.key,
    required this.diseaseType,
    required this.currentReadings,
  });

  @override
  State<SuggestionsPanelScreen> createState() =>
      _SuggestionsPanelScreenState();
}

class _SuggestionsPanelScreenState extends State<SuggestionsPanelScreen> {
  bool _isLoading = true;
  bool _isGuest = false;
  List<LifestyleSuggestion> _suggestions = [];
  String _summaryText = '';
  int _readingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isGuest = uid == null;

    if (_isGuest) {
      _loadFromSession();
    } else {
      await _loadFromFirestore(uid!);
    }
  }

  // Guest: derive suggestions from whatever was entered this session
  void _loadFromSession() {
    final readings = <String, dynamic>{};
    widget.currentReadings.forEach((key, value) {
      if (value != null) readings[key] = value;
    });

    final suggestions =
        LifestyleEngine().getSuggestions(widget.diseaseType, readings);

    setState(() {
      _suggestions = suggestions;
      _readingCount = readings.length;
      _summaryText = readings.isEmpty
          ? 'No readings logged yet today.'
          : "Based on today's readings:";
      _isLoading = false;
    });
  }

  // Logged-in: fetch last 7 days, average each metric, run suggestions engine
  Future<void> _loadFromFirestore(String uid) async {
    try {
      final readings = await HealthReadingService.getReadingsLastDays(uid, 7);
      _readingCount = readings.length;

      // Group values by metric type
      final grouped = <String, List<double>>{};
      for (final r in readings) {
        grouped.putIfAbsent(r.metricType, () => []).add(r.value);
      }

      // Average per metric — this is what gets passed to the engine
      final averages = <String, dynamic>{};
      grouped.forEach((metric, values) {
        averages[metric] = values.reduce((a, b) => a + b) / values.length;
      });

      // Find the metric with the most concerning entries (Warning / High / Low)
      final concernCount = <String, int>{};
      for (final r in readings) {
        if (r.status == 'Warning' || r.status == 'High' || r.status == 'Low') {
          concernCount[r.metricType] = (concernCount[r.metricType] ?? 0) + 1;
        }
      }

      String mostConcerning = '';
      if (concernCount.isNotEmpty) {
        mostConcerning = concernCount.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }

      final suggestions =
          LifestyleEngine().getSuggestions(widget.diseaseType, averages);

      setState(() {
        _suggestions = suggestions;
        _summaryText = _buildSummaryText(mostConcerning);
        _isLoading = false;
      });
    } catch (_) {
      // Fall back to session data if Firestore fails
      _loadFromSession();
    }
  }

  String _buildSummaryText(String mostConcerning) {
    if (_readingCount == 0) {
      return 'No readings logged in the past 7 days.';
    }

    const metricLabels = {
      'bloodSugar': 'blood sugar',
      'systolic': 'blood pressure',
      'diastolic': 'blood pressure',
      'heartRate': 'heart rate',
      'weight': 'weight',
      'steps': 'daily steps',
    };

    if (mostConcerning.isNotEmpty) {
      final label = metricLabels[mostConcerning] ?? mostConcerning;
      return 'This week you logged $_readingCount readings. '
          'Your $label readings need attention.';
    }

    return 'This week you logged $_readingCount readings. '
        'Keep up the great work!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Health Insights', style: AppTextStyles.heading2),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 24),
                Text('Suggestions', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                ..._buildSuggestionCards(),
                const SizedBox(height: 24),
                _buildAppointmentsSection(),
              ],
            ),
    );
  }

  // ── Summary card at the top ───────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGuest ? "Today's Summary" : 'Weekly Summary',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _summaryText,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestion cards or empty state ──────────────────────────────────────

  List<Widget> _buildSuggestionCards() {
    if (_suggestions.isEmpty) {
      return [_buildEmptyState()];
    }
    return _suggestions
        .map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SuggestionCard(suggestion: s),
            ))
        .toList();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.favorite_rounded,
                color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text('All looks good!', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'Keep logging your readings\nto get personalised insights',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Appointments placeholder ──────────────────────────────────────────────

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Appointments', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: AppColors.secondary, size: 24),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No upcoming appointments',
                      style: AppTextStyles.label),
                  const SizedBox(height: 4),
                  Text(
                    'Appointment reminders will appear here',
                    style:
                        AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Individual suggestion card ────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final LifestyleSuggestion suggestion;

  const _SuggestionCard({required this.suggestion});

  Color get _borderColor {
    switch (suggestion.priority) {
      case SuggestionPriority.high:
        return AppColors.error;
      case SuggestionPriority.medium:
        return AppColors.warning;
      case SuggestionPriority.low:
        return AppColors.success;
    }
  }

  IconData get _priorityIcon {
    switch (suggestion.priority) {
      case SuggestionPriority.high:
        return Icons.warning_rounded;
      case SuggestionPriority.medium:
        return Icons.info_rounded;
      case SuggestionPriority.low:
        return Icons.check_circle_rounded;
    }
  }

  String get _categoryLabel {
    switch (suggestion.category) {
      case SuggestionCategory.nutrition:
        return 'Nutrition';
      case SuggestionCategory.exercise:
        return 'Exercise';
      case SuggestionCategory.sleep:
        return 'Sleep';
      case SuggestionCategory.stress:
        return 'Stress';
      case SuggestionCategory.hydration:
        return 'Hydration';
      case SuggestionCategory.medication:
        return 'Medication';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: _borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_priorityIcon, color: _borderColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(suggestion.description,
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: 10),
                  _CategoryChip(
                      label: _categoryLabel, color: _borderColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small category chip ───────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
