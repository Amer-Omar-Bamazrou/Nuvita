import 'package:flutter/material.dart';
import '../../../core/health/health_metrics.dart';
import '../../../core/theme/app_text_styles.dart';
import 'status_display.dart';

// "Type a value" dialog for the reading screens. Keeps itself open and shows
// what's wrong when the entry isn't a number or is outside the metric's range.
Future<double?> showValueEntryDialog(
  BuildContext context, {
  required MetricDefinition def,
  required double initial,
  String title = 'Enter value',
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _ValueEntryDialog(def: def, initial: initial, title: title),
  );
}

class _ValueEntryDialog extends StatefulWidget {
  final MetricDefinition def;
  final double initial;
  final String title;

  const _ValueEntryDialog({
    required this.def,
    required this.initial,
    required this.title,
  });

  @override
  State<_ValueEntryDialog> createState() => _ValueEntryDialogState();
}

class _ValueEntryDialogState extends State<_ValueEntryDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatMetricValue(widget.def, widget.initial),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final def = widget.def;
    final v = double.tryParse(_controller.text.trim());
    if (v == null) {
      setState(() => _error = 'Enter a number');
      return;
    }
    if (!def.isInRange(v)) {
      setState(() => _error = 'Enter a value between '
          '${formatMetricValue(def, def.min)} and '
          '${formatMetricValue(def, def.max)} ${def.unit}');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: AppTextStyles.heading3),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          suffixText: widget.def.unit,
          errorText: _error,
          errorMaxLines: 2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
