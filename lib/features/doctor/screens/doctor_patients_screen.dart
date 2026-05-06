import 'package:flutter/material.dart';
import '../services/doctor_service.dart';
import 'doctor_patient_detail_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> patient) onSelectPatient;

  const DoctorPatientsScreen({super.key, required this.onSelectPatient});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _service = DoctorService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filtered = [];
  String _diseaseFilter = 'All';

  static const _diseaseOptions = [
    'All',
    'diabetes',
    'blood_pressure',
    'heart',
    'other',
  ];

  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart',
    'other': 'General',
  };

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    try {
      final patients = await _service.getAllPatients();
      if (!mounted) return;
      setState(() {
        _allPatients = patients;
        _filtered = patients;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allPatients.where((p) {
        final name = _patientName(p).toLowerCase();
        final id = (p['patientId'] as String? ?? '').toLowerCase();
        final disease = _patientDisease(p);
        final matchesSearch =
            query.isEmpty || name.contains(query) || id.contains(query);
        final matchesDisease =
            _diseaseFilter == 'All' || disease == _diseaseFilter;
        return matchesSearch && matchesDisease;
      }).toList();
    });
  }

  String _patientName(Map<String, dynamic> p) {
    return p['name'] as String? ??
        (p['profile'] as Map?)?['name'] as String? ??
        'Unknown';
  }

  String _patientDisease(Map<String, dynamic> p) {
    return (p['profile'] as Map?)?['diseaseType'] as String? ?? 'other';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF004346)))
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or Patient ID…',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF004346)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Disease filter
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _diseaseFilter,
              items: _diseaseOptions
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d == 'All' ? 'All Types' : _diseaseLabels[d]!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _diseaseFilter = v);
                  _applyFilters();
                }
              },
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF172A3A)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Spacer(),
          Text(
            '${_filtered.length} patient${_filtered.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF004346),
              side: const BorderSide(color: Color(0xFF004346)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _filtered.map(_buildPatientCard).toList(),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = _patientName(patient);
    final patientId = patient['patientId'] as String? ?? '—';
    final disease = _patientDisease(patient);
    final diseaseLabel = _diseaseLabels[disease] ?? 'General';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoctorPatientDetailScreen(patient: patient),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 240,
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
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF004346),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF172A3A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Patient ID badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004346),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          patientId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Disease type chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                diseaseLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF004346),
                  fontWeight: FontWeight.w500,
                ),
              ),
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
          Icon(Icons.people_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
