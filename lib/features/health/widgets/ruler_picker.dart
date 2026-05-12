import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class RulerPicker extends StatefulWidget {
  final double min;
  final double max;
  final double step;
  final double initialValue;
  final void Function(double) onChanged;

  const RulerPicker({
    super.key,
    required this.min,
    required this.max,
    required this.step,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final ScrollController _scroll;
  static const double _tickWidth = 10.0;
  static const double _majorEvery = 10; // every 10 minor ticks → major tick

  late int _totalTicks;
  late int _lastCenteredTick;

  @override
  void initState() {
    super.initState();
    _totalTicks = ((widget.max - widget.min) / widget.step).round() + 1;
    _lastCenteredTick = ((widget.initialValue - widget.min) / widget.step)
        .round()
        .clamp(0, _totalTicks - 1);
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final width = context.size?.width ?? 360.0;
      final offset = _offsetForTick(_lastCenteredTick, width);
      if (_scroll.hasClients) _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  double _offsetForTick(int tick, double screenWidth) {
    final centerOffset = screenWidth / 2;
    return (tick * _tickWidth) - centerOffset + _tickWidth / 2;
  }

  void _onScroll() {
    final screenWidth = context.size?.width ?? 400;
    final centerOffset = _scroll.offset + screenWidth / 2;
    final tick = (centerOffset / _tickWidth).round().clamp(0, _totalTicks - 1);
    if (tick != _lastCenteredTick) {
      _lastCenteredTick = tick;
      final value = _clampToStep(widget.min + tick * widget.step);
      HapticFeedback.selectionClick();
      widget.onChanged(value);
    }
  }

  double _clampToStep(double raw) {
    final snapped = (raw / widget.step).round() * widget.step;
    return snapped.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth / 2;

    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ruler ticks
          ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: halfScreen - _tickWidth / 2),
            itemCount: _totalTicks,
            itemBuilder: (context, i) {
              final isMajor = i % _majorEvery == 0;
              final labelValue = widget.min + i * widget.step;
              return SizedBox(
                width: _tickWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isMajor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _formatLabel(labelValue),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Container(
                      width: 1.5,
                      height: isMajor ? 36 : 20,
                      color: isMajor
                          ? AppColors.primary.withOpacity(0.55)
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),

          // Center indicator line
          Positioned(
            bottom: 10,
            child: Container(
              width: 2,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Fade edges
          Positioned(
            left: 0,
            child: Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background,
                    AppColors.background.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColors.background,
                    AppColors.background.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(double value) {
    if (widget.step >= 1) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
