import 'package:flutter/material.dart';

import '../../../data/models/planner_enums.dart';

/// A chip widget for displaying and selecting task priority.
class PriorityChip extends StatelessWidget {
  final PlannerPriority priority;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showLabel;
  final double size;

  const PriorityChip({
    super.key,
    required this.priority,
    this.isSelected = false,
    this.onTap,
    this.showLabel = true,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(priority.colorValue);
    final theme = Theme.of(context);

    if (!showLabel) {
      // Compact dot indicator
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: isSelected ? Border.all(color: color, width: 2) : null,
          ),
          child:
              isSelected
                  ? Icon(Icons.check, color: Colors.white, size: size * 0.6)
                  : null,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              priority.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal selector for choosing task priority.
class PrioritySelector extends StatelessWidget {
  final PlannerPriority selected;
  final ValueChanged<PlannerPriority> onChanged;

  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          PlannerPriority.values.map((priority) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PriorityChip(
                priority: priority,
                isSelected: priority == selected,
                onTap: () => onChanged(priority),
              ),
            );
          }).toList(),
    );
  }
}

/// A small priority indicator badge for use in cards.
class PriorityBadge extends StatelessWidget {
  final PlannerPriority priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = Color(priority.colorValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
