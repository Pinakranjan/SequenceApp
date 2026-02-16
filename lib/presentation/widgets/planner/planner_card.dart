import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../data/models/planner_entry.dart';
import '../../../data/models/planner_enums.dart';

/// Helper to get IconData from PlannerCategory
IconData _getCategoryIcon(PlannerCategory category) {
  switch (category) {
    case PlannerCategory.exam:
      return Icons.edit_document;
    case PlannerCategory.deadline:
      return Icons.schedule;
    case PlannerCategory.reminder:
      return Icons.notifications;
    case PlannerCategory.document:
      return Icons.description;
    case PlannerCategory.other:
      return Icons.star;
  }
}

/// An enhanced card widget for displaying planner entries.
/// Inspired by Taskly app design with clean, modern aesthetics.
class PlannerCard extends StatefulWidget {
  final PlannerEntry entry;
  final bool isPinned;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleComplete;
  final VoidCallback? onToggleArchive;
  final Future<void> Function() onDelete;
  final Future<void> Function(int minutes)? onSnooze;

  const PlannerCard({
    super.key,
    required this.entry,
    required this.isPinned,
    this.isHighlighted = false,
    required this.onTap,
    required this.onTogglePin,
    required this.onToggleComplete,
    this.onToggleArchive,
    required this.onDelete,
    this.onSnooze,
  });

  @override
  State<PlannerCard> createState() => _PlannerCardState();
}

class _PlannerCardState extends State<PlannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isHighlighted) {
      _glowController.repeat(); // Continuous rotation
    }

    // Periodic timer to refresh snooze countdown every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(PlannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted) {
      // Ensure animation is running if highlighted, regardless of old state
      if (!_glowController.isAnimating) {
        _glowController.repeat();
      }
    } else {
      if (_glowController.isAnimating) {
        _glowController.stop();
      }
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  /// Show snooze time picker dialog
  Future<void> _showSnoozeDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final snoozeMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Snooze for...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('1 minute'),
                    onTap: () => Navigator.pop(context, 1),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('2 minutes'),
                    onTap: () => Navigator.pop(context, 2),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('5 minutes'),
                    onTap: () => Navigator.pop(context, 5),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('10 minutes'),
                    onTap: () => Navigator.pop(context, 10),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('15 minutes'),
                    onTap: () => Navigator.pop(context, 15),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('30 minutes'),
                    onTap: () => Navigator.pop(context, 30),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('1 hour'),
                    onTap: () => Navigator.pop(context, 60),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );

    if (snoozeMinutes != null && widget.onSnooze != null) {
      await widget.onSnooze!(snoozeMinutes);
    }
  }

  String? _getReminderText(DateTime? reminderAt) {
    if (reminderAt == null) return null;
    final now = DateTime.now();
    if (reminderAt.isBefore(now)) return null;

    final diff = reminderAt.difference(now);
    if (diff.inMinutes < 1) return '(in <1m)';
    if (diff.inMinutes < 60) return '(in ${diff.inMinutes}m)';
    if (diff.inHours < 24) {
      final m = diff.inMinutes % 60;
      if (m == 0) return '(in ${diff.inHours}h)';
      return '(in ${diff.inHours}h ${m}m)';
    }
    return '(in ${diff.inDays}d)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final priorityColor = Color(entry.priority.colorValue);
    final categoryColor = Color(entry.category.colorValue);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final isSnoozedActive =
        entry.reminderAt != null && entry.reminderAt!.isAfter(now);
    final snoozeColor =
        isSnoozedActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final isOverdue = entry.dateTime.isBefore(now) && !entry.isFullyCompleted;
    final isToday =
        entry.dateTime.year == now.year &&
        entry.dateTime.month == now.month &&
        entry.dateTime.day == now.day;

    final dateText = _formatDate(entry.dateTime, isToday);
    final timeText = DateFormat('h:mm a').format(entry.dateTime);

    // Soft pastel background color based on category
    // We blend with surface color to ensure opacity, preventing shadows from
    // showing through the card body.
    final baseBg =
        isDark
            ? categoryColor.withValues(alpha: 0.15)
            : categoryColor.withValues(alpha: 0.08);
    final cardBgColor = Color.alphaBlend(baseBg, theme.colorScheme.surface);

    // Subtle left border color
    final leftBorderColor =
        entry.isFullyCompleted ? const Color(0xFF22C55E) : categoryColor;

    return Dismissible(
      key: ValueKey('planner_card_${entry.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Archive Action (Right Swipe)
          if (!entry.isFullyCompleted) return false; // Only archive completed
          if (widget.onToggleArchive != null) {
            widget.onToggleArchive!();
            return false; // Don't dismiss from tree immediately, let state handle move
          }
          return false;
        } else {
          // Delete Action (Left Swipe)
          return await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete Entry?'),
                      content: const Text(
                        'This will remove the planner entry. Any scheduled reminder will be cancelled.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              ) ??
              false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete();
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1), // Indigo for Archive
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              'Archive',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onTogglePin, // Keep long press as backup
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter:
                    widget.isHighlighted
                        ? _GradientBorderPainter(
                          animationValue: _glowController.value,
                          strokeWidth: 3.5,
                          radius: 16,
                        )
                        : null,
                child: Container(
                  // margin moved to parent Padding to allow Painter to draw OUTSIDE this container
                  // but INSIDE the padding
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        widget.isHighlighted
                            ? null // Painted by CustomPainter
                            : Border.all(
                              color:
                                  entry.isFullyCompleted
                                      ? const Color(
                                        0xFF22C55E,
                                      ).withValues(alpha: 0.4)
                                      : categoryColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                  ),
                  child: child,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Left color accent bar (positioned to ensure visibility)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: leftBorderColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Title + Menu icon
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Completion checkbox with Tooltip
                            Tooltip(
                              message:
                                  entry.isFullyCompleted
                                      ? 'Mark as incomplete'
                                      : 'Mark as complete',
                              child: GestureDetector(
                                onTap: widget.onToggleComplete,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(
                                    right: 12,
                                    top: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        entry.isFullyCompleted
                                            ? const Color(0xFF22C55E)
                                            : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          entry.isFullyCompleted
                                              ? const Color(0xFF22C55E)
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.35),
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      entry.isFullyCompleted
                                          ? const Icon(
                                            Icons.task_alt,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            // Title and notes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title.isEmpty
                                        ? '(Untitled)'
                                        : entry.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          decoration:
                                              entry.isFullyCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                          color:
                                              entry.isFullyCompleted
                                                  ? theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.5)
                                                  : null,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Notes preview
                                  if (entry.notes.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.notes.trim(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                            height: 1.3,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Pin + Snooze + Archive + Menu icon area
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Snooze button - for non-completed tasks
                                if (!entry.isFullyCompleted &&
                                    widget.onSnooze != null)
                                  InkWell(
                                    onTap: () => _showSnoozeDialog(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Tooltip(
                                      message:
                                          isSnoozedActive
                                              ? 'Reschedule'
                                              : 'Snooze',
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          6,
                                          0,
                                          6,
                                          6,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.snooze_rounded,
                                              size: 18,
                                              color: snoozeColor,
                                            ),
                                            if (_getReminderText(
                                                  entry.reminderAt,
                                                ) !=
                                                null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Text(
                                                  _getReminderText(
                                                    entry.reminderAt,
                                                  )!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: snoozeColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                // Visible, tappable Pin button with larger hit area
                                InkWell(
                                  onTap: widget.onTogglePin,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Tooltip(
                                    message: widget.isPinned ? 'Unpin' : 'Pin',
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        6,
                                        0,
                                        6,
                                        6,
                                      ),
                                      child: Icon(
                                        widget.isPinned
                                            ? Icons.push_pin_rounded
                                            : Icons.push_pin_outlined,
                                        size: 18,
                                        color:
                                            widget.isPinned
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                                // Archive button - only for completed tasks
                                if (entry.isFullyCompleted &&
                                    widget.onToggleArchive != null)
                                  InkWell(
                                    onTap: widget.onToggleArchive,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Tooltip(
                                      message:
                                          entry.isArchived
                                              ? 'Unarchive'
                                              : 'Archive',
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          6,
                                          0,
                                          6,
                                          6,
                                        ),
                                        child: Icon(
                                          entry.isArchived
                                              ? Icons.unarchive_rounded
                                              : Icons.archive_outlined,
                                          size: 18,
                                          color:
                                              entry.isArchived
                                                  ? const Color(
                                                    0xFF6366F1,
                                                  ) // Indigo
                                                  : theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    0,
                                    0,
                                    6,
                                  ),
                                  child: Icon(
                                    FontAwesomeIcons.calendarDays,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Bottom row: Badges + Time
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Pinned badge removed - pin icon in header is sufficient

                            // Priority badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.priority.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(entry.category),
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.category.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (entry.reminderAt != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.notifications_active_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                            if (entry.isRecurring) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                            const Spacer(),
                            // Time display
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.schedule_rounded,
                                  size: 13,
                                  color:
                                      isOverdue
                                          ? const Color(0xFFEF4444)
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isToday ? timeText : dateText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isOverdue
                                            ? const Color(0xFFEF4444)
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isToday) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (isToday) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    if (dateOnly == tomorrow) return 'Tomorrow';

    // Within this week
    final diff = dateOnly.difference(DateTime(now.year, now.month, now.day));
    if (diff.inDays > 0 && diff.inDays <= 6) {
      return DateFormat('EEEE').format(date);
    }

    return DateFormat('MMM d').format(date);
  }
}

/// Compact badge for category display
class _CompactBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler, compact card variant for search results.
class PlannerCardCompact extends StatelessWidget {
  final PlannerEntry entry;
  final VoidCallback onTap;

  const PlannerCardCompact({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = Color(entry.priority.colorValue);
    final categoryColor = Color(entry.category.colorValue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [priorityColor, categoryColor],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? '(Untitled)' : entry.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          entry.isFullyCompleted
                              ? TextDecoration.lineThrough
                              : null,
                      color:
                          entry.isFullyCompleted
                              ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              )
                              : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d • h:mm a').format(entry.dateTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Category badge
            _CompactBadge(
              icon: _getCategoryIcon(entry.category),
              label: entry.category.label,
              color: categoryColor,
            ),
            if (entry.isFullyCompleted) ...[
              const SizedBox(width: 8),
              const Icon(Icons.task_alt, color: Color(0xFF22C55E), size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double animationValue;
  final double strokeWidth;
  final double radius;

  _GradientBorderPainter({
    required this.animationValue,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Rainbow colors for "running light"
    const colors = [
      Color(0xFFA855F7), // Purple
      Color(0xFF3B82F6), // Blue
      Color(0xFF22C55E), // Green
      Color(0xFFEAB308), // Yellow
      Color(0xFFF97316), // Orange
      Color(0xFFEF4444), // Red
      Color(0xFFA855F7), // Purple (Loop)
    ];

    // Create a sweep gradient that rotates based on animationValue
    // We center it and rotate it
    final gradient = SweepGradient(
      colors: colors,
      stops: const [0.0, 0.17, 0.34, 0.51, 0.68, 0.85, 1.0],
      transform: GradientRotation(animationValue * 2 * 3.14159),
    );

    final paint =
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    // Inset the rect by half stroke width so border stays inside/centered on edge
    final deflatedParams = strokeWidth / 2;
    final path = Path()..addRRect(rrect.deflate(deflatedParams));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
