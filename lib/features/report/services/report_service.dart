import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';
import '../../medication/models/medication_model.dart';
import '../../medication/services/medication_service.dart';

class ReportService {
  static final _primary = PdfColor.fromHex('004346');
  static final _textDark = PdfColor.fromHex('172A3A');
  static final _cardBg = PdfColor.fromHex('EAF7F8');
  static final _dividerColor = PdfColor.fromHex('B0D8DC');

  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart Condition',
    'other': 'General Monitoring',
  };

  static Future<Uint8List> generateReport(
    String uid,
    String name,
    String diseaseType,
  ) async {
    final readingsFuture = HealthReadingService.getReadingsLastDays(uid, 30);
    final medsFuture = MedicationService.loadAll();

    final readings = await readingsFuture;
    final medications = await medsFuture;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 20),
          _buildPatientSummary(name, diseaseType),
          pw.SizedBox(height: 24),
          _buildReadingsSection(readings),
          pw.SizedBox(height: 24),
          _buildMedicationsSection(medications),
          pw.SizedBox(height: 24),
          _buildDisclaimer(),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Nuvita',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.Text(
              'Health Report',
              style: pw.TextStyle(fontSize: 16, color: _textDark),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: _dividerColor),
      ],
    );
  }

  static pw.Widget _buildPatientSummary(String name, String diseaseType) {
    final condition = _diseaseLabels[diseaseType] ?? 'General Monitoring';
    final now = DateTime.now();
    final period =
        '${_fmt(now.subtract(const Duration(days: 30)))} — ${_fmt(now)}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _dividerColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _summaryRow('Patient Name', name.isEmpty ? 'Unknown' : name),
          pw.SizedBox(height: 6),
          _summaryRow('Condition', condition),
          pw.SizedBox(height: 6),
          _summaryRow('Report Period', period),
          pw.SizedBox(height: 6),
          _summaryRow('Generated', _fmt(now)),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: _textDark,
            fontSize: 10,
          ),
        ),
        pw.Text(value, style: pw.TextStyle(color: _textDark, fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildReadingsSection(List<HealthReading> readings) {
    final widgets = <pw.Widget>[
      pw.Text(
        'Health Readings',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
      pw.SizedBox(height: 10),
    ];

    if (readings.isEmpty) {
      widgets.add(pw.Text(
        'No readings recorded in the last 30 days.',
        style: pw.TextStyle(color: _textDark, fontSize: 10),
      ));
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: widgets,
      );
    }

    final grouped = <String, List<HealthReading>>{};
    for (final r in readings) {
      grouped.putIfAbsent(r.metricType, () => []).add(r);
    }

    for (final entry in grouped.entries) {
      widgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _readableName(entry.key),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _textDark,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildTable(entry.value),
          pw.SizedBox(height: 6),
          _buildStats(entry.value),
          pw.SizedBox(height: 16),
        ],
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static pw.Widget _buildTable(List<HealthReading> readings) {
    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 9,
    );
    final cellStyle = pw.TextStyle(color: _textDark, fontSize: 9);

    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(text, style: style),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _dividerColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primary),
          children: ['Date', 'Value', 'Unit', 'Status']
              .map((h) => cell(h, headerStyle))
              .toList(),
        ),
        ...readings.map(
          (r) => pw.TableRow(children: [
            cell(_fmt(r.timestamp), cellStyle),
            cell(r.value.toStringAsFixed(1), cellStyle),
            cell(r.unit, cellStyle),
            cell(r.status, cellStyle),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _buildStats(List<HealthReading> readings) {
    final values = readings.map((r) => r.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final high = values.reduce((a, b) => a > b ? a : b);
    final low = values.reduce((a, b) => a < b ? a : b);
    final unit = readings.first.unit;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _statChip('Average', '${avg.toStringAsFixed(1)} $unit'),
          _statChip('Highest', '${high.toStringAsFixed(1)} $unit'),
          _statChip('Lowest', '${low.toStringAsFixed(1)} $unit'),
        ],
      ),
    );
  }

  static pw.Widget _statChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _textDark)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMedicationsSection(List<MedicationModel> medications) {
    final widgets = <pw.Widget>[
      pw.Text(
        'Medications',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
      pw.SizedBox(height: 10),
    ];

    if (medications.isEmpty) {
      widgets.add(pw.Text(
        'No medications recorded.',
        style: pw.TextStyle(color: _textDark, fontSize: 10),
      ));
    } else {
      for (final med in medications) {
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _dividerColor, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            '${med.name}  —  ${med.dosage}  —  ${med.frequency}',
            style: pw.TextStyle(color: _textDark, fontSize: 10),
          ),
        ));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _dividerColor, width: 0.5),
        ),
      ),
      child: pw.Text(
        'This report is generated by Nuvita and is not a substitute for professional medical advice. '
        'Always consult your doctor.',
        style: pw.TextStyle(
          fontSize: 8,
          fontStyle: pw.FontStyle.italic,
          color: PdfColor(0.5, 0.5, 0.5),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Converts camelCase metric names to readable Title Case
  static String _readableName(String metricType) {
    final spaced = metricType.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(0)!}',
    );
    if (spaced.isEmpty) return metricType;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}
