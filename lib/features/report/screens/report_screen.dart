import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../health/services/health_reading_service.dart';
import '../../medication/services/medication_service.dart';
import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isGuest = false;

  String _name = '';
  String _diseaseType = 'other';
  int _readingsCount = 0;
  int _medsCount = 0;

  // Cached bytes so Preview and Share don't both trigger generation
  Uint8List? _cachedBytes;

  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart Condition',
    'other': 'General Monitoring',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isGuest = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final docFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final readingsFuture = HealthReadingService.getReadingsLastDays(uid, 30);
      final medsFuture = MedicationService.loadAll();

      final doc = await docFuture;
      final readings = await readingsFuture;
      final meds = await medsFuture;

      final profile =
          (doc.data())?['profile'] as Map<String, dynamic>?;

      setState(() {
        _name = profile?['name'] as String? ?? '';
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
        _readingsCount = readings.length;
        _medsCount = meds.length;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List?> _getBytes() async {
    if (_cachedBytes != null) return _cachedBytes;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final bytes =
        await ReportService.generateReport(uid, _name, _diseaseType);
    _cachedBytes = bytes;
    return bytes;
  }

  Future<void> _previewReport() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _getBytes();
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Failed to generate report. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareReport() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _getBytes();
      if (bytes == null) return;

      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Nuvita_Report_$dateStr.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Failed to generate report. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Health Report', style: AppTextStyles.heading2),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _isGuest
              ? _buildGuestMessage()
              : _buildContent(),
    );
  }

  Widget _buildGuestMessage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Create an account to generate your health report.',
          style: AppTextStyles.body.copyWith(color: AppColors.secondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final condition = _diseaseLabels[_diseaseType] ?? 'General Monitoring';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildSummaryCard(condition),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              NuvitaButton(
                label: 'Preview Report',
                onPressed: _isGenerating ? null : _previewReport,
                isLoading: _isGenerating,
                icon: Icons.visibility_outlined,
              ),
              const SizedBox(height: 12),
              NuvitaButton(
                label: 'Share with Doctor',
                onPressed: _isGenerating ? null : _shareReport,
                isOutlined: true,
                icon: Icons.share_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String condition) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Summary',
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          _summaryRow(Icons.person_outline, 'Patient', _name.isEmpty ? 'Unknown' : _name),
          _summaryRow(Icons.monitor_heart_outlined, 'Condition', condition),
          _summaryRow(Icons.date_range_outlined, 'Period', 'Last 30 days'),
          _summaryRow(
            Icons.bar_chart_outlined,
            'Readings',
            '$_readingsCount recorded',
          ),
          _summaryRow(
            Icons.medication_outlined,
            'Medications',
            '$_medsCount active',
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: AppTextStyles.label.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
