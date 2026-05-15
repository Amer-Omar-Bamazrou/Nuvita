import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../models/chart_data_point.dart';
import '../models/metric_thresholds.dart';

class HealthChartWidget extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;
  final String metricType;
  final String unit;
  final ChartDataPoint? personalBest;

  // Dual line support
  final List<ChartDataPoint>? secondaryData;
  final String? secondaryLabel;
  final Color? secondaryColor;

  const HealthChartWidget({
    super.key,
    required this.dataPoints,
    required this.metricType,
    required this.unit,
    this.personalBest,
    this.secondaryData,
    this.secondaryLabel,
    this.secondaryColor,
  });

  bool get _isDualLine => secondaryData != null && secondaryData!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) return const SizedBox.shrink();

    final spots = dataPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final pbIndex = personalBest == null
        ? -1
        : dataPoints.indexWhere(
            (p) => p.date == personalBest!.date && p.value == personalBest!.value,
          );

    final values = dataPoints.map((p) => p.value).toList();
    var minVal = values.reduce((a, b) => a < b ? a : b);
    var maxVal = values.reduce((a, b) => a > b ? a : b);

    // Include secondary data in Y range
    List<FlSpot>? secondarySpots;
    if (_isDualLine) {
      secondarySpots = _alignSecondarySpots();
      for (final s in secondarySpots) {
        if (s.y < minVal) minVal = s.y;
        if (s.y > maxVal) maxVal = s.y;
      }
    }

    final (normalMin, normalMax) = MetricThresholds.getNormalRange(metricType);
    final (_, warningMax) = MetricThresholds.getWarningRange(metricType);

    final chartMinY = (minVal - 15).clamp(0.0, double.infinity);
    final chartMaxY = maxVal + 20;

    return SizedBox(
      height: 230,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
        child: LineChart(
          LineChartData(
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: _buildZones(
                normalMin, normalMax, warningMax, chartMinY, chartMaxY,
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  if (_isDualLine) return _dualTooltip(touchedSpots);
                  return touchedSpots.map((s) {
                    final idx = s.spotIndex;
                    if (idx < 0 || idx >= dataPoints.length) return null;
                    final point = dataPoints[idx];
                    final date = _fmtDate(point.date);
                    return LineTooltipItem(
                      '$date\n${point.value.toStringAsFixed(1)} $unit',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.divider.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(color: AppColors.divider, width: 1),
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: _xInterval(dataPoints.length),
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= dataPoints.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _fmtDate(dataPoints[idx].date),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.secondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              // Primary line
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: !_isDualLine,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.22),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    if (index == pbIndex) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.amber,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 3.5,
                      color: AppColors.primary,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              ),
              // Secondary line (diastolic)
              if (_isDualLine && secondarySpots != null)
                LineChartBarData(
                  spots: secondarySpots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: secondaryColor ?? AppColors.secondary,
                  barWidth: 2,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: secondaryColor ?? AppColors.secondary,
                      );
                    },
                  ),
                ),
            ],
            minX: 0,
            maxX: (dataPoints.length - 1).toDouble(),
            minY: chartMinY,
            maxY: chartMaxY,
          ),
        ),
      ),
    );
  }

  // Align secondary data points to primary data's x-axis by matching dates
  List<FlSpot> _alignSecondarySpots() {
    final secondary = secondaryData!;
    final result = <FlSpot>[];

    for (int i = 0; i < dataPoints.length; i++) {
      final pDate = dataPoints[i].date;
      // Find secondary point on same day
      final match = secondary.where((s) =>
          s.date.year == pDate.year &&
          s.date.month == pDate.month &&
          s.date.day == pDate.day);
      if (match.isNotEmpty) {
        result.add(FlSpot(i.toDouble(), match.first.value));
      }
    }

    // If no date matches, plot secondary on its own indices
    if (result.isEmpty) {
      for (int i = 0; i < secondary.length && i < dataPoints.length; i++) {
        result.add(FlSpot(i.toDouble(), secondary[i].value));
      }
    }

    return result;
  }

  // Combined tooltip showing both Sys and Dia values
  List<LineTooltipItem?> _dualTooltip(List<LineBarSpot> touchedSpots) {
    if (touchedSpots.isEmpty) return [];

    final idx = touchedSpots.first.spotIndex;
    final date = idx >= 0 && idx < dataPoints.length
        ? _fmtDate(dataPoints[idx].date)
        : '';

    String sysVal = '';
    String diaVal = '';

    for (final spot in touchedSpots) {
      if (spot.barIndex == 0) {
        sysVal = spot.y.toStringAsFixed(0);
      } else if (spot.barIndex == 1) {
        diaVal = spot.y.toStringAsFixed(0);
      }
    }

    final lines = <String>[date];
    if (sysVal.isNotEmpty) lines.add('Sys: $sysVal $unit');
    if (diaVal.isNotEmpty) lines.add('Dia: $diaVal $unit');

    // Show tooltip on first touched spot only
    return [
      LineTooltipItem(
        lines.join('\n'),
        const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Return null for subsequent spots to avoid duplicate tooltips
      for (int i = 1; i < touchedSpots.length; i++) null,
    ];
  }

  List<HorizontalRangeAnnotation> _buildZones(
    double normalMin,
    double normalMax,
    double warningMax,
    double chartMinY,
    double chartMaxY,
  ) {
    final zones = <HorizontalRangeAnnotation>[];

    void addZone(double y1, double y2, Color color) {
      final lo = y1.clamp(chartMinY, chartMaxY);
      final hi = y2.clamp(chartMinY, chartMaxY);
      if (hi > lo) zones.add(HorizontalRangeAnnotation(y1: lo, y2: hi, color: color));
    }

    addZone(chartMinY, normalMin, const Color(0x26F44336));
    addZone(normalMin, normalMax, const Color(0x1A4CAF50));
    addZone(normalMax, warningMax, const Color(0x1AFF9800));
    addZone(warningMax, chartMaxY, const Color(0x26F44336));

    return zones;
  }

  double _xInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 10;
  }

  String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}
