import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../models/chart_data_point.dart';
import '../models/metric_thresholds.dart';

class HealthChartWidget extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;
  final String metricType;
  final String unit;

  // Highlighted with a gold dot — set from ChartDataService.getPersonalBest()
  final ChartDataPoint? personalBest;

  const HealthChartWidget({
    super.key,
    required this.dataPoints,
    required this.metricType,
    required this.unit,
    this.personalBest,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) return const SizedBox.shrink();

    final spots = dataPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    // Find personal best index for the custom dot painter
    final pbIndex = personalBest == null
        ? -1
        : dataPoints.indexWhere(
            (p) => p.date == personalBest!.date && p.value == personalBest!.value,
          );

    final values = dataPoints.map((p) => p.value).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    final (normalMin, normalMax) = MetricThresholds.getNormalRange(metricType);
    final (_, warningMax) = MetricThresholds.getWarningRange(metricType);

    // Give extra breathing room above and below the data
    final chartMinY = (minVal - 15).clamp(0.0, double.infinity);
    final chartMaxY = maxVal + 20;

    return SizedBox(
      height: 230,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
        child: LineChart(
          LineChartData(
            // Coloured horizontal bands for normal / warning / critical zones
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: _buildZones(
                normalMin, normalMax, warningMax, chartMinY, chartMaxY,
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
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
                color: AppColors.divider.withOpacity(0.5),
                strokeWidth: 1,
              ),
            ),
            // Show only left + bottom borders for a clean axis look
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
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 2.5,
                // Gradient fill below the line
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.22),
                      AppColors.primary.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    // Gold star-like dot for personal best, standard dot for others
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

  /// Continuous coloured zone bands clamped to the chart's visible Y range.
  /// Without clamping, fl_chart renders annotations that are entirely below
  /// chartMinY, which causes overflow artifacts at the bottom of the chart.
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

    addZone(chartMinY, normalMin, const Color(0x26F44336));  // critical low  — red
    addZone(normalMin, normalMax, const Color(0x1A4CAF50));  // normal        — green
    addZone(normalMax, warningMax, const Color(0x1AFF9800)); // warning       — orange
    addZone(warningMax, chartMaxY, const Color(0x26F44336)); // critical high — red

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
