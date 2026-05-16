import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/preferences_service.dart';

class EmergencyService {
  // The 10-second cancellation window exists so the user can abort a
  // panic tap before anything is actually sent. This mirrors how real
  // emergency systems (e.g. iPhone SOS) give a brief grace period.
  static void showEmergencyFlow(
    BuildContext context, {
    String triggerType = 'manual',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CountdownDialog(triggerType: triggerType),
    );
  }
}

// ── Countdown dialog ──────────────────────────────────────────────────────────

class _CountdownDialog extends StatefulWidget {
  final String triggerType;
  const _CountdownDialog({required this.triggerType});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _secondsLeft = 10;
  Timer? _timer;

  String? _uid;
  String _patientName = 'Unknown';
  String _diseaseType = 'other';
  String _patientId = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startCountdown();
  }

  Future<void> _loadUserData() async {
    _uid = FirebaseAuth.instance.currentUser?.uid;

    final first = await PreferencesService.getFirstName();
    final last = await PreferencesService.getLastName();
    final parts = [first, last].where((s) => s != null && s.isNotEmpty);
    _patientName = parts.isNotEmpty ? parts.join(' ') : 'Unknown';

    if (_uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .get();
        final data = doc.data() ?? {};
        final profile = data['profile'] as Map<String, dynamic>?;
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
        _patientId = data['patientId'] as String? ?? '';
      } catch (_) {}
    }
  }

  Future<void> _logAlert({required bool cancelled}) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('alerts')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'triggerType': widget.triggerType,
        'cancelled': cancelled,
        'patientName': _patientName,
        'patientId': _patientId,
        'diseaseType': _diseaseType,
      });
    } catch (e) {
      debugPrint('EmergencyService._logAlert: $e');
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        timer.cancel();
        _onCountdownComplete();
      }
    });
  }

  void _onCountdownComplete() {
    if (!mounted) return;
    _logAlert(cancelled: false);
    Navigator.of(context).pop();
    _showAlertSentDialog(context);
  }

  void _cancel() {
    _timer?.cancel();
    _logAlert(cancelled: true);
    Navigator.of(context).pop();
    debugPrint('False alarm cancelled');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Emergency Alert',
        style: AppTextStyles.heading3.copyWith(color: AppColors.error),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Help will be notified in $_secondsLeft seconds',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '$_secondsLeft',
            style: AppTextStyles.heading1.copyWith(
              color: AppColors.error,
              fontSize: 72,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap CANCEL to stop',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _cancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Alert sent confirmation dialog ───────────────────────────────────────────

void _showAlertSentDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Alert Sent',
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Text(
        'Help has been notified (simulated).\nStay calm, assistance is on the way.',
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    ),
  );
}
