import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/care_services.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../onboarding/widgets/service_option_card.dart';

// Profile → My services. Same choices as onboarding; saving updates the
// profile, the sections Home and Tracking show and the scheduled reminders.
class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await CareServices.load();
    if (!mounted) return;
    setState(() {
      _selected = current;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      _showMessage('Please select at least one service', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await CareServices.save(
          FirebaseAuth.instance.currentUser?.uid, _selected);
    } catch (e) {
      debugPrint('MyServicesScreen: save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save your services. Please try again.',
          error: true);
      return;
    }

    // Turn reminders on or off to match the new selection
    try {
      await NotificationService.rescheduleAll();
    } catch (e) {
      debugPrint('MyServicesScreen: reminder update failed: $e');
    }

    if (!mounted) return;
    _showMessage('Your services have been updated');
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
        title: Text('My Services', style: AppTextStyles.heading3),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'Choose what Nuvita shows on Home and Tracking and '
                    'which reminders it sends.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      for (final service in serviceOptions)
                        ServiceOptionCard(
                          service: service,
                          selected: _selected.contains(service.id),
                          onTap: () => setState(() {
                            if (!_selected.remove(service.id)) {
                              _selected.add(service.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: NuvitaButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}
