import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/home_navigation_provider.dart';
import '../../../providers/notice_reminder_provider.dart';
import '../../../providers/planner_provider.dart';
import 'planner_edit_screen.dart';

enum _PlannerItemType { plannerEntry, noticeReminder }

class _PlannerSearchItem {
  final _PlannerItemType type;
  final String id;
  final String title;
  final String? subtitle;
  final DateTime when;

  const _PlannerSearchItem({
    required this.type,
    required this.id,
    required this.title,
    required this.when,
    this.subtitle,
  });
}

class PlannerSearchScreen extends ConsumerStatefulWidget {
  const PlannerSearchScreen({super.key});

  @override
  ConsumerState<PlannerSearchScreen> createState() =>
      _PlannerSearchScreenState();
}

class _PlannerSearchScreenState extends ConsumerState<PlannerSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final plannerState = ref.watch(plannerProvider);
    final noticeRemindersAsync = ref.watch(noticeRemindersProvider);

    final allItems = <_PlannerSearchItem>[
      ...plannerState.entries
          .where((e) => !e.isArchived)
          .map(
            (e) => _PlannerSearchItem(
              type: _PlannerItemType.plannerEntry,
              id: e.id,
              title: e.title,
              subtitle: e.notes.trim().isEmpty ? null : e.notes.trim(),
              when: e.dateTime,
            ),
          ),
      ...noticeRemindersAsync.valueOrNull
              ?.map(
                (r) => _PlannerSearchItem(
                  type: _PlannerItemType.noticeReminder,
                  id: r.newsId.toString(),
                  title: r.noticeTitle,
                  when: r.scheduledAt,
                ),
              )
              .toList() ??
          const <_PlannerSearchItem>[],
    ];

    final query = _controller.text.trim().toLowerCase();
    final filtered =
        query.isEmpty
            ? allItems
            : allItems.where((item) {
              if (item.title.toLowerCase().contains(query)) return true;
              final sub = item.subtitle;
              if (sub != null && sub.toLowerCase().contains(query)) return true;
              return false;
            }).toList();

    filtered.sort((a, b) => a.when.compareTo(b.when));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: theme.textTheme.bodyLarge,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              suffixIcon:
                  _controller.text.isNotEmpty
                      ? GestureDetector(
                        onTap: () => setState(() => _controller.clear()),
                        child: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                      )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final whenText = DateFormat('EEE, MMM d • h:mm a').format(item.when);

          final leadingIcon = switch (item.type) {
            _PlannerItemType.plannerEntry => Icons.event_note,
            _PlannerItemType.noticeReminder => Icons.notifications_active,
          };

          return ListTile(
            leading: Icon(
              leadingIcon,
              color:
                  theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.primary,
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.subtitle == null ? whenText : '$whenText\n${item.subtitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              if (item.type == _PlannerItemType.plannerEntry) {
                final match = ref
                    .read(plannerProvider)
                    .entries
                    .where((e) => e.id == item.id);
                final entry = match.isEmpty ? null : match.first;
                if (entry == null) return;

                final navigator = Navigator.of(context);
                await navigator.push(
                  MaterialPageRoute(
                    builder: (_) => PlannerEditScreen(existing: entry),
                  ),
                );
                if (!mounted) return;
                navigator.pop();
                return;
              }

              // Notice reminder: Notices tab has been removed.
              // Keep behavior safe by returning to Home on Orders.
              const ordersTabIndex = 0;
              final visited = ref.read(visitedTabsProvider);
              ref.read(visitedTabsProvider.notifier).state = {
                ...visited,
                ordersTabIndex,
              };
              ref.read(homeTabIndexProvider.notifier).state = ordersTabIndex;

              if (!mounted) return;
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}
