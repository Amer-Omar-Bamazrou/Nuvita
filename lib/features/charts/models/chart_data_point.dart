enum TrendDirection { improving, worsening, stable }

class ChartDataPoint {
  final DateTime date;
  final double value;
  final String status;

  const ChartDataPoint({
    required this.date,
    required this.value,
    required this.status,
  });
}
