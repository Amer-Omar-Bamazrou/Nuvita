import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';

class DoctorMessagesScreen extends StatefulWidget {
  const DoctorMessagesScreen({super.key});

  @override
  State<DoctorMessagesScreen> createState() => _DoctorMessagesScreenState();
}

class _DoctorMessagesScreenState extends State<DoctorMessagesScreen> {
  static const _primary = Color(0xFF004346);

  final _service = DoctorService();
  List<Map<String, dynamic>>? _messages;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final msgs = await _service.getPatientMessages();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DoctorMessagesScreen error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172A3A),
        elevation: 0,
        title: const Text(
          'Patient Messages',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _hasError
              ? _buildEmpty(isError: true)
              : _messages == null || _messages!.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildList(_messages!),
                    ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> messages) {
    final unreadCount =
        messages.where((m) => !(m['readByDoctor'] as bool? ?? false)).length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      itemCount: messages.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : Divider(
              height: 1,
              indent: 80,
              endIndent: 20,
              color: const Color(0xFFEEEEEE),
            ),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'All Messages',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172A3A),
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary,
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
                  ),
              ],
            ),
          );
        }
        return _buildMessageTile(messages[i - 1]);
      },
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final patientUid = data['patientUid'] as String;
    final text = data['text'] as String? ?? '';
    final patientName = data['patientName'] as String? ?? 'Unknown';
    final patientId = data['patientId'] as String? ?? '';
    final isRead = data['readByDoctor'] as bool? ?? false;
    final timestamp = data['timestamp'] as Timestamp?;

    final initials = patientName.isNotEmpty ? patientName[0].toUpperCase() : '?';
    String timeLabel = '';
    if (timestamp != null) {
      final dt = timestamp.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeLabel = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeLabel = '${diff.inHours}h ago';
      } else {
        timeLabel = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    return Container(
      color: isRead ? Colors.transparent : _primary.withValues(alpha: 0.03),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(0xFFE0F0F0)
                      : _primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF5F5F5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: const Color(0xFF172A3A),
                            ),
                          ),
                          if (patientId.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                patientId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isRead ? Colors.grey : _primary,
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isRead
                        ? const Color(0xFF6E7A82)
                        : const Color(0xFF172A3A),
                  ),
                ),
                if (!isRead) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await _service.markMessageAsRead(patientUid, id);
                          _load();
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Failed to mark as read')),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Mark as read',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF004346).withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError
                  ? Icons.wifi_off_rounded
                  : Icons.message_outlined,
              size: 40,
              color: const Color(0xFF004346).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isError ? 'Could not load messages' : 'No patient messages yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF172A3A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? 'Check your connection and try again.'
                : 'Messages sent by patients\nwill appear here.',
            style: TextStyle(fontSize: 13, color: const Color(0xFF6E7A82)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
