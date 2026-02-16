import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/planner_enums.dart';

/// A widget for managing subtasks within a planner entry.
class SubtaskList extends StatefulWidget {
  final List<SubTask> subtasks;
  final ValueChanged<List<SubTask>> onChanged;
  final bool editable;

  const SubtaskList({
    super.key,
    required this.subtasks,
    required this.onChanged,
    this.editable = true,
  });

  @override
  State<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends State<SubtaskList> {
  final _addController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final title = _addController.text.trim();
    if (title.isEmpty) return;

    final newSubtask = SubTask(
      id: const Uuid().v4(),
      title: title,
      isCompleted: false,
    );

    widget.onChanged([...widget.subtasks, newSubtask]);
    _addController.clear();
    _focusNode.requestFocus();
  }

  void _toggleSubtask(int index) {
    final updated = widget.subtasks.map((s) => s).toList();
    updated[index] = updated[index].copyWith(
      isCompleted: !updated[index].isCompleted,
    );
    widget.onChanged(updated);
  }

  void _removeSubtask(int index) {
    final updated = [...widget.subtasks];
    updated.removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = widget.subtasks.where((s) => s.isCompleted).length;
    final totalCount = widget.subtasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with progress
        if (widget.subtasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Subtasks',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedCount / $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalCount > 0 ? completedCount / totalCount : 0,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completedCount == totalCount && totalCount > 0
                            ? const Color(0xFF22C55E)
                            : theme.colorScheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Subtask items
        ...widget.subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final subtask = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleSubtask(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color:
                          subtask.isCompleted
                              ? const Color(0xFF22C55E)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            subtask.isCompleted
                                ? const Color(0xFF22C55E)
                                : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                        width: 2,
                      ),
                    ),
                    child:
                        subtask.isCompleted
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subtask.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration:
                          subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                      color:
                          subtask.isCompleted
                              ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              )
                              : null,
                    ),
                  ),
                ),
                if (widget.editable)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    onPressed: () => _removeSubtask(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          );
        }),

        // Add subtask input
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _addController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Add subtask',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyMedium,
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                TextButton(
                  onPressed: _addSubtask,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A compact inline subtask progress indicator.
class SubtaskProgress extends StatelessWidget {
  final List<SubTask> subtasks;
  final double width;
  final double height;

  const SubtaskProgress({
    super.key,
    required this.subtasks,
    this.width = 80,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final completed = subtasks.where((s) => s.isCompleted).length;
    final total = subtasks.length;
    final progress = completed / total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0
                    ? const Color(0xFF22C55E)
                    : theme.colorScheme.primary,
              ),
              minHeight: height,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$completed/$total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
