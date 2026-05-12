import 'package:flutter/material.dart';

class MetricConfig {
  final String title;
  final IconData icon;
  final String unit;
  final double min;
  final double max;

  const MetricConfig({
    required this.title,
    required this.icon,
    required this.unit,
    required this.min,
    required this.max,
  });
}
