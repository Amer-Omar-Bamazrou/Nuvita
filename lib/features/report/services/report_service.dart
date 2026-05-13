import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../charts/models/metric_thresholds.dart';
import '../../health/models/health_reading.dart';
import '../../health/services/health_reading_service.dart';
import '../../medication/models/medication_model.dart';
import '../../medication/services/medication_service.dart';

class ReportService {
  static final _primary = PdfColor.fromHex('004346');
  static final _textDark = PdfColor.fromHex('172A3A');
  static final _cardBg = PdfColor.fromHex('EAF7F8');
  static final _dividerColor = PdfColor.fromHex('B0D8DC');

  // Chart colours
  static final _chartLine = PdfColor.fromHex('004346');
  static final _chartLineSecondary = PdfColor.fromHex('508991');
  static final _chartGrid = PdfColor.fromHex('DDDDDD');
  static final _chartAxisText = PdfColor.fromHex('666666');
  static const _zoneNormal = PdfColor(0.3, 0.69, 0.31, 0.12);
  static const _zoneWarning = PdfColor(1.0, 0.6, 0.0, 0.10);

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

    // Collect diastolic data for BP dual chart
    final diastolicReadings = grouped['diastolic'];

    for (final entry in grouped.entries) {
      final metricType = entry.key;

      widgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _readableName(metricType),
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
          pw.SizedBox(height: 8),
          _buildMetricChart(
            entry.value,
            _readableName(metricType),
            metricType,
            secondaryReadings:
                metricType == 'systolic' ? diastolicReadings : null,
          ),
          pw.SizedBox(height: 16),
        ],
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── Chart drawing ─────────────────────────────────────────────────────────

  static pw.Widget _buildMetricChart(
    List<HealthReading> data,
    String metricName,
    String metricType, {
    List<HealthReading>? secondaryReadings,
  }) {
    if (data.length < 2) {
      return pw.SizedBox.shrink();
    }

    // Sort ascending by timestamp
    final sorted = List<HealthReading>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    List<HealthReading>? sortedSecondary;
    if (secondaryReadings != null && secondaryReadings.isNotEmpty) {
      sortedSecondary = List<HealthReading>.from(secondaryReadings)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // Y range
    var minY = sorted.map((r) => r.value).reduce(min);
    var maxY = sorted.map((r) => r.value).reduce(max);
    if (sortedSecondary != null) {
      minY = min(minY, sortedSecondary.map((r) => r.value).reduce(min));
      maxY = max(maxY, sortedSecondary.map((r) => r.value).reduce(max));
    }

    // Thresholds
    final (normalMin, normalMax) = MetricThresholds.getNormalRange(metricType);
    final (_, warningMax) = MetricThresholds.getWarningRange(metricType);
    final hasZones = normalMin > 0 || normalMax > 0;
    if (hasZones) {
      minY = min(minY, normalMin);
      maxY = max(maxY, warningMax);
    }

    // Padding
    final yPad = (maxY - minY) * 0.1;
    minY = (minY - yPad).clamp(0, double.infinity);
    maxY = maxY + yPad;

    final title = sortedSecondary != null
        ? '$metricName — Last 30 Days'
        : '$metricName — Last 30 Days';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(
          height: 150,
          child: pw.CustomPaint(
            size: const PdfPoint(double.infinity, 150),
            painter: (canvas, size) => _paintChart(
              canvas,
              size,
              sorted,
              minY,
              maxY,
              metricType,
              normalMin,
              normalMax,
              warningMax,
              hasZones,
              secondary: sortedSecondary,
            ),
          ),
        ),
        if (sortedSecondary != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              children: [
                _chartLegendItem(_chartLine, 'Systolic'),
                pw.SizedBox(width: 16),
                _chartLegendItem(_chartLineSecondary, 'Diastolic'),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _chartLegendItem(PdfColor color, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 14, height: 2, color: color),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7, color: _chartAxisText),
        ),
      ],
    );
  }

  static void _paintChart(
    PdfGraphics canvas,
    PdfPoint size,
    List<HealthReading> data,
    double minY,
    double maxY,
    String metricType,
    double normalMin,
    double normalMax,
    double warningMax,
    bool hasZones, {
    List<HealthReading>? secondary,
  }) {
    const leftPad = 32.0;
    const bottomPad = 16.0;
    const topPad = 4.0;
    const rightPad = 8.0;

    final chartW = size.x - leftPad - rightPad;
    final chartH = size.y - bottomPad - topPad;
    final yRange = maxY - minY;
    if (yRange <= 0 || chartW <= 0 || chartH <= 0) return;

    double xPos(int i) => leftPad + (i / (data.length - 1)) * chartW;
    double yPos(double val) =>
        bottomPad + ((val - minY) / yRange) * chartH;

    // Zone bands
    if (hasZones) {
      // Normal zone
      final nLo = yPos(normalMin).clamp(bottomPad, bottomPad + chartH);
      final nHi = yPos(normalMax).clamp(bottomPad, bottomPad + chartH);
      if (nHi > nLo) {
        canvas
          ..setFillColor(_zoneNormal)
          ..drawRect(leftPad, nLo, chartW, nHi - nLo)
          ..fillPath();
      }
      // Warning zone
      final wLo = yPos(normalMax).clamp(bottomPad, bottomPad + chartH);
      final wHi = yPos(warningMax).clamp(bottomPad, bottomPad + chartH);
      if (wHi > wLo) {
        canvas
          ..setFillColor(_zoneWarning)
          ..drawRect(leftPad, wLo, chartW, wHi - wLo)
          ..fillPath();
      }
    }

    // Horizontal grid lines (5 lines)
    canvas.setStrokeColor(_chartGrid);
    canvas.setLineWidth(0.3);
    for (int i = 0; i <= 4; i++) {
      final y = bottomPad + (i / 4) * chartH;
      canvas.drawLine(leftPad, y, leftPad + chartW, y);
    }
    canvas.strokePath();

    // Chart border
    canvas
      ..setStrokeColor(_chartGrid)
      ..setLineWidth(0.5)
      ..drawRect(leftPad, bottomPad, chartW, chartH)
      ..strokePath();

    // Y axis labels
    for (int i = 0; i <= 4; i++) {
      final val = minY + (i / 4) * yRange;
      final y = bottomPad + (i / 4) * chartH;
      _drawText(canvas, val.toStringAsFixed(0), leftPad - 4, y - 3,
          _chartAxisText, 6,
          align: 'right');
    }

    // X axis date labels (show ~5 evenly spaced)
    final xLabelCount = min(5, data.length);
    for (int i = 0; i < xLabelCount; i++) {
      final idx =
          xLabelCount <= 1 ? 0 : (i * (data.length - 1) ~/ (xLabelCount - 1));
      final x = xPos(idx);
      final dt = data[idx].timestamp;
      final label = '${dt.day}/${dt.month}';
      _drawText(canvas, label, x, bottomPad - 10, _chartAxisText, 6);
    }

    // Primary line + dots
    _drawDataLine(canvas, data, xPos, yPos, _chartLine, 1.5);
    _drawDataDots(canvas, data, xPos, yPos, _chartLine, 2.0);

    // Secondary line + dots (BP diastolic)
    if (secondary != null && secondary.isNotEmpty) {
      // Map secondary points to primary x-axis by date matching
      final secMapped = <int, double>{};
      for (final s in secondary) {
        for (int i = 0; i < data.length; i++) {
          if (_sameDay(data[i].timestamp, s.timestamp)) {
            secMapped[i] = s.value;
            break;
          }
        }
      }
      if (secMapped.isNotEmpty) {
        final indices = secMapped.keys.toList()..sort();
        // Draw line
        canvas
          ..setStrokeColor(_chartLineSecondary)
          ..setLineWidth(1.2);
        for (int j = 0; j < indices.length; j++) {
          final x = xPos(indices[j]);
          final y = yPos(secMapped[indices[j]]!);
          if (j == 0) {
            canvas.moveTo(x, y);
          } else {
            canvas.lineTo(x, y);
          }
        }
        canvas.strokePath();
        // Draw dots
        for (final idx in indices) {
          final x = xPos(idx);
          final y = yPos(secMapped[idx]!);
          canvas
            ..setFillColor(_chartLineSecondary)
            ..drawEllipse(x, y, 1.5, 1.5)
            ..fillPath();
        }
      }
    }
  }

  static void _drawDataLine(
    PdfGraphics canvas,
    List<HealthReading> data,
    double Function(int) xPos,
    double Function(double) yPos,
    PdfColor color,
    double width,
  ) {
    canvas
      ..setStrokeColor(color)
      ..setLineWidth(width);
    for (int i = 0; i < data.length; i++) {
      final x = xPos(i);
      final y = yPos(data[i].value);
      if (i == 0) {
        canvas.moveTo(x, y);
      } else {
        canvas.lineTo(x, y);
      }
    }
    canvas.strokePath();
  }

  static void _drawDataDots(
    PdfGraphics canvas,
    List<HealthReading> data,
    double Function(int) xPos,
    double Function(double) yPos,
    PdfColor color,
    double radius,
  ) {
    canvas.setFillColor(color);
    for (int i = 0; i < data.length; i++) {
      final x = xPos(i);
      final y = yPos(data[i].value);
      canvas.drawEllipse(x, y, radius, radius);
    }
    canvas.fillPath();
  }

  static void _drawText(
    PdfGraphics canvas,
    String text,
    double x,
    double y,
    PdfColor color,
    double fontSize, {
    String align = 'center',
  }) {
    final font = canvas.defaultFont!;
    final w = font.stringMetrics(text).advanceWidth * fontSize;
    double dx;
    switch (align) {
      case 'right':
        dx = x - w;
        break;
      case 'left':
        dx = x;
        break;
      default:
        dx = x - w / 2;
    }
    canvas
      ..setFillColor(color)
      ..drawString(font, fontSize, text, dx, y);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Tables ──────────────────────────────────────────────────────────────

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
