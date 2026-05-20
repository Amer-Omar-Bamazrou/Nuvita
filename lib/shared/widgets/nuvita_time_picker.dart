import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

Future<TimeOfDay?> showNuvitaTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _NuvitaTimePicker(initialTime: initialTime),
  );
}

class _NuvitaTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  const _NuvitaTimePicker({required this.initialTime});

  @override
  State<_NuvitaTimePicker> createState() => _NuvitaTimePickerState();
}

class _NuvitaTimePickerState extends State<_NuvitaTimePicker> {
  static const _itemExtent = 52.0;
  static const _visibleItems = 5;

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _periodCtrl;

  late int _hour;
  late int _minute;
  late int _period;

  @override
  void initState() {
    super.initState();
    final h12 = widget.initialTime.hourOfPeriod;
    _hour = (h12 == 0 ? 11 : h12 - 1);
    _minute = widget.initialTime.minute;
    _period = widget.initialTime.period == DayPeriod.am ? 0 : 1;

    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _periodCtrl = FixedExtentScrollController(initialItem: _period);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _buildResult() {
    final displayHour = _hour + 1;
    int hour24;
    if (_period == 0) {
      hour24 = displayHour == 12 ? 0 : displayHour;
    } else {
      hour24 = displayHour == 12 ? 12 : displayHour + 12;
    }
    return TimeOfDay(hour: hour24, minute: _minute);
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onChanged,
    required int selected,
    double width = 70,
  }) {
    return SizedBox(
      width: width,
      height: _itemExtent * _visibleItems,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 6,
        perspective: 0.003,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, i) {
            final isSelected = i == selected;
            return Center(
              child: Text(
                labelBuilder(i),
                style: TextStyle(
                  fontSize: isSelected ? 26 : 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3C3C3C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: _itemExtent * _visibleItems,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: Colors.white24, width: 1),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWheel(
                      controller: _hourCtrl,
                      itemCount: 12,
                      labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) => setState(() => _hour = i),
                      selected: _hour,
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    _buildWheel(
                      controller: _minuteCtrl,
                      itemCount: 60,
                      labelBuilder: (i) => i.toString().padLeft(2, '0'),
                      onChanged: (i) => setState(() => _minute = i),
                      selected: _minute,
                    ),
                    const SizedBox(width: 8),
                    _buildWheel(
                      controller: _periodCtrl,
                      itemCount: 2,
                      labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                      onChanged: (i) => setState(() => _period = i),
                      selected: _period,
                      width: 60,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _buildResult()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
