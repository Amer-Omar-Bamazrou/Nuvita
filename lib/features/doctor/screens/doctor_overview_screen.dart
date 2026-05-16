import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import 'doctor_suggestions_history_screen.dart';
import 'doctor_messages_screen.dart';
import 'critical_alerts_screen.dart';
import 'deleted_patients_screen.dart';

class DoctorOverviewScreen extends StatefulWidget {
  final String doctorName;
  final VoidCallback onViewPatients;

  const DoctorOverviewScreen({
    super.key,
    required this.doctorName,
    required this.onViewPatients,
  });

  @override
  State<DoctorOverviewScreen> createState() => _DoctorOverviewScreenState();
}

class _DoctorOverviewScreenState extends State<DoctorOverviewScreen> {
  final _service = DoctorService();

  bool _loading = true;
  int _totalPatients = 0;
  int _criticalToday = 0;
  int _lowMedications = 0;
  int _totalSuggestions = 0;
  int _deactivated = 0;
  int _unreadMessages = 0;
  List<Map<String, dynamic>> _recentReadings = [];
  Map<String, String> _patientNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> patients = [];
    int critical = 0;
    int lowMeds = 0;
    int suggestions = 0;
    int deactivated = 0;
    int unreadMsgs = 0;
    List<Map<String, dynamic>> recent = [];

    try {
      patients = await _service.getAllPatients();
    } catch (e) {
      debugPrint('Overview: getAllPatients failed: $e');
    }

    try {
      final alerts = await _service.getEmergencyAlertsToday();
      critical = alerts.length;
    } catch (e) {
      debugPrint('Overview: getEmergencyAlertsToday failed: $e');
    }

    try {
      lowMeds = await _service.getLowMedicationsCount();
    } catch (e) {
      debugPrint('Overview: getLowMedicationsCount failed: $e');
    }

    try {
      suggestions =
          await _service.getTotalSuggestionsCount(widget.doctorName);
    } catch (e) {
      debugPrint('Overview: getTotalSuggestionsCount failed: $e');
    }

    try {
      final deactivatedList = await _service.getDeactivatedPatients();
      deactivated = deactivatedList.length;
    } catch (e) {
      debugPrint('Overview: getDeactivatedPatients failed: $e');
    }

    try {
      unreadMsgs = await _service.getUnreadMessagesCount();
    } catch (e) {
      debugPrint('Overview: getUnreadMessagesCount failed: $e');
    }

    try {
      recent = await _service.getRecentReadingsAllPatients();
    } catch (e) {
      debugPrint('Overview: getRecentReadingsAllPatients failed: $e');
    }

    final names = <String, String>{};
    for (final p in patients) {
      final uid = p['uid'] as String;
      final name = p['name'] as String? ??
          (p['profile'] as Map?)?['name'] as String? ??
          'Unknown';
      names[uid] = name;
    }

    if (!mounted) return;
    setState(() {
      _totalPatients = patients.length;
      _criticalToday = critical;
      _lowMedications = lowMeds;
      _totalSuggestions = suggestions;
      _deactivated = deactivated;
      _unreadMessages = unreadMsgs;
      _recentReadings = recent;
      _patientNames = names;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004346)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCards(),
            const SizedBox(height: 28),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(_StatCard(
          label: 'Total Patients',
          value: '$_totalPatients',
          icon: Icons.people_rounded,
          iconColor: const Color(0xFF004346),
          iconBg: const Color(0xFFE0F0F0),
          onTap: widget.onViewPatients,
        )),
        // Real-time stream so the count updates the moment an SOS fires
        StreamBuilder<int>(
          stream: _service.streamCriticalAlertsCount(),
          initialData: _criticalToday,
          builder: (context, snap) => _buildStatCard(_StatCard(
            label: 'Critical Today',
            value: '${snap.data ?? 0}',
            icon: Icons.warning_rounded,
            iconColor: const Color(0xFFD32F2F),
            iconBg: const Color(0xFFFFEBEE),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CriticalAlertsScreen(doctorName: widget.doctorName),
                ),
              );
            },
          )),
        ),
        _buildStatCard(_StatCard(
          label: 'Low Medications',
          value: '$_lowMedications',
          icon: Icons.medication_rounded,
          iconColor: const Color(0xFFFF6F00),
          iconBg: const Color(0xFFFFF3E0),
        )),
        _buildStatCard(_StatCard(
          label: 'Suggestions Sent',
          value: '$_totalSuggestions',
          icon: Icons.send_rounded,
          iconColor: const Color(0xFF2E7D32),
          iconBg: const Color(0xFFE8F5E9),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorSuggestionsHistoryScreen(
                    doctorName: widget.doctorName),
              ),
            );
            _loadData();
          },
        )),
        _buildStatCard(_StatCard(
          label: 'Deactivated',
          value: '$_deactivated',
          icon: Icons.person_off_rounded,
          iconColor: const Color(0xFF757575),
          iconBg: const Color(0xFFF5F5F5),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DeletedPatientsScreen(doctorName: widget.doctorName),
              ),
            );
            _loadData();
          },
        )),
        _buildMessagesCard(),
      ],
    );
  }

  Widget _buildMessagesCard() {
    return _buildStatCard(_StatCard(
      label: 'Unread Messages',
      value: '$_unreadMessages',
      icon: Icons.message_rounded,
      iconColor: const Color(0xFF1565C0),
      iconBg: const Color(0xFFE3F2FD),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorMessagesScreen(),
          ),
        );
        _loadData();
      },
    ));
  }

  Widget _buildStatCard(_StatCard s) {
    return InkWell(
      onTap: s.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.iconColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              s.value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172A3A),
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6E7A82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Recent Patient Activity',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172A3A),
              ),
            ),
          ),
          const Divider(height: 1),
          if (_recentReadings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No readings yet',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ...(_recentReadings.asMap().entries.map((e) =>
                _buildReadingRow(e.key, e.value))),
        ],
      ),
    );
  }

  Widget _buildReadingRow(int index, Map<String, dynamic> reading) {
    final patientUid = reading['patientUid'] as String? ?? '';
    final patientName = _patientNames[patientUid] ?? 'Unknown';
    final metric = reading['metricType'] as String? ?? '';
    final value = reading['value'];
    final unit = reading['unit'] as String? ?? '';
    final status = reading['status'] as String? ?? 'Logged';
    final ts = reading['timestamp'];
    final time = ts is Timestamp ? _timeAgo(ts.toDate()) : '';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFEEEEEE))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F0F0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF004346),
                fontSize: 14,
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
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF172A3A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$metric  •  $value $unit',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6E7A82)),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
          const SizedBox(width: 12),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9AA3AB)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Normal':
        color = const Color(0xFF2E7D32);
        break;
      case 'Warning':
        color = const Color(0xFFFF6F00);
        break;
      case 'Critical':
      case 'High':
      case 'Low':
        color = const Color(0xFFD32F2F);
        break;
      default:
        color = const Color(0xFF6E7A82);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });
}
