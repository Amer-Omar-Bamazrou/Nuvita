import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/preferences_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../home/screens/main_shell.dart';
import '../widgets/service_option_card.dart';
import '../../../core/health/conditions.dart';
import '../../disease/screens/disease_selection_screen.dart';

// ─── Local data classes ───────────────────────────────────────────────────────

class _GenderOption {
  final String label;
  final IconData icon;
  const _GenderOption({required this.label, required this.icon});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Steps: 0=welcome, 1=intro, 2=name(combined), 3=gender, 4=dob,
  //        5=conditions, 6=services, 7=account
  int _step = 0;
  bool _goingForward = true;
  bool _isSaving = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _gender;
  DateTime? _dob;
  final Set<String> _selectedServices = {};
  Set<Condition> _selectedConditions = {};

  static const _genderOptions = [
    _GenderOption(label: 'Male', icon: Icons.person_rounded),
    _GenderOption(label: 'Female', icon: Icons.person_rounded),
    _GenderOption(label: 'Prefer not to say', icon: Icons.person_rounded),
  ];

  static const _services = serviceOptions;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    if (_step == 2) {
      if (_firstNameController.text.trim().isEmpty) {
        _showError('Please enter your first name');
        return false;
      }
      if (_lastNameController.text.trim().isEmpty) {
        _showError('Please enter your last name');
        return false;
      }
    }
    if (_step == 3 && _gender == null) {
      _showError('Please select your gender');
      return false;
    }
    if (_step == 4 && _dob == null) {
      _showError('Please select your date of birth');
      return false;
    }
    if (_step == 5 && _selectedConditions.isEmpty) {
      _showError('Please select at least one condition, or Other');
      return false;
    }
    if (_step == 6 && _selectedServices.isEmpty) {
      _showError('Please select at least one service');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();
    if (_isSaving || !_validateCurrentStep()) return;

    // Persist onboarding data when leaving the services step
    if (_step == 6) {
      setState(() => _isSaving = true);
      await PreferencesService.saveOnboardingData(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender!,
        dob: _dob!,
        services: _selectedServices.toList(),
        conditions: _selectedConditions.map((c) => c.id).toList(),
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
    }

    setState(() {
      _goingForward = true;
      _step++;
    });
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      setState(() {
        _goingForward = false;
        _step--;
      });
    }
  }

  Future<void> _navigateToLogin() async {
    await PreferencesService.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _skipToLogin() async {
    await PreferencesService.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _skipToGuest() async {
    await PreferencesService.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showSkipServicesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Skip for now?'),
        content: const Text(
          'You can update your preferences from your profile settings later.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_gender == null || _dob == null) return;
              await PreferencesService.saveOnboardingData(
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                gender: _gender!,
                dob: _dob!,
                services: [],
                conditions: _selectedConditions.map((c) => c.id).toList(),
              );
              if (!mounted) return;
              setState(() {
                _goingForward = true;
                _step++;
              });
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue selecting'),
          ),
        ],
      ),
    );
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final lastDate = DateTime.now().subtract(const Duration(days: 365 * 17));
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1930),
      lastDate: lastDate,
      helpText: 'SELECT YOUR DATE OF BIRTH',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress header shown only on personal info steps (name through services)
            if (_step >= 2 && _step <= 6) _buildStepHeader(),
            Expanded(child: _buildAnimatedStep()),
          ],
        ),
      ),
    );
  }

  // ── Progress header ───────────────────────────────────────────────────────

  Widget _buildStepHeader() {
    // step 2 → 1 dot filled, step 6 → 5 dots filled
    final filledCount = _step - 1;
    final showSkip = _step == 6;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goBack,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < filledCount;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: filled ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            width: 56,
            child: showSkip
                ? TextButton(
                    onPressed: _showSkipServicesDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.secondary,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── AnimatedSwitcher with slide transition ────────────────────────────────

  Widget _buildAnimatedStep() {
    final goingForward = _goingForward;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final isEntering = (child.key as ValueKey<int>?)?.value == _step;
        final begin = isEntering
            ? Offset(goingForward ? 1.0 : -1.0, 0)
            : Offset(goingForward ? -1.0 : 1.0, 0);
        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        );
      },
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [...previous, ?current],
      ),
      child: SizedBox.expand(
        key: ValueKey<int>(_step),
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => _buildWelcomeStep(),
      1 => _buildIntroStep(),
      2 => _buildNameStep(),
      3 => _buildGenderStep(),
      4 => _buildDobStep(),
      5 => _buildConditionsStep(),
      6 => _buildServicesStep(),
      7 => _buildAccountStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Step 0: Welcome ───────────────────────────────────────────────────────

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
              size: 50,
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'Welcome to Nuvita',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text(
            'Your health in focus with Nuvita, tracks your daily progress and stay on top of your medications on a daily basis.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          NuvitaButton(label: 'Get Started', onPressed: _goNext),
        ],
      ),
    );
  }

  // ── Step 1: Introduction ──────────────────────────────────────────────────

  Widget _buildIntroStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFF004346),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'Your Health Companion',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'In Nuvita we will manage your health, track your medications, measurements and daily habits so you can live a better and healthier life',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          NuvitaButton(label: 'Get Started', onPressed: _goNext),
        ],
      ),
    );
  }

  // ── Step 2: Name (combined first + last) ──────────────────────────────────

  Widget _buildNameStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your Name", style: AppTextStyles.heading1),
                const SizedBox(height: 28),
                NuvitaTextField(
                  label: 'First Name',
                  hint: 'Insert your first name',
                  controller: _firstNameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                NuvitaTextField(
                  label: 'Last Name',
                  hint: 'Insert your last name',
                  controller: _lastNameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: NuvitaButton(label: 'Next', onPressed: _goNext),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: GestureDetector(
            onTap: _skipToLogin,
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 3: Gender ────────────────────────────────────────────────────────

  Widget _buildGenderStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your gender?", style: AppTextStyles.heading1),
                const SizedBox(height: 28),
                ..._genderOptions.map(_buildGenderCard),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(
            label: 'Next',
            onPressed: _gender != null ? _goNext : null,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCard(_GenderOption option) {
    final isSelected = _gender == option.label;
    return GestureDetector(
      onTap: () => setState(() => _gender = option.label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.0 : 1.5,
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
            Icon(
              option.icon,
              color: isSelected ? AppColors.primary : AppColors.secondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: AppTextStyles.heading3.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                ),
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

  // ── Step 4: Date of Birth ─────────────────────────────────────────────────

  Widget _buildDobStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date of Birth?', style: AppTextStyles.heading1),
                const SizedBox(height: 28),
                _buildDobCard(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(
            label: 'Next',
            onPressed: _dob != null ? _goNext : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDobCard() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _dob != null ? AppColors.primary : AppColors.divider,
            width: _dob != null ? 2.0 : 1.5,
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Birth', style: AppTextStyles.label),
                  const SizedBox(height: 4),
                  Text(
                    _dob == null
                        ? 'Select your date of birth'
                        : _formatDate(_dob!),
                    style: _dob == null
                        ? AppTextStyles.bodySmall
                        : AppTextStyles.heading3.copyWith(fontSize: 17),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 5: Conditions ────────────────────────────────────────────────────

  Widget _buildConditionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Your conditions', style: AppTextStyles.heading1),
              SizedBox(height: 6),
              Text(
                'Select all that apply so we can show the right readings first',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConditionSelector(
              selected: _selectedConditions,
              onChanged: (next) => setState(() => _selectedConditions = next),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(
            label: 'Continue',
            onPressed: _selectedConditions.isNotEmpty ? _goNext : null,
          ),
        ),
      ],
    );
  }

  // ── Step 6: Service Preferences ───────────────────────────────────────────

  Widget _buildServicesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Set up preferences!", style: AppTextStyles.heading1),
              SizedBox(height: 6),
              Text('Select desired services to get started', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _services.length,
            itemBuilder: (_, i) => _buildServiceCard(_services[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(
            label: 'Continue',
            onPressed: _selectedServices.isNotEmpty ? _goNext : null,
            isLoading: _isSaving,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceOption service) {
    final isSelected = _selectedServices.contains(service.id);
    return ServiceOptionCard(
      service: service,
      selected: isSelected,
      onTap: () => setState(() {
        if (isSelected) {
          _selectedServices.remove(service.id);
        } else {
          _selectedServices.add(service.id);
        }
      }),
    );
  }

  // ── Step 7: Secure Your Data ──────────────────────────────────────────────

  Widget _buildAccountStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Ready to get started?',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in to protect and sync your health data',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          NuvitaButton(label: 'Sign In', onPressed: _navigateToLogin),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _skipToGuest,
            child: const Text(
              'Skip for now →',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
