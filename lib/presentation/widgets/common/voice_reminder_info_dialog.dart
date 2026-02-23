import 'package:flutter/material.dart';

/// Dialog showing how to use voice command reminders with examples.
///
/// Can be shown via:
/// ```dart
/// VoiceReminderInfoDialog.show(context);
/// ```
class VoiceReminderInfoDialog {
  VoiceReminderInfoDialog._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InfoSheet(),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.mic,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Reminders',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Set reminders by speaking',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Examples
              Text(
                'Example Commands',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),

              _ExampleTile(
                icon: '🗓️',
                command: '"Remind me tomorrow at 3 PM"',
                description: 'Sets a reminder for tomorrow at 3:00 PM',
              ),
              _ExampleTile(
                icon: '⏰',
                command: '"In 2 hours about admit card"',
                description: 'Reminder 2 hours from now with title',
              ),
              _ExampleTile(
                icon: '📅',
                command: '"Meeting with HOD on Monday at 5 PM"',
                description: 'Day + time in any order, title extracted',
              ),
              _ExampleTile(
                icon: '🔴',
                command: '"Hi priority exam tomorrow physics"',
                description: 'Priority & category detected automatically',
              ),
              _ExampleTile(
                icon: '🕐',
                command: '"Monday 17 hours Meeting with HOD"',
                description: '24-hour format also works',
              ),
              _ExampleTile(
                icon: '📝',
                command: '"In 5 min call mom with note wish birthday"',
                description: 'Adds a description/note to the reminder',
              ),

              const SizedBox(height: 20),

              // Section: Tips
              Text(
                'Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),

              _TipItem(
                icon: Icons.record_voice_over,
                text: 'Speak clearly — you have 30s, pauses up to 5s are fine',
              ),
              _TipItem(
                icon: Icons.swap_horiz,
                text:
                    'Time & day can be in any order: "Monday 5 PM" or "5 PM Monday"',
              ),
              _TipItem(
                icon: Icons.edit_note,
                text: 'You can always edit the details after voice input',
              ),
              _TipItem(
                icon: Icons.flag,
                text:
                    'Say "hi/high/low priority" — fuzzy matching for speech variants',
              ),
              _TipItem(
                icon: Icons.delete_outline,
                text: 'Say "Remove reminder" to delete an existing one',
              ),
              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  final String icon;
  final String command;
  final String description;

  const _ExampleTile({
    required this.icon,
    required this.command,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
