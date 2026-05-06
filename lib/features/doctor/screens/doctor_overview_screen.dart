import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';

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
  List<Map<String, dynamic>> _recentReadings = [];
  Map<String, String> _patientNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final patients = await _service.getAllPatients();
      final critical = await _service.getCriticalReadingsCount();
      final lowMeds = await _service.getLowMedicationsCount();
      final suggestions =
          await _service.getTotalSuggestionsCount(widget.doctorName);
      final recent = await _service.getRecentReadingsAllPatients();

      // Build uid → name map for the recent readings list
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
        _recentReadings = recent;
        _patientNames = names;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
    final stats = [
      _StatCard(
        label: 'Total Patients',
        value: '$_totalPatients',
        icon: Icons.people_rounded,
        iconColor: const Color(0xFF004346),
        iconBg: const Color(0xFFE0F0F0),
        onTap: widget.onViewPatients,
      ),
      _StatCard(
        label: 'Critical Today',
        value: '$_criticalToday',
        icon: Icons.warning_rounded,
        iconColor: const Color(0xFFD32F2F),
        iconBg: const Color(0xFFFFEBEE),
      ),
      _StatCard(
        label: 'Low Medications',
        value: '$_lowMedications',
        icon: Icons.medication_rounded,
        iconColor: const Color(0xFFFF6F00),
        iconBg: const Color(0xFFFFF3E0),
      ),
      _StatCard(
        label: 'Suggestions Sent',
        value: '$_totalSuggestions',
        icon: Icons.send_rounded,
        iconColor: const Color(0xFF2E7D32),
        iconBg: const Color(0xFFE8F5E9),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatCard s) {
    return InkWell(
      onTap: s.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
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
        child: Row(
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
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172A3A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172A3A),
                  ),
                ),
                const Spacer(),
                Text(
                  'Last 10 readings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
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
      color: index.isOdd ? const Color(0xFFF9F9F9) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Patient avatar
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
          // Patient name + metric
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
          const SizedBox(width: 12),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
    Color bg;
    Color fg;
    switch (status) {
      case 'Normal':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'Warning':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFFF6F00);
        break;
      case 'Critical':
      case 'High':
      case 'Low':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFD32F2F);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
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
