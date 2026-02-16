import 'package:flutter/material.dart';

import '../../../data/models/planner_enums.dart';

/// A chip widget for displaying and selecting task category.
class CategoryChip extends StatelessWidget {
  final PlannerCategory category;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showLabel;

  const CategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
    this.showLabel = true,
  });

  IconData get _icon {
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

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    final theme = Theme.of(context);

    if (!showLabel) {
      // Icon only
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: isSelected ? Border.all(color: color, width: 2) : null,
          ),
          child: Icon(
            _icon,
            color: isSelected ? Colors.white : color,
            size: 20,
          ),
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
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: isSelected ? Colors.white : color, size: 16),
            const SizedBox(width: 6),
            Text(
              category.label,
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

/// A horizontal scrollable selector for choosing task category.
class CategorySelector extends StatelessWidget {
  final PlannerCategory selected;
  final ValueChanged<PlannerCategory> onChanged;
  final bool scrollable;

  const CategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips =
        PlannerCategory.values.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CategoryChip(
              category: category,
              isSelected: category == selected,
              onTap: () => onChanged(category),
            ),
          );
        }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          PlannerCategory.values.map((category) {
            return CategoryChip(
              category: category,
              isSelected: category == selected,
              onTap: () => onChanged(category),
            );
          }).toList(),
    );
  }
}

/// A small category indicator badge for use in cards.
class CategoryBadge extends StatelessWidget {
  final PlannerCategory category;
  final bool compact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.compact = false,
  });

  IconData get _icon {
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

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(_icon, color: color, size: 14),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            category.label,
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
