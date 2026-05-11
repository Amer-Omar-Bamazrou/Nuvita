import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import 'doctor_patient_detail_screen.dart';

class CriticalAlertsScreen extends StatelessWidget {
  final String doctorName;
  const CriticalAlertsScreen({super.key, required this.doctorName});

  @override
  Widget build(BuildContext context) {
    final service = DoctorService();
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.streamEmergencyAlertsToday(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF004346)),
            );
          }
          if (snapshot.hasError) {
            debugPrint('CriticalAlertsScreen stream error: ${snapshot.error}');
            return _buildEmpty();
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) return _buildEmpty();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _AlertCard(alert: alerts[i], doctorName: doctorName),
          );
        },
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
            'Emergency SOS alerts will appear\nhere in real time.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String doctorName;

  const _AlertCard({required this.alert, required this.doctorName});

  @override
  Widget build(BuildContext context) {
    final patientName = alert['patientName'] as String? ?? 'Unknown';
    final patientId = alert['patientId'] as String? ?? '';
    final patientUid = alert['patientUid'] as String? ?? '';
    final diseaseType = alert['diseaseType'] as String? ?? '';
    final triggerType = alert['triggerType'] as String? ?? '';
    final ts = alert['timestamp'];

    String dateLabel = '';
    String timeLabel = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateLabel =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final diseaseLabels = {
      'diabetes': 'Diabetes',
      'blood_pressure': 'Blood Pressure',
      'heart': 'Heart Condition',
    };

    final isManual = triggerType == 'manual';
    final hasDiseaseLabel = diseaseLabels.containsKey(diseaseType);

    return InkWell(
      onTap: patientUid.isEmpty
          ? null
          : () {
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
                    doctorName: doctorName,
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
                  // Name + time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (dateLabel.isNotEmpty)
                            Text(
                              dateLabel,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF172A3A),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Patient ID badge
                  if (patientId.isNotEmpty)
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
                  // Disease + trigger chips — only shown when meaningful
                  if (hasDiseaseLabel || triggerType.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (hasDiseaseLabel)
                          _Chip(
                            label: diseaseLabels[diseaseType]!,
                            bgColor: const Color(0xFFE0F0F0),
                            textColor: const Color(0xFF004346),
                          ),
                        if (triggerType.isNotEmpty)
                          _Chip(
                            label: isManual ? 'Manual SOS' : 'Critical Reading',
                            bgColor: isManual
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFFFF3E0),
                            textColor: isManual
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFFF6F00),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Chip(
      {required this.label,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
