import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/planner_enums.dart';
import 'gemini_voice_parser.dart';

/// The detected intent from a voice command.
enum VoiceCommandIntent { set, remove, change, openManual }

/// Result returned after voice recognition + NLP parsing.
class VoiceReminderResult {
  final String rawText;
  final String? title;
  final String? description;
  final DateTime? dateTime;
  final Duration? reminderOffset;
  final PlannerPriority? priority;
  final PlannerCategory? category;
  final double confidence;
  final VoiceCommandIntent intent;
  final bool parsedByAI;
  final Duration? estimatedDuration;
  final String? recurring;

  const VoiceReminderResult({
    required this.rawText,
    this.title,
    this.description,
    this.dateTime,
    this.reminderOffset,
    this.priority,
    this.category,
    this.confidence = 0.0,
    this.intent = VoiceCommandIntent.set,
    this.parsedByAI = false,
    this.estimatedDuration,
    this.recurring,
  });

  /// Whether we successfully extracted a date/time.
  bool get hasDateTime => dateTime != null;

  /// Whether we extracted a title.
  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  @override
  String toString() =>
      'VoiceReminderResult(raw: "$rawText", title: "$title", desc: "$description", '
      'dateTime: $dateTime, reminderOffset: $reminderOffset, priority: ${priority?.name}, '
      'category: ${category?.name}, confidence: $confidence, intent: ${intent.name}, '
      'parsedByAI: $parsedByAI, estimatedDuration: $estimatedDuration, '
      'recurring: $recurring)';
}

/// Internal parse result used by date/time parsers.
class _ParseResult {
  final DateTime dateTime;
  final String remaining;
  const _ParseResult({required this.dateTime, required this.remaining});
}

/// Parser function signature.
typedef _DateTimeParser = _ParseResult? Function(String text, DateTime now);

/// Service for voice-based reminder creation.
///
/// Wraps [stt.SpeechToText] for recognition and provides
/// a regex-based NLP parser to extract date/time + title
/// from natural language.
class VoiceReminderService {
  static final VoiceReminderService _instance =
      VoiceReminderService._internal();
  factory VoiceReminderService() => _instance;
  VoiceReminderService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  /// Whether the device supports speech recognition.
  bool get isAvailable => _initialized;

  /// Initialize the speech engine. Returns `true` if available.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceReminder] Speech error: ${error.errorMsg}');
        },
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('[VoiceReminder] Init error: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Start listening. [onResult] fires on each partial/final result.
  /// [onDone] fires when listening stops (timeout or manual).
  Future<void> startListening({
    required void Function(String text, bool isFinal, double confidence)
    onResult,
    VoidCallback? onDone,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        onDone?.call();
        return;
      }
    }

    // Wire onDone to the speech status listener so it fires when
    // listening actually stops (pauseFor timeout or manual stop),
    // NOT on each finalResult segment.
    _speech.statusListener = (status) {
      // ignore: avoid_print
      print('[VoiceReminder] Speech status: $status');
      if (status == 'notListening' || status == 'done') {
        onDone?.call();
      }
    };

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult, result.confidence);
      },
      listenFor: listenFor,
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// Stop listening manually.
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Cancel listening without triggering final result.
  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  /// Whether the engine is currently listening.
  bool get isListening => _speech.isListening;

  // ─────────────────────────────────────────────────────────
  //  Smart Parse: Gemini AI (primary) → Regex (fallback)
  // ─────────────────────────────────────────────────────────

  /// Parse using Gemini AI when online, regex when offline/error.
  Future<VoiceReminderResult> smartParse(
    String text, {
    double confidence = 0.0,
    void Function(String? reason)? onFallback,
  }) async {
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any(
      (r) => r != ConnectivityResult.none,
    );
    // ignore: avoid_print
    print(
      '[VoiceReminder] Connectivity: $connectivityResult, online=$isOnline',
    );

    if (isOnline) {
      final aiResult = await GeminiVoiceParser.instance.parse(
        text,
        confidence: confidence,
      );
      if (aiResult != null) {
        // ignore: avoid_print
        print('[VoiceReminder] 🤖 AI parsed: $aiResult');
        return aiResult;
      }
      // ignore: avoid_print
      print('[VoiceReminder] 🤖 AI failed, falling back to regex');
      final lastError = GeminiVoiceParser.instance.lastError;
      onFallback?.call(lastError);
    } else {
      // ignore: avoid_print
      print('[VoiceReminder] 📴 Offline, using regex parser');
      onFallback?.call('Offline - no internet connection');
    }

    // Fallback to regex parser
    return parse(text, confidence: confidence);
  }

  // ─────────────────────────────────────────────────────────
  //  NLP: Parse spoken text into VoiceReminderResult (Regex)
  // ─────────────────────────────────────────────────────────

  /// Parse a spoken sentence into a [VoiceReminderResult].
  VoiceReminderResult parse(String text, {double confidence = 0.0}) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return VoiceReminderResult(
        rawText: text,
        confidence: confidence,
        intent: VoiceCommandIntent.openManual,
      );
    }

    VoiceCommandIntent intent = VoiceCommandIntent.set;
    final lowerCleaned = cleaned.toLowerCase();

    if (lowerCleaned.startsWith('remove') ||
        lowerCleaned.startsWith('delete') ||
        lowerCleaned.startsWith('cancel') ||
        lowerCleaned.startsWith('clear')) {
      intent = VoiceCommandIntent.remove;
    } else if (lowerCleaned.startsWith('change') ||
        lowerCleaned.startsWith('update') ||
        lowerCleaned.startsWith('edit') ||
        lowerCleaned.startsWith('modify')) {
      intent = VoiceCommandIntent.change;
    }

    final now = DateTime.now();
    DateTime? parsedDateTime;
    Duration? reminderOffset;
    String remaining = cleaned;

    // Strip common prefixes
    remaining = _stripPrefixes(remaining);

    // ── Extract priority (with fuzzy STT matching) ──
    PlannerPriority? parsedPriority;
    final priorityMatch = RegExp(
      r'\b(high|hi|hai|hay|medium|med|mid|low|lo)\s+priority\b|\bpriority\s+(high|hi|hai|hay|medium|med|mid|low|lo)\b',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (priorityMatch != null) {
      final pWord =
          (priorityMatch.group(1) ?? priorityMatch.group(2))!.toLowerCase();
      parsedPriority = _fuzzyPriority(pWord);
      remaining = remaining.replaceFirst(priorityMatch.group(0)!, '').trim();
    }

    // ── Extract category (with fuzzy STT matching) ──
    PlannerCategory? parsedCategory;
    final categoryMatch = RegExp(
      r'\bcategory\s+(?:is\s+)?(exam|exams|deadline|deadlines|reminder|reminders|document|documents|other|others)\b'
      r'|\b(exam|exams|deadline|deadlines|document|documents)\s+category\b'
      r'|\b(exam|exams|deadline|deadlines|document|documents)\b',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (categoryMatch != null) {
      final cWord =
          (categoryMatch.group(1) ??
                  categoryMatch.group(2) ??
                  categoryMatch.group(3))!
              .toLowerCase();
      parsedCategory = _fuzzyCategory(cWord);
      remaining = remaining.replaceFirst(categoryMatch.group(0)!, '').trim();
    }

    // ── Check for "before N minutes" → reminderOffset ──
    final beforeMatch = RegExp(
      r'\bbefore\s+' +
          _numRegex +
          r'\s+(minutes|minute|mins|min|hours|hour|hrs|hr)\b',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (beforeMatch != null) {
      final amount = _parseNumberWord(beforeMatch.group(1)!) ?? 0;
      final unit = beforeMatch.group(2)!.toLowerCase();
      if (unit.startsWith('hour') || unit.startsWith('hr')) {
        reminderOffset = Duration(hours: amount);
      } else {
        reminderOffset = Duration(minutes: amount);
      }
      remaining = remaining.replaceFirst(beforeMatch.group(0)!, '').trim();
    }

    // Try each parser in priority order
    final parsers = <_DateTimeParser>[
      _parseRelativeMinutesHours,
      _parseInNMinutes,
      _parseTomorrowAt,
      _parseTodayAt,
      _parseNextWeekday,
      _parseWeekdayOnly,
      _parseTomorrowOnly,
      _parseDateAt,
      _parseDateMonthAt,
      _parseTimeOnly,
    ];

    for (final parser in parsers) {
      final result = parser(remaining, now);
      if (result != null) {
        parsedDateTime = result.dateTime;
        remaining = result.remaining.trim();
        break;
      }
    }

    // Try to extract description
    String? description;
    final descMatch = RegExp(
      r'\b(with description|and description|description is|description|and note that|with notes|with note|notes)\s+(.*)',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (descMatch != null) {
      description = descMatch.group(2)?.trim();
      if (description?.isEmpty ?? false) description = null;
      remaining = remaining.substring(0, descMatch.start).trim();
    }

    // Clean up remaining text as title
    String? title = _cleanTitle(remaining);
    if (title != null && title.isEmpty) title = null;

    // Consider it valid if we got dateTime, reminderOffset, priority, or category
    if (parsedDateTime == null &&
        reminderOffset == null &&
        parsedPriority == null &&
        parsedCategory == null &&
        intent == VoiceCommandIntent.set) {
      intent = VoiceCommandIntent.openManual;
    }

    return VoiceReminderResult(
      rawText: text,
      title: title,
      description: description,
      dateTime: parsedDateTime,
      reminderOffset: reminderOffset,
      priority: parsedPriority,
      category: parsedCategory,
      confidence: confidence,
      intent: intent,
    );
  }

  // ──────────── Prefix stripping ────────────

  static final _prefixPatterns = [
    RegExp(r'^remind\s+me\s+(about\s+)?', caseSensitive: false),
    RegExp(r'^remind\s+(about\s+)?', caseSensitive: false),
    RegExp(r'^set\s+(a\s+)?reminder\s+(for\s+)?', caseSensitive: false),
    RegExp(r'^create\s+(a\s+)?reminder\s+(for\s+)?', caseSensitive: false),
    RegExp(
      r'^change\s+(the\s+)?(reminder\s*)?(time\s*)?(to\s+)?',
      caseSensitive: false,
    ),
    RegExp(
      r'^update\s+(the\s+)?(reminder\s*)?(time\s*)?(to\s+)?',
      caseSensitive: false,
    ),
    RegExp(
      r'^edit\s+(the\s+)?(reminder\s*)?(time\s*)?(to\s+)?',
      caseSensitive: false,
    ),
    RegExp(
      r'^modify\s+(the\s+)?(reminder\s*)?(time\s*)?(to\s+)?',
      caseSensitive: false,
    ),
  ];

  String _stripPrefixes(String text) {
    var result = text;
    for (final pattern in _prefixPatterns) {
      result = result.replaceFirst(pattern, '');
    }
    return result.trim();
  }

  // ──────────── Fuzzy matching helpers ────────────

  static PlannerPriority _fuzzyPriority(String word) {
    const map = {
      'high': PlannerPriority.high,
      'hi': PlannerPriority.high,
      'hai': PlannerPriority.high,
      'hay': PlannerPriority.high,
      'medium': PlannerPriority.medium,
      'med': PlannerPriority.medium,
      'mid': PlannerPriority.medium,
      'low': PlannerPriority.low,
      'lo': PlannerPriority.low,
    };
    return map[word] ?? PlannerPriority.medium;
  }

  static PlannerCategory _fuzzyCategory(String word) {
    const map = {
      'exam': PlannerCategory.exam,
      'exams': PlannerCategory.exam,
      'deadline': PlannerCategory.deadline,
      'deadlines': PlannerCategory.deadline,
      'reminder': PlannerCategory.reminder,
      'reminders': PlannerCategory.reminder,
      'document': PlannerCategory.document,
      'documents': PlannerCategory.document,
      'other': PlannerCategory.other,
      'others': PlannerCategory.other,
    };
    return map[word] ?? PlannerCategory.other;
  }

  // ──────────── Title cleanup ────────────

  String? _cleanTitle(String text) {
    var result = text;
    // Strip leading conjunctions / prepositions
    result = result.replaceFirst(
      RegExp(r'^(about|for|to|that|regarding)\s+', caseSensitive: false),
      '',
    );
    // Capitalize first letter
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result.isEmpty ? null : result;
  }

  // ──────────── Individual parsers ────────────

  static const _numRegex =
      r'(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty)';

  int? _parseNumberWord(String text) {
    var amt = int.tryParse(text);
    if (amt != null) return amt;

    const words = {
      'a': 1,
      'an': 1,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
      'thirteen': 13,
      'fourteen': 14,
      'fifteen': 15,
      'sixteen': 16,
      'seventeen': 17,
      'eighteen': 18,
      'nineteen': 19,
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
      'fifty': 50,
      'sixty': 60,
    };
    return words[text.toLowerCase()];
  }

  /// "in 30 minutes", "after 2 hours", "within 15 minutes"
  /// NOTE: "before" is handled separately as a reminder offset, not here.
  static final _relativePattern = RegExp(
    r'(in|after|within)\s+' +
        _numRegex +
        r'\s+(minutes|minute|mins|min|hours|hour|hrs|hr)\b',
    caseSensitive: false,
  );

  _ParseResult? _parseRelativeMinutesHours(String text, DateTime now) {
    final match = _relativePattern.firstMatch(text);
    if (match == null) return null;

    final amount = _parseNumberWord(match.group(2)!) ?? 0;
    final unit = match.group(3)!.toLowerCase();

    Duration offset;
    if (unit.startsWith('hour') || unit.startsWith('hr')) {
      offset = Duration(hours: amount);
    } else {
      offset = Duration(minutes: amount);
    }

    final dt = now.add(offset);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "in N minutes" variant without prefix (just "N minutes" or "two hours")
  static final _nMinutesPattern = RegExp(
    r'^' + _numRegex + r'\s+(minutes|minute|mins|min|hours|hour|hrs|hr)\b',
    caseSensitive: false,
  );

  _ParseResult? _parseInNMinutes(String text, DateTime now) {
    final match = _nMinutesPattern.firstMatch(text);
    if (match == null) return null;

    final amount = _parseNumberWord(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();

    Duration offset;
    if (unit.startsWith('hour') || unit.startsWith('hr')) {
      offset = Duration(hours: amount);
    } else {
      offset = Duration(minutes: amount);
    }

    final dt = now.add(offset);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "tomorrow at 3 PM", "tomorrow at 15:00", "tomorrow 3 PM"
  static final _tomorrowPattern = RegExp(
    r'tomorrow\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
    caseSensitive: false,
  );

  _ParseResult? _parseTomorrowAt(String text, DateTime now) {
    final match = _tomorrowPattern.firstMatch(text);
    if (match == null) return null;

    final hour = _parseHour(match.group(1)!, match.group(3));
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;

    final tomorrow = now.add(const Duration(days: 1));
    final dt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      hour,
      minute,
    );
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "today at 3 PM", "today at 15:00"
  static final _todayPattern = RegExp(
    r'today\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
    caseSensitive: false,
  );

  _ParseResult? _parseTodayAt(String text, DateTime now) {
    final match = _todayPattern.firstMatch(text);
    if (match == null) return null;

    final hour = _parseHour(match.group(1)!, match.group(3));
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;

    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "Monday at 5 PM", "Monday 17 hours", "at 5 PM Monday", "5 PM on Monday"
  static const _dayPattern =
      r'(?:next\s+|on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)';
  static const _timePattern =
      r'(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM|hours|hour|hrs|hr)?';

  static final _dayThenTimePattern = RegExp(
    '\\b$_dayPattern\\s+$_timePattern\\b',
    caseSensitive: false,
  );

  static final _timeThenDayPattern = RegExp(
    '\\b$_timePattern\\s+$_dayPattern\\b',
    caseSensitive: false,
  );

  _ParseResult? _parseNextWeekday(String text, DateTime now) {
    Match? match = _dayThenTimePattern.firstMatch(text);
    String dayName;
    String hourStr;
    String? minStr;
    String? ampmStr;

    if (match != null) {
      dayName = match.group(1)!;
      hourStr = match.group(2)!;
      minStr = match.group(3);
      ampmStr = match.group(4);
    } else {
      match = _timeThenDayPattern.firstMatch(text);
      if (match == null) return null;
      hourStr = match.group(1)!;
      minStr = match.group(2);
      ampmStr = match.group(3);
      dayName = match.group(4)!;
    }

    final dayNameLower = dayName.toLowerCase();
    final targetWeekday = _weekdayFromName(dayNameLower);
    final hour = _parseHour(hourStr, ampmStr);
    final minute = int.tryParse(minStr ?? '0') ?? 0;

    var daysAhead = targetWeekday - now.weekday;
    if (daysAhead <= 0) daysAhead += 7;

    final target = now.add(Duration(days: daysAhead));
    final dt = DateTime(target.year, target.month, target.day, hour, minute);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "Tuesday", "next Tuesday", "on Monday" (no time — keeps current time)
  static final _weekdayOnlyPattern = RegExp(
    r'(?:next\s+|on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );

  _ParseResult? _parseWeekdayOnly(String text, DateTime now) {
    final match = _weekdayOnlyPattern.firstMatch(text);
    if (match == null) return null;

    final dayName = match.group(1)!.toLowerCase();
    final targetWeekday = _weekdayFromName(dayName);

    var daysAhead = targetWeekday - now.weekday;
    if (daysAhead <= 0) daysAhead += 7;

    final target = now.add(Duration(days: daysAhead));
    // Keep the same time as currently set
    final dt = DateTime(
      target.year,
      target.month,
      target.day,
      now.hour,
      now.minute,
    );
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "tomorrow" (no time — keeps current time)
  static final _tomorrowOnlyPattern = RegExp(
    r'\btomorrow\b',
    caseSensitive: false,
  );

  _ParseResult? _parseTomorrowOnly(String text, DateTime now) {
    final match = _tomorrowOnlyPattern.firstMatch(text);
    if (match == null) return null;

    final tomorrow = now.add(const Duration(days: 1));
    final dt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      now.hour,
      now.minute,
    );
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "25th February at 5 PM", "3rd March at 10 AM", "March 25 at 5 PM"
  static final _dateAtPattern = RegExp(
    r'(\d{1,2})\s*(?:st|nd|rd|th)?\s+'
    r'(january|february|march|april|may|june|july|august|september|october|november|december)'
    r'\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
    caseSensitive: false,
  );

  _ParseResult? _parseDateAt(String text, DateTime now) {
    final match = _dateAtPattern.firstMatch(text);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!) ?? 1;
    final month = _monthFromName(match.group(2)!);
    final hour = _parseHour(match.group(3)!, match.group(5));
    final minute = int.tryParse(match.group(4) ?? '0') ?? 0;

    var year = now.year;
    final candidate = DateTime(year, month, day, hour, minute);
    if (candidate.isBefore(now)) year++;

    final dt = DateTime(year, month, day, hour, minute);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "March 5th at 10 AM" (month first)
  static final _dateMonthFirstPattern = RegExp(
    r'(january|february|march|april|may|june|july|august|september|october|november|december)'
    r'\s+(\d{1,2})\s*(?:st|nd|rd|th)?\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
    caseSensitive: false,
  );

  _ParseResult? _parseDateMonthAt(String text, DateTime now) {
    final match = _dateMonthFirstPattern.firstMatch(text);
    if (match == null) return null;

    final month = _monthFromName(match.group(1)!);
    final day = int.tryParse(match.group(2)!) ?? 1;
    final hour = _parseHour(match.group(3)!, match.group(5));
    final minute = int.tryParse(match.group(4) ?? '0') ?? 0;

    var year = now.year;
    final candidate = DateTime(year, month, day, hour, minute);
    if (candidate.isBefore(now)) year++;

    final dt = DateTime(year, month, day, hour, minute);
    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  /// "at 3 PM", "3 PM" (today, or tomorrow if already past)
  static final _timeOnlyPattern = RegExp(
    r'(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)',
    caseSensitive: false,
  );

  _ParseResult? _parseTimeOnly(String text, DateTime now) {
    final match = _timeOnlyPattern.firstMatch(text);
    if (match == null) return null;

    final hour = _parseHour(match.group(1)!, match.group(3));
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;

    var dt = DateTime(now.year, now.month, now.day, hour, minute);
    if (dt.isBefore(now)) {
      dt = dt.add(const Duration(days: 1));
    }

    final remaining = text.replaceFirst(match.group(0)!, '').trim();
    return _ParseResult(dateTime: dt, remaining: remaining);
  }

  // ──────────── Helpers ────────────

  int _parseHour(String hourStr, String? amPm) {
    var hour = int.tryParse(hourStr) ?? 0;
    if (amPm != null) {
      final lowerAmPm = amPm.toLowerCase();
      if (lowerAmPm == 'pm' && hour < 12) hour += 12;
      if (lowerAmPm == 'am' && hour == 12) hour = 0;
    }
    return hour.clamp(0, 23);
  }

  int _weekdayFromName(String name) {
    const days = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    return days[name.toLowerCase()] ?? 1;
  }

  int _monthFromName(String name) {
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return months[name.toLowerCase()] ?? 1;
  }
}
