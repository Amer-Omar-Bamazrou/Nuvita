import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/health_metric_card.dart';
import '../../../core/services/preferences_service.dart';
import '../../dashboard/providers/health_provider.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../notifications/screens/suggestions_panel_screen.dart';

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

  // Maps disease IDs to display labels
  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart Condition',
    'other': 'General Monitoring',
  };

  // Static metadata for every possible metric
  static const _configs = <HealthMetric, _MetricConfig>{
    HealthMetric.bloodSugar: _MetricConfig(
      title: 'Blood Sugar',
      icon: Icons.water_drop,
      unit: 'mg/dL',
      min: 20,
      max: 600,
    ),
    HealthMetric.systolic: _MetricConfig(
      title: 'Systolic BP',
      icon: Icons.favorite,
      unit: 'mmHg',
      min: 50,
      max: 250,
    ),
    HealthMetric.diastolic: _MetricConfig(
      title: 'Diastolic BP',
      icon: Icons.favorite_border,
      unit: 'mmHg',
      min: 30,
      max: 150,
    ),
    HealthMetric.heartRate: _MetricConfig(
      title: 'Heart Rate',
      icon: Icons.monitor_heart,
      unit: 'BPM',
      min: 20,
      max: 250,
    ),
    HealthMetric.weight: _MetricConfig(
      title: 'Weight',
      icon: Icons.scale,
      unit: 'kg',
      min: 20,
      max: 300,
    ),
    HealthMetric.steps: _MetricConfig(
      title: 'Daily Steps',
      icon: Icons.directions_walk,
      unit: 'steps',
      min: 0,
      max: 100000,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // Always try SharedPreferences first — works for both guest and auth users
    final savedFirstName = await PreferencesService.getFirstName();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Guest user — use the name from onboarding prefs
      setState(() {
        _userName = savedFirstName ?? '';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      setState(() {
        // Prefer Firestore name, fall back to SharedPreferences name
        final firestoreName = profile?['name'] as String? ?? '';
        _userName = firestoreName.isNotEmpty ? firestoreName : (savedFirstName ?? '');
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
        _isLoading = false;
      });
      if (mounted) {
        // Restore latest card values from Firestore so the home screen
        // shows the previous session's readings on app restart
        context.read<HealthProvider>().loadReadingsFromFirebase(uid);
        // Populate the history list
        context.read<HealthHistoryProvider>().loadReadings(uid);
      }
    } catch (_) {
      setState(() {
        _userName = savedFirstName ?? '';
        _isLoading = false;
      });
    }
  }

  // Which metrics to show depends on the user's condition
  List<HealthMetric> get _activeMetrics {
    switch (_diseaseType) {
      case 'diabetes':
        return [HealthMetric.bloodSugar, HealthMetric.weight, HealthMetric.steps];
      case 'blood_pressure':
        return [HealthMetric.systolic, HealthMetric.diastolic, HealthMetric.steps];
      case 'heart':
      case 'other':
      default:
        return [HealthMetric.heartRate, HealthMetric.weight, HealthMetric.steps];
    }
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
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
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

    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(provider),
                  const SizedBox(height: 20),
                  _buildSummaryBanner(),
                  const SizedBox(height: 24),
                  Text("Today's Readings", style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  _buildMetricsGrid(provider),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildFAB(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  // ── Header: greeting + date + notification icon ───────────────────────────

  Widget _buildHeader(HealthProvider provider) {
    final firstName = _userName.trim().split(' ').first;
    final hasBadge = _hasConcerningReadings(provider);

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
        // Notification icon — taps open the Health Insights panel
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SuggestionsPanelScreen(
                diseaseType: _diseaseType,
                currentReadings: {
                  for (final m in HealthMetric.values)
                    m.name: provider.getValue(m),
                },
              ),
            ),
          ),
          child: Stack(
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
              // Red badge when any metric is in warning or critical range
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
          ),
        ),
      ],
    );
  }

  // Returns true if any currently tracked metric is outside the safe range
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
          Column(
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
                style: AppTextStyles.heading3.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Metrics grid ─────────────────────────────────────────────────────────

  Widget _buildMetricsGrid(HealthProvider provider) {
    final metrics = _activeMetrics;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.88,
      children: metrics.map((metric) {
        final config = _configs[metric]!;
        final value = provider.getValue(metric);
        final status =
            value != null ? provider.getStatus(metric, value) : null;

        return HealthMetricCard(
          title: config.title,
          icon: config.icon,
          unit: config.unit,
          value: value,
          status: status,
          minValue: config.min,
          maxValue: config.max,
          suggestion: value != null
              ? provider.getSuggestionForMetric(metric.name, value)
              : null,
          onSubmit: (v) {
            provider.updateValue(metric, v);
            final newStatus = provider.getStatus(metric, v);
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              provider.saveReadingToFirebase(uid, metric, v, newStatus, config.unit);
            }
            context.read<HealthHistoryProvider>().addReading(metric, v);
          },
        );
      }).toList(),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tap any card above to add your reading'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: AppColors.white),
      label: Text("Add Today's Reading", style: AppTextStyles.buttonText),
    );
  }
}

// ── Metric config data class ──────────────────────────────────────────────────

class _MetricConfig {
  final String title;
  final IconData icon;
  final String unit;
  final double min;
  final double max;

  const _MetricConfig({
    required this.title,
    required this.icon,
    required this.unit,
    required this.min,
    required this.max,
  });
}
