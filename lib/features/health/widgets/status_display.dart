import 'package:flutter/material.dart';
import '../../../core/health/health_metrics.dart';
import '../../../core/theme/app_colors.dart';

// Badge text and colour for the live status preview on the entry screens
(String, Color) statusDisplay(MetricStatus? status) {
  switch (status) {
    case MetricStatus.normal:
      return ('Normal', AppColors.success);
    case MetricStatus.warning:
      return ('Slightly high', AppColors.warning);
    case MetricStatus.criticalLow:
      return ('Low', AppColors.error);
    case MetricStatus.criticalHigh:
      return ('High', AppColors.error);
    case null:
      return ('Recorded', AppColors.success);
  }
}

String formatMetricValue(MetricDefinition def, double value) =>
    value.toStringAsFixed(def.decimals);

// "Normal range: 50 – 100 bpm", built from the metric's status bands
String? normalRangeHint(MetricDefinition def, StatusBands? bands) {
  if (bands == null) return null;
  return 'Normal range: ${formatMetricValue(def, bands.low)} – '
      '${formatMetricValue(def, bands.normalMax)} ${def.unit}';
}
