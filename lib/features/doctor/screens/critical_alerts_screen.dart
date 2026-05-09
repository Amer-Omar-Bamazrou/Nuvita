import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import 'doctor_patient_detail_screen.dart';

class CriticalAlertsScreen extends StatefulWidget {
  final String doctorName;
  const CriticalAlertsScreen({super.key, required this.doctorName});

  @override
  State<CriticalAlertsScreen> createState() => _CriticalAlertsScreenState();
}

class _CriticalAlertsScreenState extends State<CriticalAlertsScreen> {
  final _service = DoctorService();
  bool _loading = true;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final alerts = await _service.getEmergencyAlertsToday();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('CriticalAlertsScreen: $e');
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
          'Critical Alerts Today',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004346)),
            )
          : _alerts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _buildAlertCard(_alerts[i]),
                  ),
                ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final patientName = alert['patientName'] as String? ?? 'Unknown';
    final patientId = alert['patientId'] as String? ?? '';
    final patientUid = alert['patientUid'] as String? ?? '';
    final diseaseType = alert['diseaseType'] as String? ?? 'other';
    final triggerType = alert['triggerType'] as String? ?? 'manual';
    final ts = alert['timestamp'];

    String timeLabel = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeLabel = '${diff.inMinutes}m ago';
      } else {
        timeLabel =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    final diseaseLabels = {
      'diabetes': 'Diabetes',
      'blood_pressure': 'Blood Pressure',
      'heart': 'Heart Condition',
      'other': 'General',
    };

    final isManual = triggerType == 'manual';

    return InkWell(
      onTap: patientUid.isEmpty
          ? null
          : () {
              // Build a minimal patient map to open detail screen
              final patientData = {
                'uid': patientUid,
                'name': patientName,
                'patientId': patientId,
                'profile': {'diseaseType': diseaseType},
              };
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorPatientDetailScreen(
                    patient: patientData,
                    doctorName: widget.doctorName,
                  ),
                ),
              );
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          border: Border(
            left: BorderSide(
              color: isManual
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFFFF6F00),
              width: 4,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172A3A),
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (patientId.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF004346),
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
                        const SizedBox(width: 6),
                      ],
                      // Disease chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          diseaseLabels[diseaseType] ?? 'General',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF004346),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Trigger type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isManual
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isManual ? 'Manual SOS' : 'Critical Reading',
                          style: TextStyle(
                            fontSize: 11,
                            color: isManual
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFFF6F00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF004346).withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: const Color(0xFF2E7D32).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No critical alerts today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF172A3A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency SOS alerts and critical\nreadings will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
