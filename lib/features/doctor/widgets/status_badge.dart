import 'package:flutter/material.dart';

// Outlined status pill used across the doctor portal
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Normal':
        color = const Color(0xFF2E7D32);
        break;
      case 'Warning':
        color = const Color(0xFFFF6F00);
        break;
      case 'Critical':
      case 'High':
      case 'Low':
        color = const Color(0xFFD32F2F);
        break;
      default:
        color = const Color(0xFF6E7A82);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
