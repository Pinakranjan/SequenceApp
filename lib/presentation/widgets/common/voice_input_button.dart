import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/voice_reminder_service.dart';
import '../../../providers/connectivity_provider.dart';

/// A bottom-sheet overlay for voice input with real-time transcription.
///
/// Usage:
/// ```dart
/// final result = await VoiceInputOverlay.show(context);
/// if (result != null && result.hasDateTime) { … }
/// ```
class VoiceInputOverlay {
  VoiceInputOverlay._();

  /// Show the voice input overlay and return the parsed result.
  static Future<VoiceReminderResult?> show(BuildContext context) {
    return showModalBottomSheet<VoiceReminderResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder:
          (context) => Consumer(
            builder: (context, ref, child) {
              final isOffline = ref.watch(isOfflineProvider);
              const grayscaleMatrix = ColorFilter.matrix(<double>[
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]);
              const transparentFilter = ColorFilter.mode(
                Colors.transparent,
                BlendMode.dst,
              );
              return ColorFiltered(
                colorFilter: isOffline ? grayscaleMatrix : transparentFilter,
                child: const _VoiceInputSheet(),
              );
            },
          ),
    );
  }
}

class _VoiceInputSheet extends StatefulWidget {
  const _VoiceInputSheet();

  @override
  State<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<_VoiceInputSheet> {
  final VoiceReminderService _service = VoiceReminderService();

  _ListeningState _state = _ListeningState.initializing;
  String _recognizedText = '';
  double _confidence = 0.0;
  String? _errorMessage;
  String _processingStatus = 'Analyzing your command...';
  String? _fallbackReason;
  bool _showGeminiBadge = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    if (_service.isListening) {
      _service.cancelListening();
    }
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _state = _ListeningState.initializing;
      _recognizedText = '';
      _errorMessage = null;
    });

    final available = await _service.initialize();
    if (!available) {
      if (!mounted) return;
      setState(() {
        _state = _ListeningState.error;
        _errorMessage = 'Speech recognition is not available on this device.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _state = _ListeningState.listening);

    // Haptic feedback on start
    HapticFeedback.mediumImpact();

    await _service.startListening(
      onResult: (text, isFinal, confidence) {
        if (!mounted) return;
        setState(() {
          _recognizedText = text;
          _confidence = confidence;
        });
        // Don't auto-process on isFinal — let the user speak longer
        // sentences and tap 'Done' when ready.
      },
      onDone: () {
        if (!mounted) return;
        // Only show error if listening stopped with no text at all
        if (_state == _ListeningState.listening && _recognizedText.isEmpty) {
          setState(() {
            _state = _ListeningState.error;
            _errorMessage = 'No speech detected. Please try again.';
          });
        } else if (_state == _ListeningState.listening &&
            _recognizedText.isNotEmpty) {
          // Listening stopped naturally (pauseFor expired) — process now
          _onFinalResult(_recognizedText, _confidence);
        }
      },
    );
  }

  void _onFinalResult(String text, double confidence) {
    if (!mounted) return;

    HapticFeedback.lightImpact();

    setState(() {
      _state = _ListeningState.processing;
      _processingStatus = 'Analyzing your command...';
      _fallbackReason = null;
      _showGeminiBadge = false;
    });

    // Small delay for UX polish, then parse with AI (primary) or regex (fallback)
    Future.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      final result = await _service.smartParse(
        text,
        confidence: confidence,
        onFallback: (reason) {
          if (mounted) {
            setState(() {
              _fallbackReason = reason;
            });
          }
        },
      );
      // ignore: avoid_print
      print('🎤 RAW TEXT: "$text"');
      // ignore: avoid_print
      print('🎤 PARSED: $result');
      if (!mounted) return;

      // Show badge only if AI actually parsed it
      if (result.parsedByAI) {
        setState(() {
          _showGeminiBadge = true;
          _processingStatus = 'Parsed successfully!';
        });
      }

      // Wait 2 seconds so user can see the result / errors before closing
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  void _onStopPressed() async {
    if (_service.isListening) {
      await _service.stopListening();
    }

    if (_recognizedText.isNotEmpty) {
      _onFinalResult(_recognizedText, _confidence);
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onRetryPressed() {
    _startListening();
  }

  void _onCancelPressed() async {
    if (_service.isListening) {
      await _service.cancelListening();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _stateTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle / instruction
              Text(
                _stateSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Microphone / status indicator
              _buildCenterWidget(theme, isDark),
              const SizedBox(height: 24),

              // Recognized text
              if (_recognizedText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"$_recognizedText"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              _buildActions(theme),
            ],
          ),
        ),
      ),
    );
  }

  String get _stateTitle {
    switch (_state) {
      case _ListeningState.initializing:
        return 'Preparing...';
      case _ListeningState.listening:
        return 'Listening';
      case _ListeningState.processing:
        return 'Processing...';
      case _ListeningState.error:
        return 'Oops!';
    }
  }

  String get _stateSubtitle {
    switch (_state) {
      case _ListeningState.initializing:
        return 'Setting up speech recognition';
      case _ListeningState.listening:
        return 'Say something like "tomorrow at 3 PM about exam"';
      case _ListeningState.processing:
        return _processingStatus;
      case _ListeningState.error:
        return _errorMessage ?? 'Something went wrong';
    }
  }

  Widget _buildCenterWidget(ThemeData theme, bool isDark) {
    final micColor = theme.colorScheme.primary;

    switch (_state) {
      case _ListeningState.initializing:
        return SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: micColor.withValues(alpha: 0.5),
          ),
        );

      case _ListeningState.listening:
        return GestureDetector(
          onTap: _onStopPressed,
          child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: micColor.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.mic, size: 44, color: micColor),
              )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.15, 1.15),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(1.0, 1.0),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
        );

      case _ListeningState.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(strokeWidth: 3, color: micColor),
            ),
            const SizedBox(height: 24),
            // Show badge only after Gemini confirms processing
            if (_showGeminiBadge)
              _ShimmerGeminiLabel(primaryColor: theme.colorScheme.primary)
            else if (_fallbackReason != null) ...[
              Text(
                'Using manual process...',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fallbackReason!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red.shade400,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );

      case _ListeningState.error:
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          ),
          child: Icon(Icons.mic_off, size: 40, color: theme.colorScheme.error),
        );
    }
  }

  Widget _buildActions(ThemeData theme) {
    switch (_state) {
      case _ListeningState.initializing:
      case _ListeningState.processing:
        return TextButton(
          onPressed: _onCancelPressed,
          child: const Text('Cancel'),
        );

      case _ListeningState.listening:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _onCancelPressed,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _onStopPressed,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Done'),
            ),
          ],
        );

      case _ListeningState.error:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: _onCancelPressed, child: const Text('Close')),
            FilledButton.icon(
              onPressed: _onRetryPressed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        );
    }
  }
}

enum _ListeningState { initializing, listening, processing, error }

/// "✨ Powered by Gemini" pill with running rainbow border colors.
class _ShimmerGeminiLabel extends StatefulWidget {
  final Color primaryColor;
  const _ShimmerGeminiLabel({required this.primaryColor});

  @override
  State<_ShimmerGeminiLabel> createState() => _ShimmerGeminiLabelState();
}

class _ShimmerGeminiLabelState extends State<_ShimmerGeminiLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = t * 2 * math.pi;
        final bx = math.cos(angle);
        final by = math.sin(angle);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: _colors,
              begin: Alignment(bx, by),
              end: Alignment(-bx, -by),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.5),
              color: surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'Powered by Gemini',
                  style: TextStyle(
                    fontSize: 13,
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
    );
  }
}
