import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconly/iconly.dart';

class DoctorSettingsScreen extends StatefulWidget {
  final String doctorEmail;
  final String doctorName;
  final VoidCallback onSignOut;

  const DoctorSettingsScreen({
    super.key,
    required this.doctorEmail,
    required this.doctorName,
    required this.onSignOut,
  });

  @override
  State<DoctorSettingsScreen> createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  bool _changingPassword = false;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String? _passwordError;
  String? _passwordSuccess;

  static const _primary = Color(0xFF004346);

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passwordError = 'New passwords do not match');
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: widget.doctorEmail,
        password: _currentPassCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassCtrl.text);

      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      setState(() {
        _passwordSuccess = 'Password updated successfully';
        _changingPassword = false;
      });
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _passwordError = 'Current password is incorrect';
        _changingPassword = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAccountCard(),
          const SizedBox(height: 20),
          _buildPasswordCard(),
          const SizedBox(height: 20),
          _buildSignOutCard(),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return _SettingsCard(
      title: 'Account',
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: widget.doctorName.isNotEmpty
                ? widget.doctorName
                : '—',
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.doctorEmail,
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: 'Doctor',
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return _SettingsCard(
      title: 'Change Password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _passwordField(_currentPassCtrl, 'Current Password'),
          const SizedBox(height: 12),
          _passwordField(_newPassCtrl, 'New Password'),
          const SizedBox(height: 12),
          _passwordField(_confirmPassCtrl, 'Confirm New Password'),
          const SizedBox(height: 16),
          if (_passwordError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _passwordError!,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFD32F2F)),
              ),
            ),
          if (_passwordSuccess != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _passwordSuccess!,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2E7D32)),
              ),
            ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _changingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: _changingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : const Text('Update Password',
                      style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutCard() {
    return _SettingsCard(
      title: 'Session',
      child: Row(
        children: [
          const Icon(IconlyLight.logout,
              size: 18, color: Color(0xFFD32F2F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign Out',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF172A3A)),
                ),
                const Text(
                  'You will be returned to the login screen',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9AA3AB)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: widget.onSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
              side: const BorderSide(color: Color(0xFFD32F2F)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
            ),
            child: const Text('Sign Out',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF172A3A),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB0B8BD)),
          const SizedBox(width: 14),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9AA3AB)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF172A3A)),
          ),
        ],
      ),
    );
  }
}
