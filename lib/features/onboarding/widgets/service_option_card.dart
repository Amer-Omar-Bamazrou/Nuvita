import 'package:flutter/material.dart';
import '../../../core/services/care_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ServiceOption {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const ServiceOption({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

// Shown in onboarding and in Profile → My services
const serviceOptions = [
  ServiceOption(
    id: CareServices.medications,
    icon: Icons.medication_rounded,
    iconColor: Color(0xFF1565C0),
    title: 'Medications',
    description: 'Get reminders and track your medication intakes',
  ),
  ServiceOption(
    id: CareServices.measurements,
    icon: Icons.monitor_heart_rounded,
    iconColor: Color(0xFF2E7D32),
    title: 'Measurements',
    description: 'Log health readings like blood pressure and blood sugar',
  ),
  ServiceOption(
    id: CareServices.activities,
    icon: Icons.directions_walk_rounded,
    iconColor: Color(0xFFE65100),
    title: 'Activities',
    description: 'Log walking and get a daily reminder to stay active',
  ),
  ServiceOption(
    id: CareServices.appointments,
    icon: Icons.calendar_month_rounded,
    iconColor: Color(0xFF00695C),
    title: 'Appointments',
    description: 'Never miss a doctor appointment again',
  ),
];

class ServiceOptionCard extends StatelessWidget {
  final ServiceOption service;
  final bool selected;
  final VoidCallback onTap;

  const ServiceOptionCard({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: service.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service.icon, color: service.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: AppTextStyles.heading3.copyWith(
                      fontSize: 15,
                      color: selected ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.description,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                  width: 2,
                ),
              ),
              child: Icon(
                selected ? Icons.check : Icons.add,
                color: selected ? AppColors.white : AppColors.secondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
