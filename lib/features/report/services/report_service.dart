import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/health/health_metrics.dart';
import '../../health/models/blood_pressure_pair.dart';
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
  static final _chartGrid = PdfColor.fromHex('DDDDDD');
  static final _chartAxisText = PdfColor.fromHex('666666');
  static const _zoneNormal = PdfColor(0.3, 0.69, 0.31, 0.12);
  static const _zoneWarning = PdfColor(1.0, 0.6, 0.0, 0.10);

  static Future<Uint8List> generateReport(
    String uid,
    String name,
    String diseaseType,
  ) async {
    final readings = await HealthReadingService.getReadingsLastDays(uid, 30);
    final medications = await MedicationService.loadAll();
    final adherence = await MedicationService.getAdherenceHistory(uid, 30);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 20),
          _buildPatientSummary(name),
          pw.SizedBox(height: 24),
          _buildVitalsSnapshot(readings),
          pw.SizedBox(height: 24),
          ..._buildReadingsWidgets(readings),
          pw.SizedBox(height: 24),
          ..._buildMedicationsWidgets(medications, adherence),
          pw.SizedBox(height: 24),
          _buildDisclaimer(),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ──────────────────────────────────────────────────────────────

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
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.Text(
              'Health Report',
              style: pw.TextStyle(fontSize: 20, color: _textDark),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: _dividerColor),
      ],
    );
  }

  // ── Patient summary (no condition) ─────────────────────────────────────

  static pw.Widget _buildPatientSummary(String name) {
    final now = DateTime.now();
    final period =
        '${_fmt(now.subtract(const Duration(days: 30)))} - ${_fmt(now)}';

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
            fontSize: 13,
          ),
        ),
        pw.Text(value, style: pw.TextStyle(color: _textDark, fontSize: 13)),
      ],
    );
  }

  // ── Vitals snapshot (latest values at a glance) ────────────────────────

  static pw.Widget _buildVitalsSnapshot(List<HealthReading> readings) {
    final grouped = <String, List<HealthReading>>{};
    for (final r in readings) {
      grouped.putIfAbsent(r.metricType, () => []).add(r);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    String latest(String type) {
      final list = grouped[type];
      if (list == null || list.isEmpty) return '--';
      return list.first.value.toStringAsFixed(1);
    }

    String latestUnit(String type) => _unitFor(type);

    final sys = latest('systolic');
    final dia = latest('diastolic');
    final hr = latest('heartRate');
    final hrUnit = latestUnit('heartRate');
    final bs = latest('bloodSugar');
    final bsUnit = latestUnit('bloodSugar');
    final bsContext = grouped['bloodSugar']?.first.context;
    final bsSuffix =
        bsContext == null ? '' : ' (${HealthMetrics.contextLabel(bsContext)})';
    final temp = latest('temperature');
    final tempUnit = latestUnit('temperature');
    final weight = latest('weight');
    final weightUnit = latestUnit('weight');
    final walking = latest('walkingMinutes');
    final walkingUnit = latestUnit('walkingMinutes');

    final labelStyle = pw.TextStyle(
      fontSize: 12,
      color: _textDark,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _primary,
    );

    pw.Widget vitalRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(label, style: labelStyle),
            ),
            pw.Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Latest Vitals',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _cardBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: _dividerColor),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              vitalRow('SYS / DIA', '$sys / $dia${sys != '--' ? ' mmHg' : ''}'),
              vitalRow('Heart Rate', hr != '--' ? '$hr $hrUnit' : '--'),
              vitalRow('Blood Sugar', bs != '--' ? '$bs $bsUnit$bsSuffix' : '--'),
              vitalRow('Temperature', temp != '--' ? '$temp $tempUnit' : '--'),
              vitalRow('Weight', weight != '--' ? '$weight $weightUnit' : '--'),
              pw.Padding(
                padding: pw.EdgeInsets.zero,
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 130,
                      child: pw.Text(
                        HealthMetrics.labelForKey('walkingMinutes'),
                        style: labelStyle,
                      ),
                    ),
                    pw.Text(
                      walking != '--'
                          ? '${double.parse(walking).toInt()} $walkingUnit'
                          : '--',
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Readings section (systolic/diastolic shown as one BP table) ────────

  static List<pw.Widget> _buildReadingsWidgets(List<HealthReading> readings) {
    final sectionTitle = pw.Text(
      'Health Readings',
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: _primary,
      ),
    );

    if (readings.isEmpty) {
      return [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sectionTitle,
            pw.SizedBox(height: 10),
            pw.Text(
              'No readings recorded in the last 30 days.',
              style: pw.TextStyle(color: _textDark, fontSize: 13),
            ),
          ],
        ),
      ];
    }

    final grouped = <String, List<HealthReading>>{};
    for (final r in readings) {
      grouped.putIfAbsent(r.metricType, () => []).add(r);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    const skipMetrics = {'systolic', 'diastolic'};

    final result = <pw.Widget>[sectionTitle, pw.SizedBox(height: 10)];

    final bpPairs = pairBloodPressure(
      readings.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
    );
    if (bpPairs.isNotEmpty) {
      result.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            HealthMetrics.bloodPressureLabel,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _textDark,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildBPTable(bpPairs),
          pw.SizedBox(height: 6),
          _buildBPStats(bpPairs),
          pw.SizedBox(height: 16),
        ],
      ));
    }

    for (final entry in grouped.entries) {
      if (skipMetrics.contains(entry.key)) continue;

      // Each metric is its own widget so MultiPage can break between them
      result.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            HealthMetrics.labelForKey(entry.key),
            style: pw.TextStyle(
              fontSize: 15,
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
            HealthMetrics.labelForKey(entry.key),
            entry.key,
          ),
          pw.SizedBox(height: 16),
        ],
      ));
    }

    return result;
  }

  // ── Chart drawing ─────────────────────────────────────────────────────────

  static pw.Widget _buildMetricChart(
    List<HealthReading> data,
    String metricName,
    String metricType,
  ) {
    if (data.length < 2) {
      return pw.SizedBox.shrink();
    }

    final sorted = List<HealthReading>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var minY = sorted.map((r) => r.value).reduce(min);
    var maxY = sorted.map((r) => r.value).reduce(max);

    // Zones are drawn only for metrics that have status bands
    final metric = HealthMetrics.metricForKey(metricType);
    final bands = metric == null ? null : HealthMetrics.bandsFor(metric);
    final hasZones = bands != null;
    final normalMin = bands?.low ?? 0;
    final normalMax = bands?.normalMax ?? 0;
    final warningMax = bands?.warningMax ?? 0;
    if (hasZones) {
      minY = min(minY, normalMin);
      maxY = max(maxY, warningMax);
    }

    final yPad = (maxY - minY) * 0.1;
    minY = (minY - yPad).clamp(0, double.infinity);
    maxY = maxY + yPad;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$metricName — Last 30 Days',
          style: pw.TextStyle(
            fontSize: 12,
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
            ),
          ),
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
    bool hasZones,
  ) {
    const leftPad = 38.0;
    const bottomPad = 20.0;
    const topPad = 4.0;
    const rightPad = 8.0;

    final chartW = size.x - leftPad - rightPad;
    final chartH = size.y - bottomPad - topPad;
    final yRange = maxY - minY;
    if (yRange <= 0 || chartW <= 0 || chartH <= 0) return;

    double xPos(int i) => leftPad + (i / (data.length - 1)) * chartW;
    double yPos(double val) =>
        bottomPad + ((val - minY) / yRange) * chartH;

    if (hasZones) {
      final nLo = yPos(normalMin).clamp(bottomPad, bottomPad + chartH);
      final nHi = yPos(normalMax).clamp(bottomPad, bottomPad + chartH);
      if (nHi > nLo) {
        canvas
          ..setFillColor(_zoneNormal)
          ..drawRect(leftPad, nLo, chartW, nHi - nLo)
          ..fillPath();
      }
      final wLo = yPos(normalMax).clamp(bottomPad, bottomPad + chartH);
      final wHi = yPos(warningMax).clamp(bottomPad, bottomPad + chartH);
      if (wHi > wLo) {
        canvas
          ..setFillColor(_zoneWarning)
          ..drawRect(leftPad, wLo, chartW, wHi - wLo)
          ..fillPath();
      }
    }

    canvas.setStrokeColor(_chartGrid);
    canvas.setLineWidth(0.3);
    for (int i = 0; i <= 4; i++) {
      final y = bottomPad + (i / 4) * chartH;
      canvas.drawLine(leftPad, y, leftPad + chartW, y);
    }
    canvas.strokePath();

    canvas
      ..setStrokeColor(_chartGrid)
      ..setLineWidth(0.5)
      ..drawRect(leftPad, bottomPad, chartW, chartH)
      ..strokePath();

    for (int i = 0; i <= 4; i++) {
      final val = minY + (i / 4) * yRange;
      final y = bottomPad + (i / 4) * chartH;
      _drawText(canvas, val.toStringAsFixed(0), leftPad - 4, y - 4,
          _chartAxisText, 8,
          align: 'right');
    }

    final xLabelCount = min(5, data.length);
    for (int i = 0; i < xLabelCount; i++) {
      final idx =
          xLabelCount <= 1 ? 0 : (i * (data.length - 1) ~/ (xLabelCount - 1));
      final x = xPos(idx);
      final dt = data[idx].timestamp;
      final label = '${dt.day}/${dt.month}';
      _drawText(canvas, label, x, bottomPad - 14, _chartAxisText, 8);
    }

    // Line + dots
    canvas
      ..setStrokeColor(_chartLine)
      ..setLineWidth(1.5);
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

    canvas.setFillColor(_chartLine);
    for (int i = 0; i < data.length; i++) {
      final x = xPos(i);
      final y = yPos(data[i].value);
      canvas.drawEllipse(x, y, 2.0, 2.0);
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

  // ── Tables ──────────────────────────────────────────────────────────────

  static pw.Widget _buildTable(List<HealthReading> readings) {
    final hasNotes = readings.any((r) => r.note != null && r.note!.isNotEmpty);
    // Blood sugar statuses depend on when the reading was taken, so show it
    final hasContext = readings.any((r) => r.context != null);

    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 12,
    );
    final cellStyle = pw.TextStyle(color: _textDark, fontSize: 12);

    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(text, style: style),
        );

    final headers = ['Date', 'Value', 'Unit', 'Status'];
    if (hasContext) headers.add('Context');
    if (hasNotes) headers.add('Note');

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.2),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(1.5),
    };
    if (hasContext) {
      columnWidths[columnWidths.length] = const pw.FlexColumnWidth(1.8);
    }
    if (hasNotes) {
      columnWidths[columnWidths.length] = const pw.FlexColumnWidth(2.5);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _dividerColor, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primary),
          children: headers.map((h) => cell(h, headerStyle)).toList(),
        ),
        ...readings.map(
          (r) {
            final cells = [
              cell(_fmt(r.timestamp), cellStyle),
              cell(r.value.toStringAsFixed(1), cellStyle),
              cell(_unitFor(r.metricType, fallback: r.unit), cellStyle),
              cell(r.status, cellStyle),
            ];
            if (hasContext) {
              cells.add(cell(
                r.context == null ? '' : HealthMetrics.contextLabel(r.context!),
                cellStyle,
              ));
            }
            if (hasNotes) {
              cells.add(cell(r.note ?? '', cellStyle));
            }
            return pw.TableRow(children: cells);
          },
        ),
      ],
    );
  }

  static pw.Widget _buildBPTable(List<BloodPressurePair> pairs) {
    final hasNotes = pairs.any((p) => p.note != null && p.note!.isNotEmpty);
    final unit = HealthMetrics.of(HealthMetric.systolic).unit;

    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 12,
    );
    final cellStyle = pw.TextStyle(color: _textDark, fontSize: 12);

    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(text, style: style),
        );

    String value(HealthReading? r) =>
        r == null ? '--' : r.value.toStringAsFixed(0);

    final headers = ['Date', 'Systolic', 'Diastolic', 'Unit', 'Status'];
    if (hasNotes) headers.add('Note');

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.2),
      1: const pw.FlexColumnWidth(1.4),
      2: const pw.FlexColumnWidth(1.4),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.5),
    };
    if (hasNotes) columnWidths[5] = const pw.FlexColumnWidth(2.2);

    return pw.Table(
      border: pw.TableBorder.all(color: _dividerColor, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primary),
          children: headers.map((h) => cell(h, headerStyle)).toList(),
        ),
        ...pairs.map((p) {
          final cells = [
            cell(_fmt(p.timestamp), cellStyle),
            cell(value(p.systolic), cellStyle),
            cell(value(p.diastolic), cellStyle),
            cell(unit, cellStyle),
            cell(p.status, cellStyle),
          ];
          if (hasNotes) cells.add(cell(p.note ?? '', cellStyle));
          return pw.TableRow(children: cells);
        }),
      ],
    );
  }

  static pw.Widget _buildBPStats(List<BloodPressurePair> pairs) {
    final unit = HealthMetrics.of(HealthMetric.systolic).unit;
    final sys =
        pairs.map((p) => p.systolic?.value).whereType<double>().toList();
    final dia =
        pairs.map((p) => p.diastolic?.value).whereType<double>().toList();

    String avg(List<double> v) => v.isEmpty
        ? '--'
        : (v.reduce((a, b) => a + b) / v.length).toStringAsFixed(0);
    String top(List<double> v) =>
        v.isEmpty ? '--' : v.reduce(max).toStringAsFixed(0);
    String bottom(List<double> v) =>
        v.isEmpty ? '--' : v.reduce(min).toStringAsFixed(0);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _statChip('Average', '${avg(sys)}/${avg(dia)} $unit'),
          _statChip('Highest', '${top(sys)}/${top(dia)} $unit'),
          _statChip('Lowest', '${bottom(sys)}/${bottom(dia)} $unit'),
        ],
      ),
    );
  }

  static pw.Widget _buildStats(List<HealthReading> readings) {
    final values = readings.map((r) => r.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final high = values.reduce((a, b) => a > b ? a : b);
    final low = values.reduce((a, b) => a < b ? a : b);
    final unit = _unitFor(readings.first.metricType, fallback: readings.first.unit);

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
        pw.Text(label, style: pw.TextStyle(fontSize: 11, color: _textDark)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
      ],
    );
  }

  // ── Medications + Adherence + Supply ───────────────────────────────────

  static List<pw.Widget> _buildMedicationsWidgets(
    List<MedicationModel> medications,
    Map<String, bool> adherence,
  ) {
    final sectionTitle = pw.Text(
      'Medications',
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: _primary,
      ),
    );

    if (medications.isEmpty) {
      return [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sectionTitle,
            pw.SizedBox(height: 10),
            pw.Text(
              'No medications recorded.',
              style: pw.TextStyle(color: _textDark, fontSize: 13),
            ),
          ],
        ),
      ];
    }

    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 12,
    );
    final cellStyle = pw.TextStyle(color: _textDark, fontSize: 12);

    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(text, style: style),
        );

    // Title + table kept together
    final medTable = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        sectionTitle,
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _dividerColor, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.8),
            4: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _primary),
              children: ['Name', 'Dosage', 'Frequency', 'Times', 'Pills Left']
                  .map((h) => cell(h, headerStyle))
                  .toList(),
            ),
            ...medications.map(
              (med) => pw.TableRow(children: [
                cell(med.name, cellStyle),
                cell(med.dosage, cellStyle),
                cell(med.frequency, cellStyle),
                cell(med.times.join(', '), cellStyle),
                cell(
                  med.pillsRemaining != null
                      ? '${med.pillsRemaining}'
                      : '--',
                  cellStyle,
                ),
              ]),
            ),
          ],
        ),
      ],
    );

    final result = <pw.Widget>[medTable];

    // Adherence summary
    if (adherence.isNotEmpty) {
      final taken = adherence.values.where((v) => v).length;
      final total = adherence.length;
      final pct = total > 0 ? (taken / total * 100).toStringAsFixed(0) : '0';

      result.add(pw.SizedBox(height: 12));
      result.add(pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _cardBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: _dividerColor),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _statChip('Doses Taken', '$taken / $total'),
            _statChip('Adherence Rate', '$pct%'),
            _statChip('Missed', '${total - taken} doses'),
          ],
        ),
      ));
    }

    // Medication notes
    final medsWithNotes =
        medications.where((m) => m.notes.isNotEmpty).toList();
    if (medsWithNotes.isNotEmpty) {
      result.add(pw.SizedBox(height: 8));
      for (final med in medsWithNotes) {
        result.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '${med.name}: ',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                pw.TextSpan(
                  text: med.notes,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
        ));
      }
    }

    return result;
  }

  // ── Disclaimer ─────────────────────────────────────────────────────────

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
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
          color: PdfColor(0.5, 0.5, 0.5),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static String _unitFor(String metricType, {String fallback = ''}) {
    final unit = HealthMetrics.unitForKey(metricType);
    return unit.isEmpty ? fallback : unit;
  }

  static String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}
