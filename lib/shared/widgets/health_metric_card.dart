import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/dashboard/providers/health_provider.dart';

// Carries the icon and colour for a single trend arrow on a metric card.
class TrendIndicator {
  final IconData icon;
  final Color color;
  const TrendIndicator({required this.icon, required this.color});
}

// Purely presentational — no provider knowledge here.
// Parent passes value/status and wires up onSubmit to the provider.
class HealthMetricCard extends StatelessWidget {
  const HealthMetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.unit,
    required this.value,
    required this.status,
    required this.onSubmit,
    this.minValue,
    this.maxValue,
    this.suggestion,
    this.trendIndicator,
    this.warningAdvice,
  });

  final String title;
  final IconData icon;
  final String unit;
  final double? value;
  final MetricStatus? status;
  final void Function(double) onSubmit;
  final double? minValue;
  final double? maxValue;
  final String? suggestion;
  // Trend arrow shown next to the value — only set when user has entered
  // a new reading this session that differs from the Firebase baseline.
  final TrendIndicator? trendIndicator;
  // Warning/critical action prompt that replaces the lifestyle suggestion
  // when the reading is outside the safe range.
  final String? warningAdvice;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showReadingSheet(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon chip + status badge in same row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const Spacer(),
                if (status != null) _StatusBadge(status: status!),
              ],
            ),
            const SizedBox(height: 14),
            // Value row — trend arrow appears to the right when available
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  value != null ? _formatValue(value!) : '---',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 28,
                    color: value != null ? _valueColor(status) : AppColors.divider,
                  ),
                ),
                if (trendIndicator != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    trendIndicator!.icon,
                    color: trendIndicator!.color,
                    size: 16,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            // Unit or tap prompt
            Text(
              value != null ? unit : 'Tap to add',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                color: value != null ? AppColors.secondary : AppColors.card,
              ),
            ),
            const Spacer(),
            // Metric label at the bottom
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                color: AppColors.textDark.withOpacity(0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // warningAdvice takes priority over the lifestyle suggestion —
            // both aren't shown at the same time to keep the card compact.
            if (warningAdvice != null) ...[
              const SizedBox(height: 5),
              Text(
                warningAdvice!,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: _valueColor(status),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (suggestion != null) ...[
              const SizedBox(height: 5),
              Text(
                suggestion!,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Shows as integer when there's no decimal, otherwise 1 decimal place
  String _formatValue(double v) {
    return v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
  }

  Color _valueColor(MetricStatus? s) {
    if (s == null) return AppColors.primary;
    switch (s) {
      case MetricStatus.normal:
        return AppColors.success;
      case MetricStatus.warning:
        return AppColors.warning;
      case MetricStatus.criticalLow:
      case MetricStatus.criticalHigh:
        return AppColors.error;
    }
  }

  void _showReadingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddReadingSheet(
        title: title,
        unit: unit,
        minValue: minValue,
        maxValue: maxValue,
        onSubmit: (v) {
          onSubmit(v);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MetricStatus status;

  String get _label {
    switch (status) {
      case MetricStatus.normal:
        return 'Normal';
      case MetricStatus.warning:
        return 'Warning';
      case MetricStatus.criticalLow:
        return 'Low';
      case MetricStatus.criticalHigh:
        return 'High';
    }
  }

  Color get _color {
    switch (status) {
      case MetricStatus.normal:
        return AppColors.success;
      case MetricStatus.warning:
        return AppColors.warning;
      case MetricStatus.criticalLow:
      case MetricStatus.criticalHigh:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

// ── Add reading bottom sheet ──────────────────────────────────────────────────

class _AddReadingSheet extends StatefulWidget {
  const _AddReadingSheet({
    required this.title,
    required this.unit,
    required this.onSubmit,
    this.minValue,
    this.maxValue,
  });

  final String title;
  final String unit;
  final void Function(double) onSubmit;
  final double? minValue;
  final double? maxValue;

  @override
  State<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<_AddReadingSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());

    if (value == null) {
      setState(() => _error = 'Please enter a valid number');
      return;
    }
    if (widget.minValue != null && value < widget.minValue!) {
      setState(() => _error = 'Value is too low (min ${widget.minValue!.toInt()})');
      return;
    }
    if (widget.maxValue != null && value > widget.maxValue!) {
      setState(() => _error = 'Value is too high (max ${widget.maxValue!.toInt()})');
      return;
    }

    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Rises above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Add ${widget.title}', style: AppTextStyles.heading2),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.heading2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter value',
                hintStyle:
                    AppTextStyles.heading2.copyWith(color: AppColors.divider),
                suffixText: widget.unit,
                suffixStyle:
                    AppTextStyles.heading3.copyWith(color: AppColors.secondary),
                errorText: _error,
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.error, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.error, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text('Save Reading', style: AppTextStyles.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
