import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../data/models/planner_enums.dart';

import '../../widgets/planner/category_chip.dart';
import '../../widgets/planner/priority_chip.dart';

class NoticeReminderSettings {
  final DateTime scheduledAt;
  final PlannerPriority priority;
  final PlannerCategory category;
  final RecurrenceRule? recurrence;
  final Duration reminderOffset;

  NoticeReminderSettings({
    required this.scheduledAt,
    required this.priority,
    required this.category,
    this.recurrence,
    required this.reminderOffset,
  });
}

class NoticeReminderSheet extends StatefulWidget {
  final DateTime? initialDateTime;
  final PlannerPriority initialPriority;
  final PlannerCategory initialCategory;
  final RecurrenceRule? initialRecurrence;
  final Duration initialReminderOffset;

  const NoticeReminderSheet({
    super.key,
    this.initialDateTime,
    this.initialPriority = PlannerPriority.medium,
    this.initialCategory = PlannerCategory.deadline,
    this.initialRecurrence,
    this.initialReminderOffset = Duration.zero,
  });

  @override
  State<NoticeReminderSheet> createState() => _NoticeReminderSheetState();
}

class _NoticeReminderSheetState extends State<NoticeReminderSheet> {
  late DateTime _dateTime;
  late PlannerPriority _priority;
  late PlannerCategory _category;
  late RecurrenceRule? _recurrence;
  late Duration _reminderOffset;
  late bool _isRecurring;
  late bool _enableReminder;

  @override
  void initState() {
    super.initState();
    _dateTime =
        widget.initialDateTime ?? DateTime.now().add(const Duration(hours: 1));
    _priority = widget.initialPriority;
    _category = widget.initialCategory;
    _recurrence = widget.initialRecurrence;
    _isRecurring = _recurrence != null;
    _reminderOffset = widget.initialReminderOffset;
    _enableReminder =
        _reminderOffset != Duration.zero || _dateTime.isAfter(DateTime.now());
    // If offset is zero but date is future, we can assume reminder is effectively "on" at the due time
    // But logic in planner was explicit _enableReminder field. Let's start with true if editing, or false if new?
    // Actually, for notice, we are setting a *reminder*. So it is always enabled if we are here.
    // Wait, the "Reminders" section in Planner had an "on/off" toggle.
    // For Notice, the whole feature IS a reminder.
    // EXCEPT: The user might want to just add it to planner without a notification?
    // "Set Reminder" implies notification.
    // Retaining logic: The "Reminder" toggle in planner controls if a *notification* fires before the due time.
    // Here, "Scheduled At" IS the reminder time usually.
    // But if we add Offset, then "Scheduled At" becomes the "Due Date" and (Due - Offset) is the notification time.
    // Let's assume _dateTime is the "Event Time" / "Due Date".
    _enableReminder = true; // Default to true since user clicked "Set Reminder"
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(top: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Scaffold(
        // Scaffold needed for body/appbar structure in sheet? Or just Column.
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Reminder',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        NoticeReminderSettings(
                          scheduledAt: _dateTime,
                          priority: _priority,
                          category: _category,
                          recurrence: _isRecurring ? _recurrence : null,
                          reminderOffset:
                              _enableReminder ? _reminderOffset : Duration.zero,
                          // Wait, if _enableReminder is false, offset should effectively be ignored or treated as zero?
                          // If false, should we even schedule a notification?
                          // The Planner logic: if enableReminder is false, reminderAt is null.
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date & Time
                  _DateTimeTile(
                    label: 'Date & Time',
                    value: _dateTime,
                    onTap: () async {
                      final picked = await _pickDateTime(initial: _dateTime);
                      if (picked != null) {
                        setState(() => _dateTime = picked);
                      }
                    },
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
                    onChanged:
                        (priority) => setState(() => _priority = priority),
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
                    onChanged:
                        (category) => setState(() => _category = category),
                    scrollable: false,
                  ),
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 16),

                  // Reminder Offset
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          secondary: const Icon(Icons.notifications_active),
                          title: const Text('Reminder Notification'),
                          subtitle: Text(
                            _enableReminder
                                ? _getReminderOffsetLabel(_reminderOffset)
                                : 'Off',
                          ),
                          value: _enableReminder,
                          onChanged: (v) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (v) {
                              final ok =
                                  await _ensurePermissionsUserInitiated();
                              if (!ok) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notifications are disabled. Enable them in Settings to use reminders.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Show picker immediately when enabling
                              if (!mounted) return;
                              final offset = await _pickReminderOffset();
                              if (offset != null) {
                                setState(() {
                                  _enableReminder = true;
                                  _reminderOffset = offset;
                                });
                              }
                            } else {
                              setState(() {
                                _enableReminder = false;
                              });
                            }
                          },
                        ),
                        if (_enableReminder)
                          ListTile(
                            title: const Text('Change reminder time'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final offset = await _pickReminderOffset();
                              if (offset != null) {
                                setState(() {
                                  _reminderOffset = offset;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Methods Copied/Adapted from PlannerEditScreen ---

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
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

  Future<bool> _ensurePermissionsUserInitiated() async {
    await LocalNotificationsService().initialize();
    return LocalNotificationsService().requestPermissions();
  }

  String _getReminderOffsetLabel(Duration offset) {
    if (offset == Duration.zero) return 'At time of event';
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
                            'Reminder Notification',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                    // Interval/Type Picker
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
                          Expanded(
                            child: SizedBox(
                              height: 120,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged:
                                    (index) => setModalState(
                                      () => selectedInterval = index + 1,
                                    ),
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
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 120,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged:
                                    (index) => setModalState(
                                      () =>
                                          selectedType =
                                              RecurrenceType.values[index],
                                    ),
                                controller: FixedExtentScrollController(
                                  initialItem: RecurrenceType.values.indexOf(
                                    selectedType,
                                  ),
                                ),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    final type = RecurrenceType.values[index];
                                    final isSelected = type == selectedType;
                                    return Center(
                                      child: Text(
                                        type.label, // Simplified label logic for brevity
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed:
                                    () => setModalState(
                                      () =>
                                          displayedMonth = DateTime(
                                            displayedMonth.year,
                                            displayedMonth.month - 1,
                                          ),
                                    ),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(displayedMonth),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed:
                                    () => setModalState(
                                      () =>
                                          displayedMonth = DateTime(
                                            displayedMonth.year,
                                            displayedMonth.month + 1,
                                          ),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Calendar Grid (Simplified for brevity, but functional structure)
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
                                final normalized = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                );
                                final isSelected = selectedDates.any(
                                  (d) =>
                                      DateTime(d.year, d.month, d.day) ==
                                      normalized,
                                );
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
                                                normalized,
                                          );
                                        } else {
                                          selectedDates.add(normalized);
                                        }
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? theme.colorScheme.primary
                                                : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          day.toString(),
                                          style: TextStyle(
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : theme
                                                        .colorScheme
                                                        .onSurface,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
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
                                  Text('${selectedDates.length} selected'),
                                  const Spacer(),
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
