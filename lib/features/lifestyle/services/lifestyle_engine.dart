import 'package:flutter/material.dart';
import '../models/lifestyle_suggestion.dart';

class LifestyleEngine {
  // Blood sugar thresholds are in mg/dL (the app's stored unit).
  // Converted from the mmol/L clinical values: 10 mmol/L = 180 mg/dL, 4 = 72, 7 = 126.
  static const double _bsHighThreshold = 180;
  static const double _bsLowThreshold = 72;
  static const double _bsMidThreshold = 126;

  // Returns up to 4 suggestions sorted high → medium → low.
  // latestReadings keys match HealthMetric enum names: bloodSugar, systolic,
  // diastolic, heartRate, weight, steps.
  List<LifestyleSuggestion> getSuggestions(
    String diseaseType,
    Map<String, dynamic> latestReadings,
  ) {
    final suggestions = <LifestyleSuggestion>[];

    final bloodSugar = latestReadings['bloodSugar'] as double?;
    final systolic = latestReadings['systolic'] as double?;
    final heartRate = latestReadings['heartRate'] as double?;
    final weight = latestReadings['weight'] as double?;
    final steps = latestReadings['steps'] as double?;

    // Blood sugar rules
    if (bloodSugar != null) {
      if (bloodSugar > _bsHighThreshold) {
        suggestions.add(const LifestyleSuggestion(
          id: 'bs_high',
          title: 'Reduce Sugar Intake',
          description:
              'Your blood sugar is elevated. Avoid sugary drinks and snacks, '
              'and increase your water intake to help your body balance glucose levels.',
          category: SuggestionCategory.nutrition,
          priority: SuggestionPriority.high,
          icon: Icons.warning_amber_rounded,
        ));
      } else if (bloodSugar < _bsLowThreshold) {
        suggestions.add(const LifestyleSuggestion(
          id: 'bs_low',
          title: 'Eat Small Frequent Meals',
          description:
              'Your blood sugar is low. Have a small snack now and eat '
              'every 2–3 hours to keep your glucose levels stable.',
          category: SuggestionCategory.nutrition,
          priority: SuggestionPriority.high,
          icon: Icons.restaurant_rounded,
        ));
      } else if (bloodSugar >= _bsMidThreshold) {
        suggestions.add(const LifestyleSuggestion(
          id: 'bs_mid',
          title: 'Light Walk After Meals',
          description:
              'A 10-minute walk after eating helps your body use glucose more '
              'efficiently and keeps blood sugar from rising too high.',
          category: SuggestionCategory.exercise,
          priority: SuggestionPriority.medium,
          icon: Icons.directions_walk_rounded,
        ));
      }
    }

    // Systolic BP rules
    if (systolic != null) {
      if (systolic > 140) {
        suggestions.add(const LifestyleSuggestion(
          id: 'bp_high',
          title: 'Reduce Salt & Avoid Caffeine',
          description:
              'Your blood pressure is high. Cut back on salty foods and '
              'avoid coffee or energy drinks until your reading comes down.',
          category: SuggestionCategory.nutrition,
          priority: SuggestionPriority.high,
          icon: Icons.monitor_heart_rounded,
        ));
      } else if (systolic >= 120) {
        suggestions.add(const LifestyleSuggestion(
          id: 'bp_mid',
          title: '30-Minute Walk Daily',
          description:
              'Regular moderate walking is one of the most effective ways '
              'to bring borderline blood pressure into a healthy range.',
          category: SuggestionCategory.exercise,
          priority: SuggestionPriority.medium,
          icon: Icons.directions_walk_rounded,
        ));
      }
    }

    // Heart rate rules
    if (heartRate != null) {
      if (heartRate > 100) {
        suggestions.add(const LifestyleSuggestion(
          id: 'hr_high',
          title: 'Try Breathing Exercises',
          description:
              'Your heart rate is elevated. Try box breathing: inhale for '
              '4 seconds, hold 4, exhale 6. Repeat 5 times to calm your nervous system.',
          category: SuggestionCategory.stress,
          priority: SuggestionPriority.high,
          icon: Icons.air_rounded,
        ));
      } else if (heartRate < 55) {
        suggestions.add(const LifestyleSuggestion(
          id: 'hr_low',
          title: 'Speak to Your Doctor',
          description:
              'Your heart rate is lower than normal. Avoid intense physical '
              'activity today and mention this to your doctor if it continues.',
          category: SuggestionCategory.medication,
          priority: SuggestionPriority.medium,
          icon: Icons.medical_services_rounded,
        ));
      }
    }

    // Weight exists → nudge towards hydration and daily steps
    if (weight != null) {
      suggestions.add(const LifestyleSuggestion(
        id: 'weight_hydration',
        title: 'Stay Hydrated & Keep Moving',
        description:
            'Aim for at least 8 glasses of water and 8,000 steps today. '
            'Both habits support a healthy weight over time.',
        category: SuggestionCategory.hydration,
        priority: SuggestionPriority.low,
        icon: Icons.water_drop_rounded,
      ));
    }

    // Steps rules
    if (steps != null) {
      if (steps < 3000) {
        suggestions.add(const LifestyleSuggestion(
          id: 'steps_low',
          title: 'Take a Short Walk',
          description:
              "You've been less active today. Even a 15-minute walk around "
              'the block improves circulation and lifts your energy.',
          category: SuggestionCategory.exercise,
          priority: SuggestionPriority.medium,
          icon: Icons.directions_walk_rounded,
        ));
      } else if (steps > 8000) {
        suggestions.add(const LifestyleSuggestion(
          id: 'steps_great',
          title: 'Great Work Today!',
          description:
              "You've logged over 8,000 steps — excellent! Staying this "
              'active is one of the best things you can do for your long-term health.',
          category: SuggestionCategory.exercise,
          priority: SuggestionPriority.low,
          icon: Icons.emoji_events_rounded,
        ));
      }
    }

    // Disease-type defaults when no relevant reading has been logged today
    if (diseaseType == 'diabetes' && bloodSugar == null) {
      suggestions.add(const LifestyleSuggestion(
        id: 'diabetes_default',
        title: 'Choose Low-GI Foods',
        description:
            'No blood sugar reading yet today. Opt for whole grains, legumes, '
            'and vegetables to keep your glucose stable throughout the day.',
        category: SuggestionCategory.nutrition,
        priority: SuggestionPriority.medium,
        icon: Icons.grain_rounded,
      ));
    }

    if (diseaseType == 'blood_pressure' && systolic == null) {
      suggestions.add(const LifestyleSuggestion(
        id: 'bp_default',
        title: 'Drink More Water',
        description:
            'No blood pressure reading yet today. Staying well-hydrated '
            'supports healthy circulation and helps regulate blood pressure.',
        category: SuggestionCategory.hydration,
        priority: SuggestionPriority.medium,
        icon: Icons.water_drop_rounded,
      ));
    }

    // Heart condition always gets a stress management tip
    if (diseaseType == 'heart') {
      suggestions.add(const LifestyleSuggestion(
        id: 'heart_stress',
        title: 'Manage Daily Stress',
        description:
            'Chronic stress adds strain to your heart. Try 10 minutes of '
            'relaxation, gentle music, or light stretching each day.',
        category: SuggestionCategory.stress,
        priority: SuggestionPriority.medium,
        icon: Icons.self_improvement_rounded,
      ));
    }

    // Sort high → medium → low, deduplicate by id, cap at 4
    suggestions.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    final seen = <String>{};
    final result = <LifestyleSuggestion>[];
    for (final s in suggestions) {
      if (seen.add(s.id) && result.length < 4) result.add(s);
    }

    return result;
  }
}
