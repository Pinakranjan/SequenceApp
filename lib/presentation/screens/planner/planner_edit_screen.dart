import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/local_notifications_service.dart';
import '../../../core/utils/title_case_formatter.dart';
import '../../../data/models/planner_entry.dart';
import '../../../data/models/planner_enums.dart';
import '../../../providers/planner_provider.dart';
import '../../widgets/planner/category_chip.dart';
import '../../widgets/planner/priority_chip.dart';

class PlannerEditScreen extends ConsumerStatefulWidget {
  final PlannerEntry? existing;

  const PlannerEditScreen({super.key, this.existing});

  @override
  ConsumerState<PlannerEditScreen> createState() => _PlannerEditScreenState();
}

class _PlannerEditScreenState extends ConsumerState<PlannerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));

  // Reminder is now mandatory - always enabled with default at due time
  Duration _reminderOffset = Duration.zero; // Offset before due time

  // Enhanced fields
  PlannerPriority _priority = PlannerPriority.medium;
  PlannerCategory _category = PlannerCategory.reminder;
  Duration? _estimatedDuration;
  bool _isRecurring = false;
  RecurrenceRule? _recurrence;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _notesController.text = existing.notes;
      _dateTime = existing.dateTime;
      // Reminder is always on - load offset from existing data
      if (existing.reminderAt != null) {
        _reminderOffset = existing.dateTime.difference(existing.reminderAt!);
        if (_reminderOffset.isNegative) _reminderOffset = Duration.zero;
      }
      _priority = existing.priority;
      _category = existing.category;

      _estimatedDuration = existing.estimatedDuration;
      _isRecurring = existing.isRecurring;
      _recurrence = existing.recurrence;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving ? null : _save,
              child:
                  _saving
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                      : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Admit Card download',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
                inputFormatters: [TitleCaseTextInputFormatter()],
              ),
              const SizedBox(height: 16),

              // Notes (moved below Title)
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(Icons.notes),
                      ),
                    ],
                  ),
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
                inputFormatters: [TitleCaseTextInputFormatter()],
              ),
              const SizedBox(height: 16),

              // Priority Section
              Text(
                'Priority',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              PrioritySelector(
                selected: _priority,
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              const SizedBox(height: 16),

              // Category Section
              Text(
                'Category',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CategorySelector(
                selected: _category,
                onChanged: (category) => setState(() => _category = category),
                scrollable: true,
              ),
              const SizedBox(height: 16),

              // Date & Time
              _DateTimeTile(
                label: 'Date & Time',
                value: _dateTime,
                onTap: () async {
                  final picked = await _pickDateTime(
                    context,
                    initial: _dateTime,
                  );
                  if (picked == null) return;
                  setState(() {
                    _dateTime = picked;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Estimated Duration
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Estimated Duration'),
                  subtitle: Text(
                    _estimatedDuration != null
                        ? _formatDuration(_estimatedDuration!)
                        : 'Not set',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickDuration,
                ),
              ),
              const SizedBox(height: 12),

              // Recurring
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.repeat),
                      title: const Text('Recurring'),
                      subtitle: Text(
                        _isRecurring
                            ? (_recurrence?.displayText ?? 'Custom')
                            : 'One-time entry',
                      ),
                      value: _isRecurring,
                      onChanged: (v) async {
                        if (v) {
                          final rule = await _pickRecurrence();
                          if (rule != null) {
                            setState(() {
                              _isRecurring = true;
                              _recurrence = rule;
                            });
                          }
                        } else {
                          setState(() {
                            _isRecurring = false;
                            _recurrence = null;
                          });
                        }
                      },
                    ),
                    if (_isRecurring)
                      ListTile(
                        title: const Text('Change recurrence'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final rule = await _pickRecurrence();
                          if (rule != null) {
                            setState(() {
                              _recurrence = rule;
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reminder (now mandatory)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Reminder'),
                  subtitle: Text(_getReminderOffsetLabel(_reminderOffset)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await _ensurePermissionsUserInitiated();
                    if (!ok) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notifications are disabled. Enable them in Settings to use reminders.',
                          ),
                        ),
                      );
                      // proceed anyway so they can set the offset (saved gracefully later)
                    }
                    final offset = await _pickReminderOffset();
                    if (offset != null) {
                      setState(() {
                        _reminderOffset = offset;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getReminderOffsetLabel(Duration offset) {
    if (offset == Duration.zero) return 'Same with due time';
    if (offset == const Duration(minutes: 2)) return '2 minutes before';
    if (offset == const Duration(minutes: 5)) return '5 minutes before';
    if (offset == const Duration(minutes: 10)) return '10 minutes before';
    if (offset == const Duration(minutes: 15)) return '15 minutes before';
    if (offset == const Duration(minutes: 30)) return '30 minutes before';
    if (offset == const Duration(hours: 1)) return '1 hour before';
    if (offset == const Duration(days: 1)) return '1 day before';
    return '${offset.inMinutes} minutes before';
  }

  Future<Duration?> _pickReminderOffset() async {
    final offsets = <Duration>[
      Duration.zero,
      const Duration(minutes: 2),
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(days: 1),
    ];

    return showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reminder is on',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Switch.adaptive(
                            value: true,
                            onChanged: (v) {
                              if (!v) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...offsets.map(
                      (offset) => ListTile(
                        leading: Icon(
                          offset == _reminderOffset
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              offset == _reminderOffset
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                        title: Text(_getReminderOffsetLabel(offset)),
                        onTap: () => Navigator.pop(context, offset),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) return '$hours hour${hours > 1 ? 's' : ''}';
      return '$hours hr $minutes min';
    }
    return '${duration.inMinutes} minutes';
  }

  Future<void> _pickDuration() async {
    final durations = [
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
      const Duration(hours: 2),
      const Duration(hours: 3),
      const Duration(hours: 4),
    ];

    final selected = await showModalBottomSheet<Duration?>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Estimated Duration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...durations.map(
                      (d) => ListTile(
                        leading:
                            _estimatedDuration == d
                                ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF22C55E),
                                )
                                : const SizedBox(width: 24),
                        title: Text(_formatDuration(d)),
                        onTap: () => Navigator.pop(context, d),
                      ),
                    ),
                    ListTile(
                      leading:
                          _estimatedDuration == null
                              ? const Icon(
                                Icons.check,
                                color: Color(0xFF22C55E),
                              )
                              : const SizedBox(width: 24),
                      title: const Text('No estimate'),
                      onTap: () => Navigator.pop(context, Duration.zero),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
    );

    if (selected != null) {
      setState(() {
        _estimatedDuration = selected == Duration.zero ? null : selected;
      });
    }
  }

  Future<RecurrenceRule?> _pickRecurrence() async {
    int selectedInterval = _recurrence?.interval ?? 1;
    RecurrenceType selectedType = _recurrence?.type ?? RecurrenceType.weekly;
    List<DateTime> selectedDates = List.from(_recurrence?.specificDates ?? []);
    DateTime displayedMonth = DateTime.now();

    return showModalBottomSheet<RecurrenceRule?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Repeat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interval and Type Picker Row
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Interval Picker
                          Expanded(
                            child: SizedBox(
                              height: 120,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setModalState(
                                    () => selectedInterval = index + 1,
                                  );
                                },
                                controller: FixedExtentScrollController(
                                  initialItem: selectedInterval - 1,
                                ),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    final val = index + 1;
                                    final isSelected = val == selectedInterval;
                                    return Center(
                                      child: Text(
                                        val.toString().padLeft(2, '0'),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              color:
                                                  isSelected
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                      : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                            ),
                                      ),
                                    );
                                  },
                                  childCount: 99,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ':',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Type Picker
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 120,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  setModalState(
                                    () =>
                                        selectedType =
                                            RecurrenceType.values[index],
                                  );
                                },
                                controller: FixedExtentScrollController(
                                  initialItem: RecurrenceType.values.indexOf(
                                    selectedType,
                                  ),
                                ),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    final type = RecurrenceType.values[index];
                                    final isSelected = type == selectedType;
                                    // Pluralize based on interval
                                    String label = type.label;
                                    if (selectedInterval > 1) {
                                      switch (type) {
                                        case RecurrenceType.daily:
                                          label = 'Days';
                                          break;
                                        case RecurrenceType.weekly:
                                          label = 'Weeks';
                                          break;
                                        case RecurrenceType.monthly:
                                          label = 'Months';
                                          break;
                                        case RecurrenceType.yearly:
                                          label = 'Years';
                                          break;
                                      }
                                    } else {
                                      switch (type) {
                                        case RecurrenceType.daily:
                                          label = 'Day';
                                          break;
                                        case RecurrenceType.weekly:
                                          label = 'Week';
                                          break;
                                        case RecurrenceType.monthly:
                                          label = 'Month';
                                          break;
                                        case RecurrenceType.yearly:
                                          label = 'Year';
                                          break;
                                      }
                                    }
                                    return Center(
                                      child: Text(
                                        label,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              color:
                                                  isSelected
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                      : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                            ),
                                      ),
                                    );
                                  },
                                  childCount: RecurrenceType.values.length,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Multi-date Calendar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select specific dates (tap to toggle)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Month navigation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () {
                                  setModalState(() {
                                    displayedMonth = DateTime(
                                      displayedMonth.year,
                                      displayedMonth.month - 1,
                                    );
                                  });
                                },
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(displayedMonth),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () {
                                  setModalState(() {
                                    displayedMonth = DateTime(
                                      displayedMonth.year,
                                      displayedMonth.month + 1,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Weekday headers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children:
                                ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                                    .map(
                                      (d) => SizedBox(
                                        width: 36,
                                        child: Center(
                                          child: Text(
                                            d,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 4),
                          // Calendar grid
                          Builder(
                            builder: (context) {
                              final firstDay = DateTime(
                                displayedMonth.year,
                                displayedMonth.month,
                                1,
                              );
                              final lastDay = DateTime(
                                displayedMonth.year,
                                displayedMonth.month + 1,
                                0,
                              );
                              final startWeekday = firstDay.weekday % 7;
                              final days = <Widget>[];

                              for (int i = 0; i < startWeekday; i++) {
                                days.add(const SizedBox());
                              }

                              for (int day = 1; day <= lastDay.day; day++) {
                                final date = DateTime(
                                  displayedMonth.year,
                                  displayedMonth.month,
                                  day,
                                );
                                final normalizedDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                );
                                final isSelected = selectedDates.any(
                                  (d) =>
                                      DateTime(d.year, d.month, d.day) ==
                                      normalizedDate,
                                );
                                final isToday =
                                    DateTime(
                                      DateTime.now().year,
                                      DateTime.now().month,
                                      DateTime.now().day,
                                    ) ==
                                    normalizedDate;

                                days.add(
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        if (isSelected) {
                                          selectedDates.removeWhere(
                                            (d) =>
                                                DateTime(
                                                  d.year,
                                                  d.month,
                                                  d.day,
                                                ) ==
                                                normalizedDate,
                                          );
                                        } else {
                                          selectedDates.add(normalizedDate);
                                        }
                                        selectedDates.sort();
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? theme.colorScheme.primary
                                                : isToday
                                                ? theme
                                                    .colorScheme
                                                    .primaryContainer
                                                : null,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            isToday && !isSelected
                                                ? Border.all(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  width: 1,
                                                )
                                                : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          day.toString(),
                                          style: TextStyle(
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : theme
                                                        .colorScheme
                                                        .onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 7,
                                childAspectRatio: 1.2,
                                children: days,
                              );
                            },
                          ),
                          if (selectedDates.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${selectedDates.length} date${selectedDates.length > 1 ? 's' : ''} selected',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => setModalState(
                                          () => selectedDates.clear(),
                                        ),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Done Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              RecurrenceRule(
                                type: selectedType,
                                interval: selectedInterval,
                                specificDates: selectedDates,
                              ),
                            );
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _ensurePermissionsUserInitiated() async {
    await LocalNotificationsService().initialize();
    return LocalNotificationsService().requestPermissions();
  }

  Future<DateTime?> _pickDateTime(
    BuildContext _, {
    required DateTime initial,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null) return null;

    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final now = DateTime.now();

    final existing = widget.existing;
    final isActiveTask =
        !(existing?.isArchived ?? false) &&
        !(existing?.isFullyCompleted ?? false);

    // Reminder is now mandatory - always calculate
    final desiredReminderAt = _dateTime.subtract(_reminderOffset);

    // Notifications are only allowed for active tasks.
    final reminderAt = isActiveTask ? desiredReminderAt : null;

    if (reminderAt != null && reminderAt.isBefore(now)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final id = existing?.id ?? const Uuid().v4();

      int? notificationId = existing?.notificationId;

      // Cancel old reminder if removing or changing it.
      final hadOldReminder = existing?.reminderAt != null;
      final oldNotificationId = existing?.notificationId;
      final reminderChanged =
          hadOldReminder && (existing!.reminderAt != reminderAt);

      if ((reminderAt == null && hadOldReminder) || reminderChanged) {
        if (oldNotificationId != null) {
          await LocalNotificationsService().cancel(oldNotificationId);
        }
        notificationId = null;
      }

      DateTime? effectiveReminderAt = reminderAt;

      if (reminderAt != null) {
        final ok = await _ensurePermissionsUserInitiated();
        if (!ok) {
          // Permission denied – save the entry anyway but skip the reminder.
          effectiveReminderAt = null;
          notificationId = null;
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Entry saved, but reminders are disabled. '
                  'Enable notifications in Settings to receive reminders.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          notificationId ??= DateTime.now().millisecondsSinceEpoch.remainder(
            1 << 31,
          );

          await LocalNotificationsService().scheduleReminder(
            notificationId: notificationId,
            title: 'Planner reminder',
            body: _titleController.text.trim(),
            scheduledAt: reminderAt,
            payload: 'type=planner&planner_id=$id',
          );
        }
      }

      final entry = PlannerEntry(
        id: id,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        dateTime: _dateTime,
        reminderAt: effectiveReminderAt,
        notificationId: notificationId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        priority: _priority,
        category: _category,
        isCompleted: existing?.isCompleted ?? false,
        subtasks: existing?.subtasks ?? const [],
        estimatedDuration: _estimatedDuration,
        isRecurring: _isRecurring,
        recurrence: _recurrence,
        isArchived: existing?.isArchived ?? false,
      );

      await ref.read(plannerProvider.notifier).upsert(entry);

      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final navigator = Navigator.of(context);

    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete entry?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _saving = true);
    try {
      if (existing.notificationId != null) {
        await LocalNotificationsService().cancel(existing.notificationId!);
      }
      await ref.read(plannerProvider.notifier).delete(existing.id);
      if (!mounted) return;
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: Text(label),
        subtitle: Text(
          DateFormat('EEE, MMM d, yyyy • h:mm a').format(value),
          style: theme.textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
