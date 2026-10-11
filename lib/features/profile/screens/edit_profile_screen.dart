import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/health/conditions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../disease/screens/disease_selection_screen.dart';
import '../../disease/services/conditions_service.dart';

// Edits name, gender and date of birth on /users/{uid}. The name is written
// both at the root (read by the doctor portal and registration) and under
// profile. Conditions are edited on DiseaseSelectionScreen and saved there.
// Pops with true when something was saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _gender;
  DateTime? _dob;
  PatientConditions _conditions = PatientConditions.none;

  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _changed = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final profile = data['profile'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _nameController.text =
            profile?['name'] as String? ?? data['name'] as String? ?? '';
        final gender = profile?['gender'] as String?;
        _gender = _genders.contains(gender) ? gender : null;
        _dob = DateTime.tryParse(profile?['dob'] as String? ?? '');
        _conditions = PatientConditions.fromProfile(profile);
        _loading = false;
      });
    } catch (e) {
      debugPrint('EditProfileScreen: load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _pickDob() async {
    final lastDate = DateTime.now().subtract(const Duration(days: 365 * 17));
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob != null && !_dob!.isAfter(lastDate)
          ? _dob!
          : DateTime(1990),
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
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _editConditions() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DiseaseSelectionScreen()),
    );
    final uid = _uid;
    if (saved != true || uid == null) return;
    _changed = true;
    try {
      final conditions = await ConditionsService.load(uid);
      if (mounted) setState(() => _conditions = conditions);
    } catch (e) {
      debugPrint('EditProfileScreen: reload conditions failed: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      _showMessage('Please select your gender', error: true);
      return;
    }
    if (_dob == null) {
      _showMessage('Please select your date of birth', error: true);
      return;
    }
    final uid = _uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final name = _nameController.text.trim();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'profile': {
          'name': name,
          'gender': _gender,
          'dob': _dob!.toIso8601String(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('EditProfileScreen: save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save your profile. Please try again.',
          error: true);
      return;
    }

    if (!mounted) return;
    _showMessage('Profile updated');
    Navigator.of(context).pop(true);
  }

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Conditions are saved on their own screen, so leaving returns whether
    // anything changed and Profile reloads
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text('Edit Profile', style: AppTextStyles.heading3),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _loadFailed
                ? _buildLoadError()
                : _buildForm(),
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
            Text("Couldn't load your profile",
                style: AppTextStyles.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            NuvitaButton(label: 'Retry', onPressed: _load, isOutlined: true),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NuvitaTextField(
              label: 'Full name',
              hint: 'e.g. Sarah Ahmed',
              controller: _nameController,
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 24),
            Text('Gender', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in _genders)
                  ChoiceChip(
                    label: Text(g),
                    selected: _gender == g,
                    onSelected: (_) => setState(() => _gender = g),
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: _gender == g
                          ? AppColors.primary
                          : AppColors.textDark,
                      fontWeight:
                          _gender == g ? FontWeight.w600 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: _gender == g
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                    backgroundColor: AppColors.white,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Date of birth', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            _pickerRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date of birth',
              value: _dob == null ? 'Select' : _formatDate(_dob!),
              onTap: _pickDob,
            ),
            const SizedBox(height: 24),
            Text('Conditions', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            _pickerRow(
              icon: Icons.monitor_heart_outlined,
              label: 'Your conditions',
              value: _conditions.summary,
              onTap: _editConditions,
            ),
            const SizedBox(height: 32),
            NuvitaButton(
              label: 'Save Changes',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
