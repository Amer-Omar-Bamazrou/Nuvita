import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../dashboard/providers/health_provider.dart';
import '../services/lifestyle_engine.dart';
import '../widgets/suggestion_card.dart';

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  String _diseaseType = 'other';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiseaseType();
  }

  Future<void> _loadDiseaseType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      setState(() {
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // Builds the readings map from the shared HealthProvider session state
  Map<String, dynamic> _buildReadings(HealthProvider provider) {
    final map = <String, dynamic>{};
    for (final metric in HealthMetric.values) {
      final value = provider.getValue(metric);
      if (value != null) map[metric.name] = value;
    }
    return map;
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
        final readings = _buildReadings(provider);
        final suggestions =
            LifestyleEngine().getSuggestions(_diseaseType, readings);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildHeader(context),
                if (suggestions.isEmpty)
                  _buildEmptyState()
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => SuggestionCard(suggestion: suggestions[i]),
                        childCount: suggestions.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Row(
          children: [
            if (canPop) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textDark.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Suggestions', style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                Text(
                  'Based on your latest readings',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 72,
              color: AppColors.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No tips yet',
              style: AppTextStyles.heading3.copyWith(color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first reading on the Home tab to get personalised lifestyle tips.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
