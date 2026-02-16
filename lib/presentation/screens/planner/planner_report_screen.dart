import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/planner_enums.dart';
import '../../../providers/planner_provider.dart';

class PlannerReportScreen extends ConsumerWidget {
  const PlannerReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(plannerProvider);
    final entries = state.entries;

    // Calculate Stats
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Status Breakdown
    final completed = entries.where((e) => e.isFullyCompleted).toList();
    final incomplete = entries.where((e) => !e.isFullyCompleted).toList();

    final pending =
        incomplete.where((e) {
          final d = e.dateTime;
          final date = DateTime(d.year, d.month, d.day);
          return !date.isAfter(today); // Today or past
        }).toList();

    final upcoming =
        incomplete.where((e) {
          final d = e.dateTime;
          final date = DateTime(d.year, d.month, d.day);
          return date.isAfter(today); // Future
        }).toList();

    // Priority Breakdown (All Incomplete)
    final urgent =
        incomplete.where((e) => e.priority == PlannerPriority.high).toList();
    final important =
        incomplete.where((e) => e.priority == PlannerPriority.medium).toList();
    final optional =
        incomplete.where((e) => e.priority == PlannerPriority.low).toList();

    // Weekly Productivity (Completed tasks per day)
    final currentWeekday = now.weekday;
    final weekStart = today.subtract(Duration(days: currentWeekday - 1));
    final weeklyCompleted = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return completed.where((e) {
        final d = e.dateTime;
        final date = DateTime(d.year, d.month, d.day);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).length;
    });

    // Weekly Pending (Scheduled this week but not done)
    final weeklyPending = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return incomplete.where((e) {
        final d = e.dateTime;
        final date = DateTime(d.year, d.month, d.day);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).length;
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Report & Analysis',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // summary Card
            _SummaryCard(
              pending: pending.length,
              completed: completed.length,
              upcoming: upcoming.length,
            ),
            const SizedBox(height: 16),

            // Productivity Insight
            _ProductivityCard(
              weeklyCompleted: weeklyCompleted,
              weeklyPending: weeklyPending,
            ),
            const SizedBox(height: 16),

            // Priority Breakdown
            _PriorityCard(
              urgent: urgent.length,
              important: important.length,
              optional: optional.length,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pending;
  final int completed;
  final int upcoming;

  const _SummaryCard({
    required this.pending,
    required this.completed,
    required this.upcoming,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Light mode: Light Gray (Gray 100)
    // Dark mode: Surface Container
    final cardColor =
        isDark ? theme.colorScheme.surfaceContainer : Colors.grey[300];
    final titleColor =
        isDark ? Colors.white : const Color(0xFF1E3A8A); // Deep Blue

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Summary card',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              Icon(Icons.segment, color: titleColor),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 120,
                width: 120,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    values: [
                      _ChartValue(
                        pending.toDouble(),
                        const Color(0xFF84CC16),
                      ), // Lime 500
                      _ChartValue(
                        completed.toDouble(),
                        const Color(0xFF8B5CF6),
                      ), // Violet 500
                      _ChartValue(
                        upcoming.toDouble(),
                        const Color(0xFFEAB308),
                      ), // Yellow 500
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      color: const Color(0xFF84CC16),
                      label: 'Pending',
                      value: pending,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: const Color(0xFF8B5CF6),
                      label: 'Completed',
                      value: completed,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: const Color(0xFFEAB308),
                      label: 'Upcoming',
                      value: upcoming,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductivityCard extends StatelessWidget {
  final List<int> weeklyCompleted;
  final List<int> weeklyPending;

  const _ProductivityCard({
    required this.weeklyCompleted,
    required this.weeklyPending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        isDark ? theme.colorScheme.surfaceContainer : Colors.grey[300];
    final titleColor = isDark ? Colors.white : const Color(0xFF1E3A8A);
    final axisColor =
        isDark ? theme.colorScheme.onSurfaceVariant : Colors.grey[600];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Determine max Y for scale
    int maxVal = 0;
    for (int i = 0; i < 7; i++) {
      if (weeklyCompleted[i] > maxVal) maxVal = weeklyCompleted[i];
      if (weeklyPending[i] > maxVal) maxVal = weeklyPending[i];
    }
    if (maxVal == 0) maxVal = 5;
    maxVal = (maxVal * 1.2).ceil(); // Add buffer

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productivity Insight',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendDot(
                color: const Color(0xFFEAB308),
                label: 'Upcoming/Pend',
              ),
              const SizedBox(width: 12),
              _LegendDot(color: const Color(0xFF8B5CF6), label: 'Completed'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y Axis
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final val = maxVal - (maxVal * index / 5).round();
                    return Text(
                      '$val',
                      style: TextStyle(fontSize: 10, color: axisColor),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                // Chart
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      final pRatio = weeklyPending[index] / maxVal;
                      final cRatio = weeklyCompleted[index] / maxVal;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Side by side bars
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _Bar(
                                      heightFactor: pRatio,
                                      color: const Color(0xFFEAB308),
                                    ),
                                    const SizedBox(width: 4),
                                    _Bar(
                                      heightFactor: cRatio,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: axisColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
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

class _Bar extends StatelessWidget {
  final double heightFactor;
  final Color color;

  const _Bar({required this.heightFactor, required this.color});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: heightFactor.clamp(0.01, 1.0),
      child: Container(
        width: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final int urgent;
  final int important;
  final int optional;

  const _PriorityCard({
    required this.urgent,
    required this.important,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        isDark ? theme.colorScheme.surfaceContainer : Colors.grey[300];
    final titleColor = isDark ? Colors.white : const Color(0xFF1E3A8A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Priority Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              Icon(Icons.segment, color: titleColor),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 120,
                width: 120,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    values: [
                      _ChartValue(
                        urgent.toDouble(),
                        const Color(0xFFEF4444),
                      ), // Red 500
                      _ChartValue(
                        important.toDouble(),
                        const Color(0xFFF59E0B),
                      ), // Amber 500
                      _ChartValue(
                        optional.toDouble(),
                        const Color(0xFF10B981),
                      ), // Emerald 500
                    ],
                    width: 24,
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      color: const Color(0xFFEF4444),
                      label: 'Urgent',
                      value: urgent,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: const Color(0xFFF59E0B),
                      label: 'Important',
                      value: important,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: const Color(0xFF10B981),
                      label: 'Optional',
                      value: optional,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurfaceVariant
            : const Color(0xFF475569); // Slate 600 - Readable on Grey 100

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($value)',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurfaceVariant
            : const Color(0xFF475569);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// --- Chart Painters ---

class _ChartValue {
  final double value;
  final Color color;
  const _ChartValue(this.value, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_ChartValue> values;

  _PieChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (sum, item) => sum + item.value);
    if (total == 0) return;

    double startAngle = -pi / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    for (final item in values) {
      final sweepAngle = (item.value / total) * 2 * pi;
      final paint =
          Paint()
            ..color = item.color
            ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartValue> values;
  final double width;

  _DonutChartPainter({required this.values, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (sum, item) => sum + item.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw background circle
    final bgPaint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width;
    canvas.drawCircle(center, radius - width / 2, bgPaint);

    if (total == 0) return;

    double startAngle = -pi / 2;

    for (final item in values) {
      final sweepAngle = (item.value / total) * 2 * pi;
      final paint =
          Paint()
            ..color = item.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - width / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
