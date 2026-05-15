import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../doctor/services/patient_suggestion_service.dart';

class SuggestionsPanelScreen extends StatefulWidget {
  // Kept for backward compat — home_screen.dart passes these
  final String diseaseType;
  final Map<String, double?> currentReadings;

  const SuggestionsPanelScreen({
    super.key,
    required this.diseaseType,
    required this.currentReadings,
  });

  @override
  State<SuggestionsPanelScreen> createState() =>
      _SuggestionsPanelScreenState();
}

class _SuggestionsPanelScreenState extends State<SuggestionsPanelScreen> {
  bool _isGuest = false;
  final PatientSuggestionService _service = PatientSuggestionService();
  final Set<String> _expandedIds = {};
  // Cached once so StreamBuilder doesn't resubscribe on every setState rebuild
  Stream<List<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _isGuest = FirebaseAuth.instance.currentUser == null;
    if (!_isGuest) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _stream = _service.listenToAllSuggestions(uid);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: AppTextStyles.heading2),
        centerTitle: true,
      ),
      body: _isGuest ? _buildGuestState() : _buildStream(),
    );
  }

  // ── Stream ─────────────────────────────────────────────────────────────────

  Widget _buildStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snap.hasError) {
          debugPrint('Notifications stream error: ${snap.error}');
          return _buildEmptyState(isError: true);
        }
        final messages = snap.data ?? [];
        debugPrint('Notifications: ${messages.length} message(s) loaded');
        if (messages.isEmpty) return _buildEmptyState();
        return _buildList(uid, messages);
      },
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(String uid, List<Map<String, dynamic>> messages) {
    final unreadCount =
        messages.where((m) => !(m['read'] as bool? ?? false)).length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      itemCount: messages.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : Divider(
              height: 1,
              indent: 82,
              endIndent: 20,
              color: AppColors.divider.withValues(alpha: 0.5),
            ),
      itemBuilder: (context, i) {
        if (i == 0) return _buildHeader(unreadCount);
        return _buildTile(uid, messages[i - 1]);
      },
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text('Doctor Messages', style: AppTextStyles.heading3),
          const Spacer(),
          if (unreadCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'All caught up',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Notification tile ──────────────────────────────────────────────────────

  Widget _buildTile(String uid, Map<String, dynamic> data) {
    final id = data['id'] as String;
    final text = data['text'] as String? ?? '';
    final doctorName = data['doctorName'] as String? ?? 'Your Doctor';
    final isRead = data['read'] as bool? ?? false;
    final timestamp = data['timestamp'] as Timestamp?;
    final isExpanded = _expandedIds.contains(id);

    return InkWell(
      onTap: () async {
        setState(() {
          if (isExpanded) {
            _expandedIds.remove(id);
          } else {
            _expandedIds.add(id);
          }
        });
        if (!isRead) {
          try {
            await _service.markAsRead(uid, id);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to mark as read')),
              );
            }
          }
        }
      },
      child: Container(
        color: isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.03),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor avatar with unread dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isRead
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    color: isRead ? AppColors.secondary : AppColors.primary,
                    size: 22,
                  ),
                ),
                if (!isRead)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          doctorName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timestamp != null)
                        Text(
                          _service.timeAgo(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isRead ? Colors.grey : AppColors.primary,
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    maxLines: isExpanded ? null : 2,
                    overflow: isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isRead
                          ? Colors.grey.shade600
                          : AppColors.textDark.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────────

  Widget _buildEmptyState({bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.wifi_off_rounded
                    : Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isError ? 'Could not load messages' : 'No notifications yet',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isError
                  ? 'Check your connection and try again.'
                  : 'Messages from your doctor\nwill appear here.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 24),
            Text('Sign in to see notifications',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Doctor messages and health alerts\nwill appear here once you sign in.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
