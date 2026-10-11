import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/health/conditions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../services/conditions_service.dart';

// ─── Condition option data ────────────────────────────────────────────────────

class _ConditionOption {
  final Condition condition;
  final String emoji;
  final String subtitle;

  const _ConditionOption(this.condition, this.emoji, this.subtitle);
}

const _options = [
  _ConditionOption(Condition.diabetesType1, '🩸', 'Blood sugar monitoring'),
  _ConditionOption(Condition.diabetesType2, '🩸', 'Blood sugar monitoring'),
  _ConditionOption(Condition.hypertension, '💉', 'High blood pressure'),
  _ConditionOption(Condition.heartDisease, '❤️', 'Cardiovascular'),
  _ConditionOption(Condition.other, '➕', 'General monitoring'),
];

// Multi-select list of conditions. Used by the onboarding conditions step
// and by DiseaseSelectionScreen.
class ConditionSelector extends StatelessWidget {
  final Set<Condition> selected;
  final ValueChanged<Set<Condition>> onChanged;

  const ConditionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DiseaseCard(
              emoji: o.emoji,
              title: o.condition.label,
              subtitle: o.subtitle,
              isSelected: selected.contains(o.condition),
              onTap: () {
                final next = {...selected};
                if (!next.remove(o.condition)) next.add(o.condition);
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

// Edits the signed-in patient's conditions (Profile → My conditions).
// Pops with true after saving.
class DiseaseSelectionScreen extends StatefulWidget {
  const DiseaseSelectionScreen({super.key});

  @override
  State<DiseaseSelectionScreen> createState() => _DiseaseSelectionScreenState();
}

class _DiseaseSelectionScreenState extends State<DiseaseSelectionScreen> {
  Set<Condition> _selected = {};
  bool _unspecifiedDiabetes = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final current = await ConditionsService.load(uid);
      if (!mounted) return;
      setState(() {
        _selected = {...current.conditions};
        _unspecifiedDiabetes = current.unspecifiedDiabetes;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DiseaseSelectionScreen: load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_selected.isEmpty) {
      _showError('Select at least one condition, or Other');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showError('Please sign in to save your conditions');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ConditionsService.save(uid, PatientConditions(_selected));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('DiseaseSelectionScreen: save failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Failed to save. Please try again.');
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
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _loadFailed
                ? _buildLoadError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("What are your conditions?",
                            style: AppTextStyles.heading1),
                        const SizedBox(height: 8),
                        Text(
                          'Select all that apply. Nuvita uses them to put the '
                          'right readings and charts first, and your doctor '
                          'sees them too.',
                          style: AppTextStyles.bodySmall,
                        ),
                        if (_unspecifiedDiabetes) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Your profile says diabetes without the type. '
                            'Please choose type 1 or type 2.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                        const SizedBox(height: 28),
                        ConditionSelector(
                          selected: _selected,
                          onChanged: (next) =>
                              setState(() => _selected = next),
                        ),
                        const SizedBox(height: 20),
                        NuvitaButton(
                          label: 'Save',
                          onPressed: _isSaving ? null : _onSave,
                          isLoading: _isSaving,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Couldn't load your conditions",
                style: AppTextStyles.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            NuvitaButton(label: 'Retry', onPressed: _load, isOutlined: true),
          ],
        ),
      ),
    );
  }
}

// ─── DiseaseCard ──────────────────────────────────────────────────────────────

class DiseaseCard extends StatelessWidget {
  const DiseaseCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.5 : 1.5,
          ),
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
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
