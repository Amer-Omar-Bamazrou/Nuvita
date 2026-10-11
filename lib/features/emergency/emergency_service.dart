import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/preferences_service.dart';

// SOS currently only records an alert that the care team sees in the doctor
// portal. It does not call emergency services or the user's emergency
// contacts, and the wording below must not suggest otherwise.
class EmergencyService {
  // The 10-second cancellation window exists so the user can abort a
  // panic tap before anything is recorded.
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
      } catch (e) {
        debugPrint('EmergencyService: profile fetch failed: $e');
      }
    }
  }

  // Returns true only when the alert document was written
  Future<bool> _logAlert({required bool cancelled}) async {
    if (_uid == null) return false;
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
      return true;
    } catch (e) {
      debugPrint('EmergencyService._logAlert: $e');
      return false;
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

  Future<void> _onCountdownComplete() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    final signedIn = _uid != null;
    final recorded = await _logAlert(cancelled: false);
    navigator.pop();
    if (!rootContext.mounted) return;
    _showAlertResultDialog(
      rootContext,
      recorded: recorded,
      signedIn: signedIn,
    );
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
            _uid == null
                ? 'You are not signed in, so no alert can be recorded. '
                    'Call your local emergency number if you need urgent help.'
                : 'An alert will be recorded for your care team in '
                    '$_secondsLeft seconds',
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

// ── Result dialog ────────────────────────────────────────────────────────────

void _showAlertResultDialog(
  BuildContext context, {
  required bool recorded,
  required bool signedIn,
}) {
  final String title;
  final String message;
  if (recorded) {
    title = 'Alert recorded';
    message = 'Your care team can see this alert in the Nuvita doctor portal. '
        'Nuvita does not call emergency services or your emergency contacts. '
        'If you need urgent help, call your local emergency number now.';
  } else if (!signedIn) {
    title = 'No alert sent';
    message = 'You are not signed in, so no alert was recorded and nobody '
        'was contacted. If you need urgent help, call your local emergency '
        'number now.';
  } else {
    title = 'Alert not recorded';
    message = 'We could not record the alert. Check your connection. '
        'If you need urgent help, call your local emergency number now.';
  }

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
              color: (recorded ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              recorded ? Icons.check_circle_rounded : Icons.error_rounded,
              color: recorded ? AppColors.success : AppColors.error,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Text(
        message,
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
