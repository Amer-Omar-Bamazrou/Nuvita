import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/dashboard/providers/health_provider.dart';
import '../models/metric_config.dart';
import 'add_reading_input_screen.dart';
import 'blood_pressure_input_screen.dart';

// Virtual item type — Blood Pressure is a combined entry, others are single-metric.
enum _MeasurementId { bloodSugarBefore, bloodSugarAfter, bloodPressure, weight, temperature }

class _MeasurementItem {
  final _MeasurementId id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _MeasurementItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const List<_MeasurementItem> _allItems = [
  _MeasurementItem(
    id: _MeasurementId.bloodSugarBefore,
    title: 'Blood Sugar (Before Meal)',
    subtitle: 'mg/dL · Fasting glucose',
    icon: Icons.water_drop,
  ),
  _MeasurementItem(
    id: _MeasurementId.bloodSugarAfter,
    title: 'Blood Sugar (After Meal)',
    subtitle: 'mg/dL · Post-meal glucose',
    icon: Icons.water_drop_outlined,
  ),
  _MeasurementItem(
    id: _MeasurementId.bloodPressure,
    title: 'Blood Pressure',
    subtitle: 'mmHg · Systolic, Diastolic & Pulse',
    icon: Icons.favorite_rounded,
  ),
  _MeasurementItem(
    id: _MeasurementId.weight,
    title: 'Weight',
    subtitle: 'kg · Body weight',
    icon: Icons.scale,
  ),
  _MeasurementItem(
    id: _MeasurementId.temperature,
    title: 'Temperature',
    subtitle: '°C · Body temperature',
    icon: Icons.thermostat,
  ),
];

const Map<String, List<_MeasurementId>> _popularByDisease = {
  'diabetes': [
    _MeasurementId.bloodSugarBefore,
    _MeasurementId.bloodSugarAfter,
    _MeasurementId.weight,
  ],
  'blood_pressure': [
    _MeasurementId.bloodPressure,
    _MeasurementId.weight,
  ],
  'heart': [
    _MeasurementId.bloodPressure,
    _MeasurementId.weight,
  ],
  'other': [
    _MeasurementId.bloodPressure,
    _MeasurementId.weight,
    _MeasurementId.temperature,
  ],
};

const Map<_MeasurementId, MetricConfig> _singleConfigs = {
  _MeasurementId.bloodSugarBefore: MetricConfig(
    title: 'Blood Sugar (Before Meal)',
    icon: Icons.water_drop,
    unit: 'mg/dL',
    min: 20,
    max: 600,
  ),
  _MeasurementId.bloodSugarAfter: MetricConfig(
    title: 'Blood Sugar (After Meal)',
    icon: Icons.water_drop_outlined,
    unit: 'mg/dL',
    min: 20,
    max: 600,
  ),
  _MeasurementId.weight: MetricConfig(
    title: 'Weight',
    icon: Icons.scale,
    unit: 'kg',
    min: 20,
    max: 300,
  ),
  _MeasurementId.temperature: MetricConfig(
    title: 'Temperature',
    icon: Icons.thermostat,
    unit: '°C',
    min: 30,
    max: 45,
  ),
};

const Map<_MeasurementId, HealthMetric> _singleMetric = {
  _MeasurementId.bloodSugarBefore: HealthMetric.bloodSugarBefore,
  _MeasurementId.bloodSugarAfter: HealthMetric.bloodSugarAfter,
  _MeasurementId.weight: HealthMetric.weight,
  _MeasurementId.temperature: HealthMetric.temperature,
};

class AddReadingListScreen extends StatefulWidget {
  final String diseaseType;
  final Future<void> Function(HealthMetric metric, double value, DateTime when) onSave;

  const AddReadingListScreen({
    super.key,
    required this.diseaseType,
    required this.onSave,
  });

  @override
  State<AddReadingListScreen> createState() => _AddReadingListScreenState();
}

class _AddReadingListScreenState extends State<AddReadingListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_MeasurementItem> get _popular {
    final ids = _popularByDisease[widget.diseaseType] ?? _popularByDisease['other']!;
    return ids.map((id) => _allItems.firstWhere((i) => i.id == id)).toList();
  }

  List<_MeasurementItem> get _filtered {
    if (_query.isEmpty) return _allItems;
    return _allItems
        .where((i) => i.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _openItem(_MeasurementItem item) async {
    bool? saved;

    if (item.id == _MeasurementId.bloodPressure) {
      saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BloodPressureInputScreen(onSave: widget.onSave),
        ),
      );
    } else {
      final config = _singleConfigs[item.id]!;
      final metric = _singleMetric[item.id]!;
      saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddReadingInputScreen(
            metric: metric,
            config: config,
            onSave: widget.onSave,
          ),
        ),
      );
    }

    // Pop the list screen too so the user lands back on the home screen
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Reading', style: AppTextStyles.heading2),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search measurements…',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.secondary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                if (!searching) ...[
                  _sectionHeader('Popular for you'),
                  const SizedBox(height: 8),
                  ..._popular.map(_tile),
                  const SizedBox(height: 20),
                  _sectionHeader('All measurements'),
                  const SizedBox(height: 8),
                  ..._allItems.map(_tile),
                ] else if (filtered.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        'No measurements match "$_query"',
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  ...filtered.map(_tile),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Color(0xFF6E7A82),
      ),
    );
  }

  Widget _tile(_MeasurementItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: AppColors.primary, size: 22),
        ),
        title: Text(item.title, style: AppTextStyles.label.copyWith(fontSize: 14)),
        subtitle: Text(
          item.subtitle,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondary, size: 22),
        onTap: () => _openItem(item),
      ),
    );
  }
}
