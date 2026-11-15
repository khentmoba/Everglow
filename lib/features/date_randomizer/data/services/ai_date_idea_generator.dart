import 'package:flutter/foundation.dart';
import '../../../ai/data/services/ai_service.dart';
import '../models/date_idea.dart';

class AIDateIdeaGenerator {
  final AIService _aiService;

  AIDateIdeaGenerator(this._aiService);

  Future<DateIdea?> generatePersonalizedIdea({
    String? mood,
    String? timeOfDay,
    String? interests,
  }) async {
    try {
      final prompt = [
        'Generate ONE unique, romantic date idea title (short, 3-7 words). Be creative and personal.',
        if (mood != null && mood.isNotEmpty) 'Current mood: $mood',
        if (timeOfDay != null && timeOfDay.isNotEmpty) 'When: $timeOfDay',
        if (interests != null && interests.isNotEmpty) 'They enjoy: $interests',
        '',
        'Respond with ONLY the title — no quotes, no explanation, no extra text.',
      ].join('\n');

      final result = await _aiService.quickAsk(
        message: prompt,
        systemPrompt:
            'You are a creative date planner. Generate unique, romantic date idea titles. Respond with ONLY the title text — no quotes, no markdown, no other text.',
      );

      final title = result.trim().replaceAll('"', '').replaceAll("'", '');
      if (title.isEmpty) return null;

      return DateIdea(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AI date idea failed: $e');
      return null;
    }
  }
}
