import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class EmergencyService {
  // The 10-second cancellation window exists so the user can abort a
  // panic tap before anything is actually sent. This mirrors how real
  // emergency systems (e.g. iPhone SOS) give a brief grace period.
  static void showEmergencyFlow(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CountdownDialog(),
    );
  }
}

// ── Countdown dialog ──────────────────────────────────────────────────────────

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog();

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _secondsLeft = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
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
    // Close countdown dialog then show the confirmation dialog
    Navigator.of(context).pop();
    _showAlertSentDialog(context);
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
    // Silence on cancellation — no snackbar, no action, nothing sent
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
              color: AppColors.error.withOpacity(0.7),
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
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Alert Sent',
        style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
        textAlign: TextAlign.center,
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
            onPressed: () => Navigator.of(context).pop(),
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
