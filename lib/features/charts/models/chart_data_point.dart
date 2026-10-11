enum TrendDirection { improving, worsening, stable }

class ChartDataPoint {
  final DateTime date;
  final double value;
  final String status;
  final String? context; // e.g. "Fasting" for blood sugar, shown in tooltips
  final String? note; // context chip picked when the reading was taken

  const ChartDataPoint({
    required this.date,
    required this.value,
    required this.status,
    this.context,
    this.note,
  });

  // Extra tooltip line, e.g. "Fasting · Just woke up"
  String? get detail {
    final parts = [
      ?context,
      if (note != null && note!.isNotEmpty) note!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
