import 'package:flutter/material.dart';

enum SuggestionCategory { nutrition, exercise, sleep, stress, hydration, medication }

enum SuggestionPriority { high, medium, low }

class LifestyleSuggestion {
  final String id;
  final String title;
  final String description;
  final SuggestionCategory category;
  final SuggestionPriority priority;
  final IconData icon;

  const LifestyleSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.icon,
  });
}
