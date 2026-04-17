import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/preferences_service.dart';
import '../../auth/screens/register_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../home/screens/main_shell.dart';

// ─── Local data classes ───────────────────────────────────────────────────────

class _GenderOption {
  final String label;
  final IconData icon;
  const _GenderOption({required this.label, required this.icon});
}

class _ServiceDef {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  const _ServiceDef({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Step index: 0=welcome, 1=firstName, 2=lastName, 3=gender, 4=dob,
  //            5=services, 6=account
  int _step = 0;
  bool _goingForward = true;
  bool _isSaving = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _gender;
  DateTime? _dob;
  final Set<String> _selectedServices = {};

  static const _genderOptions = [
    _GenderOption(label: 'Male', icon: Icons.male),
    _GenderOption(label: 'Female', icon: Icons.female),
    _GenderOption(label: 'Prefer not to say', icon: Icons.person),
  ];

  static const _services = [
    _ServiceDef(
      id: 'medications',
      icon: Icons.medication_rounded,
      iconColor: Color(0xFF1565C0),
      title: 'Medications',
      description: 'Get reminders and track your medication intakes',
    ),
    _ServiceDef(
      id: 'measurements',
      icon: Icons.monitor_heart_rounded,
      iconColor: Color(0xFF2E7D32),
      title: 'Measurements',
      description: 'Log health readings like blood pressure and blood sugar',
    ),
    _ServiceDef(
      id: 'activities',
      icon: Icons.directions_walk_rounded,
      iconColor: Color(0xFFE65100),
      title: 'Activities',
      description: 'Set reminders for walking, hydration and exercise',
    ),
    _ServiceDef(
      id: 'doctor_reports',
      icon: Icons.description_rounded,
      iconColor: Color(0xFF6A1B9A),
      title: 'Doctor Reports',
      description: 'Generate and share health reports with your doctor',
    ),
    _ServiceDef(
      id: 'emergency_alerts',
      icon: Icons.emergency_rounded,
      iconColor: Color(0xFFC62828),
      title: 'Emergency Alerts',
      description: 'Get alerted when readings reach dangerous levels',
    ),
    _ServiceDef(
      id: 'appointments',
      icon: Icons.calendar_month_rounded,
      iconColor: Color(0xFF00695C),
      title: 'Appointments',
      description: 'Never miss a doctor appointment again',
    ),
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    if (_step == 1 && _firstNameController.text.trim().isEmpty) {
      _showError('Please enter your first name');
      return false;
    }
    if (_step == 2 && _lastNameController.text.trim().isEmpty) {
      _showError('Please enter your last name');
      return false;
    }
    if (_step == 3 && _gender == null) {
      _showError('Please select your gender');
      return false;
    }
    if (_step == 4 && _dob == null) {
      _showError('Please select your date of birth');
      return false;
    }
    if (_step == 5 && _selectedServices.isEmpty) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();
    if (_isSaving || !_validateCurrentStep()) return;

    // Persist the onboarding data when leaving the services step
    if (_step == 5) {
      setState(() => _isSaving = true);
      await PreferencesService.saveOnboardingData(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender!,
        dob: _dob!,
        services: _selectedServices.toList(),
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

  // Navigating to register marks onboarding done first
  Future<void> _navigateToRegister() async {
    await PreferencesService.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // Navigating to login marks onboarding done first
  Future<void> _navigateToLogin() async {
    await PreferencesService.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
              // Save with empty services and move to account step
              await PreferencesService.saveOnboardingData(
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                gender: _gender!,
                dob: _dob!,
                services: [],
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

  void _showSkipAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Skip account creation?'),
        content: const Text(
          "Your data will only be stored on this device. If you uninstall the app your data will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await PreferencesService.setOnboardingComplete();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainShell()),
              );
            },
            child: const Text('Skip anyway'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? maxDate,
      firstDate: DateTime(1900),
      lastDate: maxDate,
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
            // Progress header — only shown on personal info steps 1–5
            if (_step >= 1 && _step <= 5) _buildStepHeader(),
            // Animated step content fills the remaining space
            Expanded(child: _buildAnimatedStep()),
          ],
        ),
      ),
    );
  }

  // ── Progress header ───────────────────────────────────────────────────────

  Widget _buildStepHeader() {
    // On step 1: 1 dot filled. On step 5: 5 dots filled.
    final filledCount = _step;
    final showSkip = _step == 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _goBack,
            child: Container(
              padding: const EdgeInsets.all(9),
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
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          // Progress dots — width animates from narrow to wide when filled
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
          // Fixed-width slot — holds Skip button on services step, empty otherwise
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
    // Capture direction here so the closure below uses the value from
    // this build pass, not a future one.
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
        children: [...previous, if (current != null) current],
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
      1 => _buildFirstNameStep(),
      2 => _buildLastNameStep(),
      3 => _buildGenderStep(),
      4 => _buildDobStep(),
      5 => _buildServicesStep(),
      6 => _buildAccountStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Step 1: Welcome ───────────────────────────────────────────────────────

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
              color: AppColors.primary.withOpacity(0.1),
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
            'Your smart health companion for chronic disease management',
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

  // ── Step 2: First Name ────────────────────────────────────────────────────

  Widget _buildFirstNameStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("What's your first name?", style: AppTextStyles.heading1),
                const SizedBox(height: 28),
                NuvitaTextField(
                  label: 'First Name',
                  hint: 'Enter your first name',
                  controller: _firstNameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(label: 'Next', onPressed: _goNext),
        ),
      ],
    );
  }

  // ── Step 3: Last Name ─────────────────────────────────────────────────────

  Widget _buildLastNameStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("What's your last name?", style: AppTextStyles.heading1),
                const SizedBox(height: 28),
                NuvitaTextField(
                  label: 'Last Name',
                  hint: 'Enter your last name',
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: NuvitaButton(label: 'Next', onPressed: _goNext),
        ),
      ],
    );
  }

  // ── Step 4: Gender ────────────────────────────────────────────────────────

  Widget _buildGenderStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("What's your gender?", style: AppTextStyles.heading1),
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
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.0 : 1.5,
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

  // ── Step 5: Date of Birth ─────────────────────────────────────────────────

  Widget _buildDobStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('When were you born?', style: AppTextStyles.heading1),
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
              color: AppColors.textDark.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
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
              Text("Let's set up your routine!", style: AppTextStyles.heading1),
              SizedBox(height: 6),
              Text('Select the services you want', style: AppTextStyles.bodySmall),
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

  Widget _buildServiceCard(_ServiceDef service) {
    final isSelected = _selectedServices.contains(service.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedServices.remove(service.id);
        } else {
          _selectedServices.add(service.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F4F4) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: service.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service.icon, color: service.iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: AppTextStyles.heading3.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.description,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle button: + becomes checkmark when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 2,
                ),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                color: isSelected ? AppColors.white : AppColors.secondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 7: Account Setup ─────────────────────────────────────────────────

  Widget _buildAccountStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Secure your data',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Create an account to back up your health data',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          NuvitaButton(label: 'Create Account', onPressed: _navigateToRegister),
          const SizedBox(height: 14),
          NuvitaButton(
            label: 'Sign In',
            onPressed: _navigateToLogin,
            isOutlined: true,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _showSkipAccountDialog,
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
