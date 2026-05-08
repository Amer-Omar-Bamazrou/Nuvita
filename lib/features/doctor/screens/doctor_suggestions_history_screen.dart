import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';

class DoctorSuggestionsHistoryScreen extends StatefulWidget {
  final String doctorName;

  const DoctorSuggestionsHistoryScreen({
    super.key,
    required this.doctorName,
  });

  @override
  State<DoctorSuggestionsHistoryScreen> createState() =>
      _DoctorSuggestionsHistoryScreenState();
}

class _DoctorSuggestionsHistoryScreenState
    extends State<DoctorSuggestionsHistoryScreen> {
  final _service = DoctorService();

  bool _loading = true;
  List<Map<String, dynamic>> _suggestions = [];

  static const _primary = Color(0xFF004346);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data =
          await _service.getSentSuggestionsHistory(widget.doctorName);
      if (!mounted) return;
      setState(() {
        _suggestions = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('SuggestionsHistory: load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
          'Suggestions Sent',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _primary))
            : _suggestions.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _suggestions.length,
                    itemBuilder: (context, i) =>
                        _buildItem(_suggestions[i]),
                  ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> s) {
    final patientName = s['patientName'] as String? ?? 'Unknown';
    final patientId = s['patientId'] as String? ?? '—';
    final text = s['text'] as String? ?? '';
    final ts = s['timestamp'];

    String date = '—';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      date = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
          // Patient header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F0F0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  patientName.isNotEmpty
                      ? patientName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF172A3A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Patient ID badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                ),
              ),
              // Date
              Text(
                date,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          // Message body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.send_rounded, size: 14, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF172A3A),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_outlined,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No suggestions sent yet',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 6),
                Text(
                  'Messages you send to patients will appear here.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
