import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import '../data/medicine_library.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final String doctorName;

  const DoctorPatientDetailScreen({
    super.key,
    required this.patient,
    required this.doctorName,
  });

  @override
  State<DoctorPatientDetailScreen> createState() =>
      _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState
    extends State<DoctorPatientDetailScreen> {
  final _service = DoctorService();

  bool _loadingReadings = true;
  bool _loadingMeds = true;
  List<Map<String, dynamic>> _readings = [];
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _suggestions = [];

  static const _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'As needed',
    'Weekly',
  ];

  static List<String> _timesForFrequency(String freq) {
    switch (freq) {
      case 'Twice daily':
        return ['08:00', '20:00'];
      case 'Three times daily':
        return ['08:00', '14:00', '20:00'];
      case 'Weekly':
        return ['08:00'];
      case 'As needed':
        return [];
      default:
        return ['08:00'];
    }
  }

  final _suggestionCtrl = TextEditingController();
  bool _sendingSuggestion = false;

  static const _primary = Color(0xFF004346);

  String get _uid => widget.patient['uid'] as String? ?? '';
  String get _patientName =>
      widget.patient['name'] as String? ??
      (widget.patient['profile'] as Map?)?['name'] as String? ??
      'Unknown';

  String _formatDob(String iso) {
    if (iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadReadings();
    _loadMedications();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _suggestionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    setState(() => _loadingReadings = true);
    try {
      final r = await _service.getPatientReadings(_uid);
      if (!mounted) return;
      setState(() {
        _readings = r;
        _loadingReadings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReadings = false);
    }
  }

  Future<void> _loadMedications() async {
    setState(() => _loadingMeds = true);
    try {
      final m = await _service.getPatientMedications(_uid);
      if (!mounted) return;
      setState(() {
        _medications = m;
        _loadingMeds = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMeds = false);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('suggestions')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
      if (!mounted) return;
      setState(() {
        _suggestions =
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
  }

  // Opens a dialog to edit a medication. Using a dialog instead of an inline
  // form avoids DropdownButtonFormField overlay conflicts on Flutter Web.
  void _showEditMedDialog(Map<String, dynamic> med) {
    final medId = med['id'] as String;
    final nameCtrl =
        TextEditingController(text: med['name'] as String? ?? '');
    final dosageCtrl =
        TextEditingController(text: med['dosage'] as String? ?? '');
    final pillsCtrl =
        TextEditingController(text: med['pillsRemaining']?.toString() ?? '');

    final current = med['frequency'] as String? ?? 'Once daily';
    String selectedFreq =
        _frequencies.contains(current) ? current : 'Once daily';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Edit Medication',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172A3A)),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _dialogField(nameCtrl, 'Medication name')),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogField(dosageCtrl, 'Dosage')),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedFreq,
                  items: _frequencies
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedFreq = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    labelStyle: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF172A3A)),
                ),
                const SizedBox(height: 12),
                _dialogField(pillsCtrl, 'Pills remaining (optional)',
                    numeric: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _service.updateMedication(_uid, medId, {
                  'name': nameCtrl.text.trim(),
                  'dosage': dosageCtrl.text.trim(),
                  'frequency': selectedFreq,
                  'times': _timesForFrequency(selectedFreq),
                  'pillsRemaining': int.tryParse(pillsCtrl.text),
                });
                _loadMedications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      dosageCtrl.dispose();
      pillsCtrl.dispose();
    });
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint, {
    bool numeric = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Future<void> _sendSuggestion() async {
    final text = _suggestionCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingSuggestion = true);
    try {
      await _service.sendSuggestion(
        _uid,
        text,
        widget.doctorName,
        patientName: _patientName,
        patientId: widget.patient['patientId'] as String? ?? '',
      );
      _suggestionCtrl.clear();
      await _loadSuggestions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suggestion sent'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      debugPrint('sendSuggestion error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
    if (!mounted) return;
    setState(() => _sendingSuggestion = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172A3A),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          _patientName,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column — 40%
            Flexible(
              flex: 4,
              child: Column(
                children: [
                  _buildPersonalInfo(),
                  const SizedBox(height: 16),
                  _buildMeasurementCards(),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right column — 60%
            Flexible(
              flex: 6,
              child: Column(
                children: [
                  _buildMedicationsSection(),
                  const SizedBox(height: 16),
                  _buildReadingsSection(),
                  const SizedBox(height: 16),
                  _buildSuggestionsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left column ───────────────────────────────────────────────────────────

  Widget _buildPersonalInfo() {
    final profile =
        widget.patient['profile'] as Map<String, dynamic>? ?? {};
    final patientId = widget.patient['patientId'] as String? ?? '—';
    final email = widget.patient['email'] as String? ?? '—';
    final diseaseType = profile['diseaseType'] as String? ?? 'other';
    final gender = profile['gender'] as String? ?? '—';
    final dobRaw = profile['dob'] as String? ?? '';
    final dob = _formatDob(dobRaw);
    final createdAt = widget.patient['createdAt'];
    String memberSince = '—';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      memberSince = '${dt.day}/${dt.month}/${dt.year}';
    }

    final diseaseLabels = {
      'diabetes': 'Diabetes',
      'blood_pressure': 'Blood Pressure',
      'heart': 'Heart Condition',
      'other': 'General Monitoring',
    };

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Personal Information'),
          const SizedBox(height: 14),
          _InfoRow('Patient ID', patientId, mono: true),
          _InfoRow('Email', email),
          _InfoRow('Gender', gender),
          _InfoRow('Date of Birth', dob),
          _InfoRow('Condition',
              diseaseLabels[diseaseType] ?? 'General Monitoring'),
          _InfoRow('Member Since', memberSince),
        ],
      ),
    );
  }

  Widget _buildMeasurementCards() {
    if (_loadingReadings) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: CircularProgressIndicator(color: _primary)),
        ),
      );
    }

    final profile =
        widget.patient['profile'] as Map<String, dynamic>? ?? {};
    final diseaseType = profile['diseaseType'] as String? ?? 'other';

    // Find latest value for each metric
    Map<String, Map<String, dynamic>> latest = {};
    for (final r in _readings) {
      final metric = r['metricType'] as String? ?? '';
      if (!latest.containsKey(metric)) latest[metric] = r;
    }

    List<_MetricDef> metrics;
    switch (diseaseType) {
      case 'blood_pressure':
        metrics = [
          _MetricDef('bloodPressureSystolic', 'Systolic BP', 'mmHg'),
          _MetricDef('bloodPressureDiastolic', 'Diastolic BP', 'mmHg'),
        ];
        break;
      case 'diabetes':
        metrics = [
          _MetricDef('bloodSugar', 'Blood Sugar', 'mg/dL'),
          _MetricDef('weight', 'Weight', 'kg'),
        ];
        break;
      case 'heart':
        metrics = [
          _MetricDef('heartRate', 'Heart Rate', 'bpm'),
          _MetricDef('weight', 'Weight', 'kg'),
        ];
        break;
      default:
        metrics = [
          _MetricDef('bloodSugar', 'Blood Sugar', 'mg/dL'),
          _MetricDef('heartRate', 'Heart Rate', 'bpm'),
        ];
    }

    return Column(
      children: metrics.map((m) {
        final data = latest[m.metricType];
        final value = data?['value']?.toString() ?? '—';
        final status = data?['status'] as String? ?? '—';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172A3A),
                            ),
                          ),
                          if (value != '—') ...[
                            const SizedBox(width: 4),
                            Text(m.unit,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (status != '—') _StatusBadge(status: status),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Right column ──────────────────────────────────────────────────────────

  Widget _buildMedicationsSection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle('Medications'),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAssignMedicationSheet,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Assign',
                  style: TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingMeds)
            const Center(
                child: CircularProgressIndicator(color: _primary))
          else if (_medications.isEmpty)
            Text('No medications recorded.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500))
          else
            ..._medications.map(_buildMedRow),
        ],
      ),
    );
  }

  void _showAssignMedicationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AssignMedicationSheet(
        onAssign: (data) async {
          try {
            await _service.addMedication(_uid, data);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Medication assigned successfully'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
            _loadMedications();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to assign medication')),
            );
          }
        },
      ),
    );
  }

  Widget _buildMedRow(Map<String, dynamic> med) {
    final pills = med['pillsRemaining'] as int?;
    final isLow = pills != null && pills <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      med['name'] as String? ?? '—',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF172A3A)),
                    ),
                    const SizedBox(width: 8),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Low Supply',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFF6F00),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${med['dosage'] ?? ''} · ${med['frequency'] ?? ''}'
                  '${pills != null ? ' · $pills pills left' : ''}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditMedDialog(med),
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: Colors.grey.shade500,
            tooltip: 'Edit',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsSection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Recent Readings'),
          const SizedBox(height: 14),
          if (_loadingReadings)
            const Center(
                child: CircularProgressIndicator(color: _primary))
          else if (_readings.isEmpty)
            Text('No readings recorded.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500))
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3, child: _TableHeader('Date')),
                  Expanded(
                      flex: 3, child: _TableHeader('Metric')),
                  Expanded(
                      flex: 2, child: _TableHeader('Value')),
                  Expanded(
                      flex: 2, child: _TableHeader('Status')),
                ],
              ),
            ),
            ..._readings.asMap().entries.map((e) =>
                _buildReadingRow(e.key, e.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingRow(int index, Map<String, dynamic> r) {
    final ts = r['timestamp'];
    String date = '—';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      date =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final metric = r['metricType'] as String? ?? '—';
    final value = r['value']?.toString() ?? '—';
    final unit = r['unit'] as String? ?? '';
    final status = r['status'] as String? ?? 'Logged';

    return Container(
      color: index.isOdd
          ? const Color(0xFFF9F9F9)
          : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(date,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              flex: 3,
              child: Text(metric,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              flex: 2,
              child: Text('$value $unit',
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              flex: 2,
              child: _StatusBadge(status: status)),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Send Suggestion'),
          const SizedBox(height: 14),
          TextField(
            controller: _suggestionCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Write a health suggestion for this patient…',
              hintStyle: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _sendingSuggestion ? null : _sendSuggestion,
              icon: _sendingSuggestion
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send',
                  style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent suggestions',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._suggestions.map(_buildSuggestionItem),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> s) {
    final ts = s['timestamp'];
    String time = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      time = '${dt.day}/${dt.month}/${dt.year}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF004346).withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: Color(0xFF004346)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s['text'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF172A3A)),
            ),
          ),
          const SizedBox(width: 8),
          Text(time,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF172A3A),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _InfoRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF172A3A),
                fontWeight: mono ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: mono ? 1.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF508991),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
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

class _MetricDef {
  final String metricType;
  final String label;
  final String unit;
  const _MetricDef(this.metricType, this.label, this.unit);
}

// ── Assign Medication bottom sheet ────────────────────────────────────────────

class _AssignMedicationSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> data) onAssign;
  const _AssignMedicationSheet({required this.onAssign});

  @override
  State<_AssignMedicationSheet> createState() =>
      _AssignMedicationSheetState();
}

class _AssignMedicationSheetState extends State<_AssignMedicationSheet> {
  static const _primary = Color(0xFF004346);

  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _pillsCtrl = TextEditingController();

  static const _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'As needed',
    'Weekly',
  ];

  String _selectedFrequency = 'Once daily';
  List<Medicine> _filtered = medicineLibrary;
  Medicine? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    _pillsCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? medicineLibrary
          : medicineLibrary
              .where((m) =>
                  m.name.toLowerCase().contains(query) ||
                  m.category.toLowerCase().contains(query))
              .toList();
    });
  }

  void _selectMedicine(Medicine med) {
    setState(() {
      _selected = med;
      _nameCtrl.text = med.name;
      _dosageCtrl.text = med.defaultDosage;
      _selectedFrequency = _frequencies.contains(med.defaultFrequency)
          ? med.defaultFrequency
          : 'Once daily';
    });
  }

  List<String> _timesForFrequency(String freq) {
    switch (freq) {
      case 'Twice daily':
        return ['08:00', '20:00'];
      case 'Three times daily':
        return ['08:00', '14:00', '20:00'];
      case 'Weekly':
        return ['08:00'];
      case 'As needed':
        return [];
      default:
        return ['08:00'];
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();
    if (name.isEmpty || dosage.isEmpty) return;

    setState(() => _saving = true);

    final data = {
      'name': name,
      'dosage': dosage,
      'frequency': _selectedFrequency,
      'times': _timesForFrequency(_selectedFrequency),
      'startDate': Timestamp.now(),
      'notes': _notesCtrl.text.trim(),
      'pillsRemaining': int.tryParse(_pillsCtrl.text),
      'pillsPerDose': 1,
      'lowSupplyNotified': false,
      'reminderEnabled': false,
    };

    await widget.onAssign(data);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                const Text(
                  'Assign Medication',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172A3A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search medicines by name or category…',
                      hintStyle: TextStyle(
                          fontSize: 13, color: Colors.grey.shade400),
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Medicine list (max 200px scrollable)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No medicines found',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final med = _filtered[i];
                              final isSelected = _selected == med;
                              return InkWell(
                                onTap: () => _selectMedicine(med),
                                child: Container(
                                  color: isSelected
                                      ? _primary.withOpacity(0.06)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? _primary
                                                    : const Color(
                                                        0xFF172A3A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${med.category} · ${med.defaultDosage} · ${med.type}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: _primary,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Form
                  Row(
                    children: [
                      Expanded(child: _field(_nameCtrl, 'Medication name')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_dosageCtrl, 'Dosage')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequency,
                    items: _frequencies
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedFrequency = v);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      labelStyle: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_pillsCtrl, 'Pills remaining (optional)',
                              numeric: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_notesCtrl, 'Notes (optional)')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text(
                              'Assign Medication',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool numeric = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(fontSize: 12, color: Colors.grey.shade400),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
