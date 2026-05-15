import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../auth/screens/login_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../emergency/screens/emergency_contacts_screen.dart';
import '../../../main.dart' show cancelDoctorNotificationListeners;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isGuest = false;
  String _name = '';
  String _patientId = '';
  String _gender = '';
  String _dob = '';
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isGuest = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data();
      final profile = data?['profile'] as Map<String, dynamic>?;
      setState(() {
        // Name may live at root (new registrations) or under 'profile' (onboarding path)
        _name = profile?['name'] as String? ?? data?['name'] as String? ?? '';
        _patientId = data?['patientId'] as String? ?? '';
        _gender = profile?['gender'] as String? ?? '';
        _dob = profile?['dob'] as String? ?? '';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _formatDob(String iso) {
    if (iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _copyPatientId() {
    Clipboard.setData(ClipboardData(text: _patientId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Patient ID copied to clipboard'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await NotificationService.cancelWellnessReminder();
      await NotificationService.cancelWeeklyHealthSummary();
      cancelDoctorNotificationListeners();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _signOut();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showPersonalInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Personal Info', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              _infoRow('Name', _name.isEmpty ? '—' : _name),
              _infoRow('Gender', _gender.isEmpty ? '—' : _gender),
              _infoRow('Date of Birth', _formatDob(_dob)),
              if (_patientId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Patient ID',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _patientId,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _copyPatientId,
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Profile editing coming soon.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // The send message sheet owns its own loading state via StatefulBuilder.
  // Using try/finally guarantees the spinner always resets, even on errors.
  void _showMessageDoctorSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool sending = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> send() async {
              if (_isGuest) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to message your doctor'),
                  ),
                );
                return;
              }

              final text = ctrl.text.trim();
              if (text.isEmpty) return;

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              setSheetState(() => sending = true);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('messages')
                    .add({
                  'text': text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'readByDoctor': false,
                  'patientName': _name.isEmpty ? 'Unknown' : _name,
                  'patientId': _patientId,
                }).timeout(const Duration(seconds: 10));
                ctrl.clear();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message sent to your doctor'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send message. Try again.'),
                    ),
                  );
                }
              } finally {
                if (ctx.mounted) setSheetState(() => sending = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Message Your Doctor', style: AppTextStyles.heading2),
                  const SizedBox(height: 6),
                  Text(
                    'Your message will be reviewed by your doctor.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Write your message here…',
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NuvitaButton(
                    label: 'Send Message',
                    onPressed: sending ? null : send,
                    isLoading: sending,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBugReportSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool sending = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> send() async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;

              setSheetState(() => sending = true);
              try {
                await FirebaseFirestore.instance
                    .collection('bugReports')
                    .add({
                  'text': text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'platform': 'mobile',
                }).timeout(const Duration(seconds: 10));
                ctrl.clear();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Bug report sent. Thank you!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send report. Try again.'),
                    ),
                  );
                }
              } finally {
                if (ctx.mounted) setSheetState(() => sending = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Report a Bug', style: AppTextStyles.heading2),
                  const SizedBox(height: 6),
                  Text(
                    'Help us improve Nuvita by describing the issue.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Describe the bug…',
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NuvitaButton(
                    label: 'Send Report',
                    onPressed: sending ? null : send,
                    isLoading: sending,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _recommendApp() {
    SharePlus.instance.share(
      ShareParams(
        text: 'I use Nuvita to manage my health! '
            'It helps me track medications, readings and appointments. '
            'Try it today!',
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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

    return _isGuest ? _buildGuestView() : _buildProfileView();
  }

  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text('Your Profile', style: AppTextStyles.heading1),
              const SizedBox(height: 10),
              Text(
                'Sign in to access your profile, health reports and appointments.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              NuvitaButton(
                label: 'Sign In',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 14),
              NuvitaButton(
                label: 'Create Account',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                ),
                isOutlined: true,
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final initials = _initials(_name.isEmpty ? '?' : _name);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name.isEmpty ? 'Unknown' : _name,
                      style: AppTextStyles.heading1,
                    ),
                    if (_patientId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ID: $_patientId',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ── Card 1 — Personal Info ──────────────────────────────────────
              _sectionCard(
                icon: Icons.person_outline_rounded,
                title: 'Personal Info',
                children: [
                  _tile(
                    leading: Icons.edit_outlined,
                    title: 'View Profile',
                    subtitle: 'Name, gender, date of birth',
                    onTap: _showPersonalInfoSheet,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Card 2 — Account & Backup ───────────────────────────────────
              _sectionCard(
                icon: Icons.backup_outlined,
                title: 'Account & Backup',
                children: [
                  _tile(
                    leading: Icons.download_outlined,
                    title: 'Export My Data',
                    subtitle: 'Download your health records',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Export feature coming soon'),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _tile(
                    leading: Icons.delete_outline_rounded,
                    title: 'Delete My Data',
                    subtitle: 'Remove all your health data',
                    titleColor: AppColors.error,
                    leadingColor: AppColors.error,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Delete Data?'),
                          content: const Text(
                            'For data deletion requests please contact support@nuvita.com',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Card 3 — Emergency ─────────────────────────────────────────
              _sectionCard(
                icon: Icons.emergency_rounded,
                iconColor: AppColors.error,
                title: 'Emergency',
                children: [
                  _tile(
                    leading: Icons.contact_phone_outlined,
                    title: 'Emergency Contacts',
                    subtitle: 'Add contacts for emergencies',
                    leadingColor: AppColors.error,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyContactsScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Card 4 — Support ────────────────────────────────────────────
              _sectionCard(
                icon: Icons.support_agent_outlined,
                title: 'Support',
                children: [
                  _tile(
                    leading: Icons.message_outlined,
                    title: 'Message Your Doctor',
                    subtitle: 'Send a message to your doctor',
                    onTap: _showMessageDoctorSheet,
                  ),
                  _divider(),
                  _tile(
                    leading: Icons.bug_report_outlined,
                    title: 'Report a Bug',
                    subtitle: 'Help us improve Nuvita',
                    onTap: _showBugReportSheet,
                  ),
                  _divider(),
                  _tile(
                    leading: Icons.share_outlined,
                    title: 'Recommend Nuvita',
                    subtitle: 'Share with friends and family',
                    onTap: _recommendApp,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Sign Out button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _signingOut ? null : _showSignOutDialog,
                    icon: _signingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : const Icon(
                            Icons.logout_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper builders ────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _tile({
    required IconData leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? leadingColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        leading,
        color: leadingColor ?? AppColors.primary,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.secondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondary,
        size: 20,
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
