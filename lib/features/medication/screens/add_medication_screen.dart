import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/notification_service.dart';
import '../../doctor/data/medicine_library.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.existing});

  // Pass an existing medication to pre-fill the form and enter edit mode
  final MedicationModel? existing;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _pillsController = TextEditingController();
  final _searchController = TextEditingController();

  String _frequency = 'Once daily';
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;
  List<Medicine> _searchResults = [];
  bool _showSearch = true;

  bool get _isEditMode => widget.existing != null;

  static const _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
  ];
  static const _frequencyTimeCounts = {
    'Once daily': 1,
    'Twice daily': 2,
    'Three times daily': 3,
  };
  static const _defaultTimes = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ];
  static const _timeLabels = [
    'Morning dose',
    'Afternoon dose',
    'Evening dose',
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.existing;
    if (med != null) {
      _showSearch = false;
      _nameController.text = med.name;
      _dosageController.text = med.dosage;
      _notesController.text = med.notes;
      _frequency = med.frequency;
      _startDate = med.startDate;
      if (med.pillsRemaining != null) {
        _pillsController.text = med.pillsRemaining.toString();
      }
      _times = med.times.map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _pillsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _searchResults = medicineLibrary
          .where((m) =>
              m.name.toLowerCase().contains(lower) ||
              m.category.toLowerCase().contains(lower))
          .toList();
    });
  }

  void _selectMedicine(Medicine medicine) {
    _nameController.text = medicine.name;
    _dosageController.text = medicine.defaultDosage;
    final freq = medicine.defaultFrequency;
    if (_frequencyTimeCounts.containsKey(freq)) {
      _onFrequencyChanged(freq);
    }
    setState(() {
      _searchResults = [];
      _searchController.clear();
      _showSearch = false;
    });
  }

  void _onFrequencyChanged(String freq) {
    final count = _frequencyTimeCounts[freq]!;
    setState(() {
      _frequency = freq;
      _times = List.generate(
        count,
        (i) => i < _times.length ? _times[i] : _defaultTimes[i],
      );
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeScrollPicker(initialTime: _times[index]),
    );
    if (picked != null && mounted) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  int? _parsedPills() {
    final text = _pillsController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final existing = widget.existing;
    final pills = _parsedPills();
    final resetNotified = pills != null && pills > 7;

    final med = MedicationModel(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      frequency: _frequency,
      times: _times.map(_formatTime).toList(),
      startDate: _startDate,
      notes: _notesController.text.trim(),
      pillsRemaining: pills,
      pillsPerDose: 1,
      // Clear the notification flag if the user refilled above threshold
      lowSupplyNotified: resetNotified ? false : (existing?.lowSupplyNotified ?? false),
    );

    await NotificationService.initialize();
    await NotificationService.requestPermissions();

    if (_isEditMode) {
      // Cancel old scheduled reminders before re-scheduling with updated times
      await NotificationService.cancelMedicationReminder(
          existing!.id, existing.times.length);
      await MedicationService.update(med);
      await NotificationService.scheduleMedicationReminder(med);

      // If the user refilled above threshold, cancel any pending supply alert
      if (resetNotified) {
        await NotificationService.cancelLowSupplyAlert(med.id);
      }
    } else {
      await MedicationService.add(med);
      await NotificationService.scheduleMedicationReminder(med);
    }

    if (!mounted) return;
    // Pop with the saved model so callers can update their state immediately
    Navigator.of(context).pop(med);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit Medication' : 'Add Medication',
          style: AppTextStyles.heading3,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showSearch && !_isEditMode) ...[
                _buildSearchSection(),
                const SizedBox(height: 20),
              ],
              NuvitaTextField(
                label: 'Medication Name',
                hint: 'e.g. Metformin',
                controller: _nameController,
                prefixIcon: Icons.medication_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Dosage',
                hint: 'e.g. 500mg',
                controller: _dosageController,
                prefixIcon: Icons.colorize_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Dosage is required' : null,
              ),
              const SizedBox(height: 24),
              Text('How often?', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildFrequencySelector(),
              const SizedBox(height: 24),
              Text('Reminder times', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              ...List.generate(
                _times.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTimePicker(i),
                ),
              ),
              const SizedBox(height: 12),
              Text('Start date', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 24),
              Text('Pill supply', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              NuvitaTextField(
                label: 'Number of pills remaining (optional)',
                hint: 'Leave empty to skip tracking',
                controller: _pillsController,
                prefixIcon: Icons.inventory_2_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              NuvitaTextField(
                label: 'Notes (optional)',
                hint: 'Take with food, avoid grapefruit...',
                controller: _notesController,
                prefixIcon: Icons.notes_rounded,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              NuvitaButton(
                label: _isEditMode ? 'Save Changes' : 'Save Medication',
                onPressed: _onSave,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Search medicine', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by name or category...',
              hintStyle: AppTextStyles.bodySmall,
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.secondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.secondary, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.divider.withOpacity(0.6),
              ),
              itemBuilder: (_, i) {
                final med = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.medication_rounded,
                      color: AppColors.primary, size: 22),
                  title: Text(
                    med.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${med.category}  ·  ${med.defaultDosage}  ·  ${med.type}',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  onTap: () => _selectMedicine(med),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      children: _frequencies.map((freq) {
        final isSelected = _frequency == freq;
        return GestureDetector(
          onTap: () => _onFrequencyChanged(freq),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.07)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color:
                      isSelected ? AppColors.primary : AppColors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  freq,
                  style: AppTextStyles.body.copyWith(
                    color:
                        isSelected ? AppColors.primary : AppColors.textDark,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker(int index) {
    final label = _timeLabels[index];
    final time = _times[index];
    final display = time.format(context);

    return GestureDetector(
      onTap: () => _pickTime(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickStartDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starting from', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  _formatDate(_startDate),
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scroll wheel time picker ──

class _TimeScrollPicker extends StatefulWidget {
  final TimeOfDay initialTime;
  const _TimeScrollPicker({required this.initialTime});

  @override
  State<_TimeScrollPicker> createState() => _TimeScrollPickerState();
}

class _TimeScrollPickerState extends State<_TimeScrollPicker> {
  static const _itemExtent = 52.0;

  // 96 slots: 24 hours × 4 (15-min intervals)
  static final _slots = List.generate(96, (i) {
    final hour = i ~/ 4;
    final minute = (i % 4) * 15;
    return TimeOfDay(hour: hour, minute: minute);
  });

  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _closestIndex(widget.initialTime);
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _closestIndex(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    int best = 0;
    int bestDiff = 9999;
    for (int i = 0; i < _slots.length; i++) {
      final slotMin = _slots[i].hour * 60 + _slots[i].minute;
      final diff = (slotMin - totalMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  String _formatSlot(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')} : $m  $p';
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
            height: _itemExtent * 5,
            child: Stack(
              children: [
                // Selection highlight lines
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        color: Colors.white24,
                      ),
                      SizedBox(height: _itemExtent - 2),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        color: Colors.white24,
                      ),
                    ],
                  ),
                ),
                // Scroll wheel
                ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: _itemExtent,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 6,
                  perspective: 0.003,
                  onSelectedItemChanged: (i) {
                    setState(() => _selectedIndex = i);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _slots.length,
                    builder: (context, i) {
                      final isSelected = i == _selectedIndex;
                      return Center(
                        child: Text(
                          _formatSlot(_slots[i]),
                          style: TextStyle(
                            fontSize: isSelected ? 26 : 18,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : Colors.white38,
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    },
                  ),
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
                onPressed: () =>
                    Navigator.pop(context, _slots[_selectedIndex]),
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
