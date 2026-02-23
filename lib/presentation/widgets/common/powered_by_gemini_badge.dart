import 'dart:math';
import 'package:flutter/material.dart';

/// Animated "✨ Powered by Gemini" badge with a running rainbow border.
/// Shows for 10 seconds, then fades out.
class PoweredByGeminiBadge extends StatefulWidget {
  final VoidCallback onDone;
  const PoweredByGeminiBadge({super.key, required this.onDone});

  @override
  State<PoweredByGeminiBadge> createState() => _PoweredByGeminiBadgeState();
}

class _PoweredByGeminiBadgeState extends State<PoweredByGeminiBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _masterOpacity = 1.0;

  static const _colors = [
    Color(0xFF4285F4), // Blue
    Color(0xFF9B72CB), // Purple
    Color(0xFFD96570), // Red/Pink
    Color(0xFFF4B400), // Yellow
    Color(0xFF0F9D58), // Green
    Color(0xFF4285F4), // Blue (loop)
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Visible for 10 seconds, then fade out
    Future.delayed(const Duration(milliseconds: 9500), () {
      if (!mounted) return;
      _controller.stop();
      setState(() => _masterOpacity = 0.0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return AnimatedOpacity(
      opacity: _masterOpacity,
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final angle = t * 2 * pi;
                final bx = cos(angle);
                final by = sin(angle);
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _colors,
                      begin: Alignment(bx, by),
                      end: Alignment(-bx, -by),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.5),
                      color: surface,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'Powered by Gemini',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
