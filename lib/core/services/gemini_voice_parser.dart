import 'dart:convert';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/app_config.dart';
import '../../data/models/planner_enums.dart';
import 'voice_reminder_service.dart';

/// AI-powered voice command parser using Gemini API.
///
/// Used as the primary parser when online. Falls back to regex if this
/// service fails (network error, rate limit, malformed response, etc).
class GeminiVoiceParser {
  GeminiVoiceParser._();
  static final GeminiVoiceParser instance = GeminiVoiceParser._();

  GenerativeModel? _model;
  String? _lastError;

  /// The last error message from a failed parse attempt.
  String? get lastError => _lastError;

  bool get _hasApiKey =>
      AppConfig.geminiApiKey.isNotEmpty &&
      AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY';

  GenerativeModel _getModel() {
    return _model ??= GenerativeModel(
      model:
          'gemini-2.5-flash-lite', // 'gemini-3.1-pro-preview', 'gemini-3-flash-preview', 'gemini-2.5-flash-lite'
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );
  }

  /// Parse a voice command using Gemini AI.
  /// Returns a [VoiceReminderResult] or `null` on any failure.
  Future<VoiceReminderResult?> parse(
    String rawText, {
    double confidence = 0.0,
    int retryCount = 0,
  }) async {
    if (!_hasApiKey || rawText.trim().isEmpty) {
      // ignore: avoid_print
      print('[GeminiParser] ❌ No API key or empty text');
      _lastError = 'No API key configured';
      return null;
    }

    // Clear previous error
    _lastError = null;

    // Clean the input text
    final cleanText = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');

    // ignore: avoid_print
    print('[GeminiParser] 🎤 Processing: "$cleanText"');

    DateTime startTime = DateTime.now();
    int attempt = 0;

    while (attempt <= retryCount) {
      attempt++;
      try {
        final now = DateTime.now();
        final prompt = _buildPrompt(cleanText, now);

        // ignore: avoid_print
        print('[GeminiParser] 🚀 Attempt $attempt: Calling Gemini API...');

        // Add small delay between retries
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        final response = await _getModel()
            .generateContent([Content.text(prompt)])
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Gemini API timeout after 10 seconds');
              },
            );

        final text = response.text;

        // Calculate processing time
        final processingTime =
            DateTime.now().difference(startTime).inMilliseconds;

        // ignore: avoid_print
        print('[GeminiParser] 📥 Response received in ${processingTime}ms');

        if (text == null || text.isEmpty) {
          // ignore: avoid_print
          print('[GeminiParser] ⚠️ Empty response received');
          if (attempt <= retryCount) continue;
          return null;
        }

        // Try to clean the response if it contains markdown code blocks
        String cleanResponse = text;
        if (text.contains('```json')) {
          final RegExp jsonRegex = RegExp(r'```json\n(.*?)\n```', dotAll: true);
          final match = jsonRegex.firstMatch(text);
          if (match != null) {
            cleanResponse = match.group(1)!;
          }
        } else if (text.contains('```')) {
          final RegExp jsonRegex = RegExp(r'```\n(.*?)\n```', dotAll: true);
          final match = jsonRegex.firstMatch(text);
          if (match != null) {
            cleanResponse = match.group(1)!;
          }
        }

        // ignore: avoid_print
        print('[GeminiParser] 📊 Cleaned response: $cleanResponse');

        final result = _parseResponse(cleanResponse, cleanText, confidence);

        if (result != null) {
          // Validate the result has at least a title
          if (result.title == null || result.title!.isEmpty) {
            // ignore: avoid_print
            print(
              '[GeminiParser] ⚠️ Parsed result has no title, using fallback',
            );
            // Reconstruct with fallback title since fields are final
            final fallbackTitle = _extractFallbackTitle(cleanText);
            return VoiceReminderResult(
              rawText: result.rawText,
              title: fallbackTitle,
              description: result.description,
              dateTime: result.dateTime,
              reminderOffset: result.reminderOffset,
              priority: result.priority,
              category: result.category,
              confidence: result.confidence,
              intent: result.intent,
              parsedByAI: true,
              estimatedDuration: result.estimatedDuration,
              recurring: result.recurring,
            );
          }

          // ignore: avoid_print
          print('[GeminiParser] ✅ Successfully parsed: ${result.title}');
          return result;
        } else {
          // ignore: avoid_print
          print('[GeminiParser] ❌ Failed to parse JSON response');
          if (attempt <= retryCount) continue;
        }
      } on TimeoutException catch (e) {
        _lastError = 'Request timed out';
        // ignore: avoid_print
        print('[GeminiParser] ⏱️ Timeout error (attempt $attempt): $e');
        if (attempt <= retryCount) continue;
      } on FormatException catch (e) {
        _lastError = 'Invalid response format';
        // ignore: avoid_print
        print('[GeminiParser] 📄 Format error (attempt $attempt): $e');
        if (attempt <= retryCount) continue;
      } catch (e) {
        final errorStr = e.toString();
        // Detect rate limit errors specifically
        if (errorStr.contains('quota') ||
            errorStr.contains('rate') ||
            errorStr.contains('429')) {
          _lastError = 'API rate limit exceeded';
        } else {
          _lastError = 'AI service error';
        }
        // ignore: avoid_print
        print('[GeminiParser] ❌ Error (attempt $attempt): $e');
        if (attempt <= retryCount) continue;
      }
    }

    // Log total failure
    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    // ignore: avoid_print
    print('[GeminiParser] 💔 All attempts failed after ${totalTime}ms');

    return null;
  }

  /// Fallback method to extract a basic title when AI parsing fails
  String _extractFallbackTitle(String rawText) {
    // Simple fallback: take first 3-5 words as title
    final words = rawText.split(' ');

    if (words.isEmpty) return 'Reminder';

    // Remove common command words
    final commandWords = [
      'remind',
      'reminder',
      'set',
      'create',
      'add',
      'new',
      'schedule',
      'please',
    ];
    final filteredWords =
        words
            .where((word) => !commandWords.contains(word.toLowerCase()))
            .toList();

    if (filteredWords.isEmpty) return words.take(3).join(' ');

    // Take first 3-5 words as title (max 40 chars)
    String title = filteredWords.take(5).join(' ');
    if (title.length > 40) {
      title = title.substring(0, 40).trim();
      if (title.endsWith(',')) title = title.substring(0, title.length - 1);
    }

    return title;
  }

  String _buildPrompt(String rawText, DateTime now) {
    final weekday =
        [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][now.weekday - 1];

    final month =
        [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ][now.month - 1];

    return '''
You are a voice reminder parser for a planner app. Extract structured data from the user's voice command.

Current date/time: ${now.toIso8601String()} ($weekday, $month ${now.day}, ${now.year} at ${now.hour}:${now.minute.toString().padLeft(2, '0')})

Voice command: "$rawText"

Return a JSON object with these fields (use null for fields not mentioned):
{
  "title": "string - a short, clean reminder title",
  "description": "string or null - Retrive all the details and notes from the voice command after getting the title",
  "dateTime": "ISO 8601 string or null",
  "priority": "high, medium, low, or null",
  "category": "exam, deadline, reminder, document, other, or null",
  "reminderOffsetMinutes": "integer or null",
  "estimatedDuration": "integer or null - in minutes",
  "recurring": "string or null - one-time, daily, weekly, monthly, yearly",
  "intent": "set, change, remove, or openManual"
}

IMPORTANT PARSING RULES:

1. **TITLE EXTRACTION**:
   - Title = the core task/reminder subject ONLY (2-5 words maximum)
   - STRIP ALL time, date, priority, category keywords from title
   - STRIP ALL descriptions/explanations from title
   - Use Title Case (capitalize first letter of each word)
   
   Examples:
   ✓ "Call Mom" → title="Call Mom", description=null
   ✓ "Call Mom to wish happy birthday" → title="Call Mom", description="Wish happy birthday"
   ✓ "Math Practice on calculus and trigonometry" → title="Math Practice", description="Calculus and Trigonometry"
   ✓ "Meeting with HOD about project deadline" → title="Meeting With HOD", description="Project deadline"
   ✓ "Submit assignment for Database Management System" → title="Submit Assignment", description="Database Management System"
   ✓ "Buy groceries milk eggs bread" → title="Buy Groceries", description="Milk, eggs, bread"
   ✓ "Doctor appointment for annual checkup" → title="Doctor Appointment", description="Annual checkup"

2. **DATE & TIME HANDLING**:
   - For "in X minutes/hours": Compute absolute dateTime from current time
   - For "today at X": Set date to today
   - For "tomorrow at X": Set date to tomorrow
   - For "next Monday/Tuesday/etc.": Set to next occurrence of that day
   - For "on Feb 21" or "21st Feb": Set to that date in current/future year
   - For "at 9:23 AM" without date: Set to today if time > current time, else tomorrow
   - For "morning" (before 12 PM): Set to 9:00 AM
   - For "afternoon" (12 PM - 5 PM): Set to 2:00 PM
   - For "evening" (5 PM - 9 PM): Set to 6:00 PM
   - For "night" (after 9 PM): Set to 8:00 PM

3. **CATEGORY INFERENCE** (if not explicitly stated):
   - "exam", "test", "quiz", "study" → exam
   - "deadline", "submit", "due", "assignment", "project due" → deadline
   - "remind", "reminder", "remember", "don't forget" → reminder
   - "document", "doc", "paper", "form", "application" → document
   - Otherwise → other

4. **PRIORITY INFERENCE** (if not explicitly stated):
   - Keywords: "high priority", "urgent", "important", "asap", "critical" → high
   - Keywords: "medium priority", "normal" → medium
   - Keywords: "low priority", "whenever", "if you have time" → low
   - Otherwise → null (let app decide default)

5. **REMINDER OFFSET**:
   - "remind me X minutes/hours before" → Set reminderOffsetMinutes
   - "remind me at time" → Set reminderOffsetMinutes = 0 (same as due time)
   - "no reminder" → Set reminderOffsetMinutes = null
   
   Examples:
   - "remind before 5 minutes" → reminderOffsetMinutes = 5
   - "remind me 1 hour before" → reminderOffsetMinutes = 60
   - "remind same time" → reminderOffsetMinutes = 0

6. **ESTIMATED DURATION**:
   - Extract if user mentions duration: "takes 30 minutes", "for 2 hours", "lasts 1 hour"
   - Convert everything to minutes
   
   Examples:
   - "30 minutes" → 30
   - "1 hour" → 60
   - "1.5 hours" → 90
   - "2 hours 30 minutes" → 150

7. **RECURRING PATTERNS**:
   - "every day", "daily" → daily
   - "every week", "weekly" → weekly
   - "every month", "monthly" → monthly
   - "every year", "yearly", "annually" → yearly
   - "one-time", "once" → one-time
   - If not mentioned → "one-time"

8. **INTENT DETECTION**:
   - "remove/delete/cancel reminder" → intent="remove"
   - "change/update/modify to" → intent="change"
   - "show/open reminders" → intent="openManual"
   - Default is "set"

COMPLEX EXAMPLES:

Example 1: "Remind me to call Mom on Saturday at 9:23 AM with high priority, remind before 5 minutes, takes 15 minutes"
→ {
  "title": "Call Mom",
  "description": null,
  "dateTime": "2026-02-21T09:23:00", 
  "priority": "high",
  "category": "reminder",
  "reminderOffsetMinutes": 5,
  "estimatedDuration": 15,
  "recurring": "one-time",
  "intent": "set"
}

Example 2: "Set a deadline for submitting the Database project next Monday at 5 PM, it's urgent and takes about 2 hours"
→ {
  "title": "Submit Database Project",
  "description": null,
  "dateTime": "2026-02-23T17:00:00",
  "priority": "high",
  "category": "deadline",
  "reminderOffsetMinutes": null,
  "estimatedDuration": 120,
  "recurring": "one-time",
  "intent": "set"
}

Example 3: "Remind me to practice Math on calculus and trigonometry every week on Monday at 5 PM, low priority"
→ {
  "title": "Practice Math",
  "description": "Calculus and trigonometry",
  "dateTime": "2026-02-23T17:00:00",
  "priority": "low",
  "category": "exam",
  "reminderOffsetMinutes": null,
  "estimatedDuration": null,
  "recurring": "weekly",
  "intent": "set"
}

Example 4: "Remove the reminder for Doctor appointment"
→ {
  "title": "Doctor Appointment",
  "description": null,
  "dateTime": null,
  "priority": null,
  "category": null,
  "reminderOffsetMinutes": null,
  "estimatedDuration": null,
  "recurring": null,
  "intent": "remove"
}

CRITICAL: 
- Return ONLY valid JSON, no other text
- Use null for any field that cannot be determined
- Keep titles short and clean (2-5 words max)
- Put all extra details in description
''';
  }

  VoiceReminderResult? _parseResponse(
    String jsonStr,
    String rawText,
    double confidence,
  ) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      // Parse dateTime
      DateTime? dateTime;
      if (data['dateTime'] != null) {
        dateTime = DateTime.tryParse(data['dateTime']);
      }

      // Parse priority
      PlannerPriority? priority;
      if (data['priority'] != null) {
        final p = (data['priority'] as String).toLowerCase();
        priority = switch (p) {
          'high' => PlannerPriority.high,
          'medium' => PlannerPriority.medium,
          'low' => PlannerPriority.low,
          _ => null,
        };
      }

      // Parse category
      PlannerCategory? category;
      if (data['category'] != null) {
        final c = (data['category'] as String).toLowerCase();
        category = switch (c) {
          'exam' => PlannerCategory.exam,
          'deadline' => PlannerCategory.deadline,
          'reminder' => PlannerCategory.reminder,
          'document' => PlannerCategory.document,
          'other' => PlannerCategory.other,
          _ => null,
        };
      }

      // Parse reminder offset
      Duration? reminderOffset;
      if (data['reminderOffsetMinutes'] != null) {
        final mins = data['reminderOffsetMinutes'];
        if (mins is int && mins >= 0) {
          reminderOffset = Duration(minutes: mins);
        } else if (mins is double && mins >= 0) {
          reminderOffset = Duration(minutes: mins.toInt());
        }
      }

      // Parse estimated duration
      Duration? estimatedDuration;
      if (data['estimatedDuration'] != null) {
        final mins = data['estimatedDuration'];
        if (mins is int && mins > 0) {
          estimatedDuration = Duration(minutes: mins);
        } else if (mins is double && mins > 0) {
          estimatedDuration = Duration(minutes: mins.toInt());
        }
      }

      // Parse recurring
      String? recurring = data['recurring'] as String?;
      if (recurring != null && recurring.isEmpty) recurring = null;

      // Parse intent
      VoiceCommandIntent intent = VoiceCommandIntent.set;
      if (data['intent'] != null) {
        final i = (data['intent'] as String).toLowerCase();
        intent = switch (i) {
          'remove' => VoiceCommandIntent.remove,
          'change' => VoiceCommandIntent.change,
          'openmanual' => VoiceCommandIntent.openManual,
          _ => VoiceCommandIntent.set,
        };
      }

      // Parse title and description
      String? title = data['title'] as String?;
      if (title != null && title.isEmpty) title = null;
      String? description = data['description'] as String?;
      if (description != null && description.isEmpty) description = null;

      return VoiceReminderResult(
        rawText: rawText,
        title: title,
        description: description,
        dateTime: dateTime,
        reminderOffset: reminderOffset,
        priority: priority,
        category: category,
        confidence: confidence,
        intent: intent,
        parsedByAI: true,
        estimatedDuration: estimatedDuration,
        recurring: recurring,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[GeminiParser] ❌ Parse error: $e');
      return null;
    }
  }
}
