import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../models/patient_model.dart';
import '../services/patient_service.dart';
import '../../home/screens/main_shell.dart';

// ─── Disease option data ──────────────────────────────────────────────────────

class _DiseaseOption {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;

  const _DiseaseOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DiseaseSelectionScreen extends StatefulWidget {
  const DiseaseSelectionScreen({super.key});

  @override
  State<DiseaseSelectionScreen> createState() =>
      _DiseaseSelectionScreenState();
}

class _DiseaseSelectionScreenState extends State<DiseaseSelectionScreen> {
  // Phase state
  String? _selectedDisease;
  bool _isShowingQuestions = false;

  // Step state (0-indexed, 0–6 = 7 steps)
  int _currentStep = 0;
  bool _isGoingForward = true;
  static const int _totalSteps = 7;

  // Personal info inputs
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _gender;
  bool? _smokes;
  bool? _onMedication;
  bool _isLoading = false;

  static const _diseases = [
    _DiseaseOption(
      id: 'diabetes',
      emoji: '🩸',
      title: 'Diabetes',
      subtitle: 'Type 1 & Type 2',
    ),
    _DiseaseOption(
      id: 'blood_pressure',
      emoji: '💉',
      title: 'Blood Pressure',
      subtitle: 'Hypertension',
    ),
    _DiseaseOption(
      id: 'heart',
      emoji: '❤️',
      title: 'Heart Condition',
      subtitle: 'Cardiovascular',
    ),
    _DiseaseOption(
      id: 'other',
      emoji: '➕',
      title: 'Other',
      subtitle: 'General monitoring',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter your full name');
          return false;
        }
        break;
      case 1:
        final age = int.tryParse(_ageController.text.trim());
        if (age == null || age < 1 || age > 120) {
          _showError('Please enter a valid age');
          return false;
        }
        break;
      case 2:
        if (_gender == null) {
          _showError('Please select your gender');
          return false;
        }
        break;
      case 3:
        final h = double.tryParse(_heightController.text.trim());
        if (h == null || h < 50 || h > 300) {
          _showError('Please enter a valid height in cm');
          return false;
        }
        break;
      case 4:
        final w = double.tryParse(_weightController.text.trim());
        if (w == null || w < 10 || w > 500) {
          _showError('Please enter a valid weight in kg');
          return false;
        }
        break;
      case 5:
        if (_smokes == null) {
          _showError('Please select an option');
          return false;
        }
        break;
      case 6:
        if (_onMedication == null) {
          _showError('Please select an option');
          return false;
        }
        break;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────

  void _handleContinue() {
    if (_selectedDisease == null) {
      _showError('Please select your condition to continue');
      return;
    }
    setState(() {
      _currentStep = 0;
      _isShowingQuestions = true;
    });
  }

  void _handleNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStep == _totalSteps - 1) {
      _saveAndNavigate();
    } else {
      setState(() {
        _isGoingForward = true;
        _currentStep++;
      });
    }
  }

  // Called by the back arrow inside the question card header
  void _handleBack() {
    if (_currentStep == 0) {
      // Return to disease selection — fades back to disease phase
      setState(() => _isShowingQuestions = false);
    } else {
      setState(() {
        _isGoingForward = false;
        _currentStep--;
      });
    }
  }

  Future<void> _saveAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = PatientModel(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _gender!,
        height: double.parse(_heightController.text.trim()),
        weight: double.parse(_weightController.text.trim()),
        smoker: _smokes!,
        onMedication: _onMedication!,
        diseaseType: _selectedDisease!,
      );

      await PatientService().savePatientProfile(user.uid, profile);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to save your profile. Please try again.');
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // AnimatedSwitcher at the SafeArea level so both phases share the
      // same footprint — disease cards fade out, question card fades in.
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          // StackFit.expand ensures both phases fill the full available area
          // so the height never jumps during the fade transition.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: _isShowingQuestions
              ? _buildQuestionPhase(key: const ValueKey('questions'))
              : _buildDiseasePhase(key: const ValueKey('diseases')),
        ),
      ),
    );
  }

  // ── Phase 1 — Disease selection ───────────────────────────

  Widget _buildDiseasePhase({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's your condition?", style: AppTextStyles.heading1),
          const SizedBox(height: 8),
          Text(
            'Select your chronic condition to personalise your experience',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 28),
          ..._diseases.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DiseaseCard(
                emoji: d.emoji,
                title: d.title,
                subtitle: d.subtitle,
                isSelected: _selectedDisease == d.id,
                onTap: () => setState(() => _selectedDisease = d.id),
              ),
            ),
          ),
          const SizedBox(height: 32),
          NuvitaButton(
            label: 'Continue',
            onPressed: _selectedDisease != null ? _handleContinue : null,
          ),
        ],
      ),
    );
  }

  // ── Phase 2 — Question card ───────────────────────────────

  Widget _buildQuestionPhase({Key? key}) {
    final disease = _diseases.firstWhere((d) => d.id == _selectedDisease);
    final isLastStep = _currentStep == _totalSteps - 1;

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: QuestionCard(
        diseaseEmoji: disease.emoji,
        diseaseTitle: disease.title,
        currentStep: _currentStep,
        totalSteps: _totalSteps,
        onBack: _handleBack,
        stepContent: _buildStepContentAnimated(),
        buttonLabel: isLastStep ? 'Get Started' : 'Next',
        onNext: _handleNext,
        isLoading: _isLoading,
      ),
    );
  }

  // ── Step content with slide animation ────────────────────

  Widget _buildStepContentAnimated() {
    // Capture direction now so the transition builder closure uses
    // the value that was current when the step changed.
    final goingForward = _isGoingForward;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        final isEntering =
            (child.key as ValueKey<int>?)?.value == _currentStep;

        // Entering child slides in from right (forward) or left (backward).
        // Exiting child slides out to the opposite side.
        final begin = isEntering
            ? Offset(goingForward ? 1.0 : -1.0, 0)
            : Offset(goingForward ? -1.0 : 1.0, 0);

        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      // Stack clips overflow so slide-in widgets don't show outside the card
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: SizedBox.expand(
        key: ValueKey<int>(_currentStep),
        child: _buildCurrentStepContent(),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    return switch (_currentStep) {
      0 => _stepLayout(
          'What is your full name?',
          _styledTextField(
            _nameController,
            TextInputType.name,
            'Enter your full name',
          ),
        ),
      1 => _stepLayout(
          'How old are you?',
          _styledNumberField(_ageController, 'Age', 'years'),
        ),
      2 => _stepLayout('What is your gender?', _buildGenderOptions()),
      3 => _stepLayout(
          'What is your height?',
          _styledNumberField(_heightController, 'Height', 'cm'),
        ),
      4 => _stepLayout(
          'What is your weight?',
          _styledNumberField(_weightController, 'Weight', 'kg'),
        ),
      5 => _stepLayout('Do you smoke?', _buildSmokingOptions()),
      6 => _stepLayout('Are you on medication?', _buildMedicationOptions()),
      _ => const SizedBox.shrink(),
    };
  }

  // Generic layout: question text + input widget, scrollable
  Widget _stepLayout(String question, Widget input) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: AppTextStyles.heading1),
          const SizedBox(height: 28),
          input,
        ],
      ),
    );
  }

  // ── Option row builders ───────────────────────────────────

  Widget _buildGenderOptions() {
    return _buildOptionRow(
      label1: 'Male',
      icon1: Icons.male,
      label2: 'Female',
      icon2: Icons.female,
      selected: _gender,
      onSelect: (v) => setState(() => _gender = v),
    );
  }

  Widget _buildSmokingOptions() {
    return _buildOptionRow(
      label1: 'Yes',
      icon1: Icons.smoking_rooms_rounded,
      label2: 'No',
      icon2: Icons.smoke_free_rounded,
      selected: _smokes == null ? null : (_smokes! ? 'Yes' : 'No'),
      onSelect: (v) => setState(() => _smokes = v == 'Yes'),
    );
  }

  Widget _buildMedicationOptions() {
    return _buildOptionRow(
      label1: 'Yes',
      icon1: Icons.medication_rounded,
      label2: 'No',
      icon2: Icons.medication_liquid_rounded,
      selected: _onMedication == null ? null : (_onMedication! ? 'Yes' : 'No'),
      onSelect: (v) => setState(() => _onMedication = v == 'Yes'),
    );
  }

  Widget _buildOptionRow({
    required String label1,
    required IconData icon1,
    required String label2,
    required IconData icon2,
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    return Row(
      children: [
        Expanded(
          child: OptionCard(
            label: label1,
            icon: icon1,
            isSelected: selected == label1,
            onTap: () => onSelect(label1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OptionCard(
            label: label2,
            icon: icon2,
            isSelected: selected == label2,
            onTap: () => onSelect(label2),
          ),
        ),
      ],
    );
  }

  // ── Input field builders ──────────────────────────────────

  Widget _styledTextField(
    TextEditingController controller,
    TextInputType keyboardType,
    String hint,
  ) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.heading2,
      textInputAction: TextInputAction.done,
      decoration: _inputDecoration(hint: hint),
    );
  }

  Widget _styledNumberField(
    TextEditingController controller,
    String hint,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.heading2,
      textInputAction: TextInputAction.done,
      decoration: _inputDecoration(hint: hint, suffix: suffix),
    );
  }

  InputDecoration _inputDecoration({required String hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.heading2.copyWith(color: AppColors.divider),
      suffixText: suffix,
      suffixStyle: AppTextStyles.heading3.copyWith(color: AppColors.secondary),
      filled: true,
      fillColor: AppColors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

// ─── DiseaseCard — reusable selectable disease card ──────────────────────────

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
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.06),
              blurRadius: 8,
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
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            // Check icon fades in once the card is selected
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

// ─── OptionCard — reusable Yes/No and Male/Female card ────────────────────────

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 120,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? AppColors.primary : AppColors.secondary,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTextStyles.heading3.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QuestionCard — reusable question container widget ───────────────────────

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.diseaseEmoji,
    required this.diseaseTitle,
    required this.currentStep,
    required this.totalSteps,
    required this.stepContent,
    required this.onBack,
    required this.buttonLabel,
    required this.onNext,
    required this.isLoading,
  });

  final String diseaseEmoji;
  final String diseaseTitle;
  final int currentStep;
  final int totalSteps;
  final Widget stepContent;   // Animated step content passed from parent
  final VoidCallback onBack;
  final String buttonLabel;
  final VoidCallback onNext;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          // Expanded so the step content fills the space between
          // the header and the button at the bottom.
          Expanded(child: stepContent),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back arrow — goes to previous step or back to disease selection
              GestureDetector(
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$diseaseEmoji  $diseaseTitle',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: TextStyle(
                        color: AppColors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar — white track, white fill at varying opacity
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              backgroundColor: AppColors.white.withOpacity(0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.white),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: NuvitaButton(
        label: buttonLabel,
        onPressed: isLoading ? null : onNext,
        isLoading: isLoading,
      ),
    );
  }
}
