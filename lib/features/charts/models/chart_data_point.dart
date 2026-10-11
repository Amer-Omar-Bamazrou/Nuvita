enum TrendDirection { improving, worsening, stable }

class ChartDataPoint {
  final DateTime date;
  final double value;
  final String status;
  final String? context; // e.g. "Fasting" for blood sugar, shown in tooltips

  const ChartDataPoint({
    required this.date,
    required this.value,
    required this.status,
    this.context,
  });
}
