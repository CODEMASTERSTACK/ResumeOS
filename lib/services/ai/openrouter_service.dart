import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

const _openRouterApiKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue: '',
);

/// OpenRouter fallback AI service (same interface as Gemini)
class OpenRouterService implements AIService {
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'anthropic/claude-3-haiku'; // fast + cheap fallback

  final http.Client _client;

  OpenRouterService([http.Client? client]) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> analyzeJobDescription(
      String jobDescription) async {
    const systemPrompt =
        'You are an expert technical recruiter. Always respond with valid JSON only.';
    final userPrompt = '''
Analyze this job description and return JSON with:
{"role":"","experienceLevel":"junior|mid|senior","requiredSkills":[],"preferredSkills":[],"keywords":[],"domainKeywords":[]}

Job Description: $jobDescription''';

    return _call(systemPrompt, userPrompt);
  }

  @override
  Future<ProjectRewriteResult> rewriteProjectBullets({
    required String projectTitle,
    required String projectDescription,
    required List<String> technologies,
    required String targetRole,
    required List<String> keywords,
    List<String> linkedSkills = const [],
  }) async {
    const systemPrompt =
        'You are an expert resume writer. Return valid JSON only.';
    final userPrompt =
        'Rewrite this project as 3 resume bullets for a $targetRole role.\n'
        'Project: $projectTitle — $projectDescription\n'
        'Tech: ${technologies.join(", ")}\n'
        'Linked Skills: ${linkedSkills.join(", ")}\n'
        'Keywords: ${keywords.take(5).join(", ")}\n'
        'Rules: In addition to bullets, select the 3-4 most relevant linked skills (from list above, if any) or project technologies for a $targetRole role.\n'
        'Return: {"bullets": ["...", "...", "..."], "selectedSkills": ["..."]}';

    final result = await _call(systemPrompt, userPrompt);
    return ProjectRewriteResult.fromJson(result);
  }

  @override
  Future<String> generateProfessionalSummary({
    required String candidateBackground,
    required String targetRole,
    required List<String> keywords,
    required List<String> topSkills,
  }) async {
    const systemPrompt =
        'You are an expert resume writer. Return valid JSON only.';
    final userPrompt =
        'Write a 2-3 sentence professional summary for a $targetRole position.\n'
        'Background: $candidateBackground\n'
        'Skills: ${topSkills.take(5).join(", ")}\n'
        'Return: {"summary": "..."}';

    final result = await _call(systemPrompt, userPrompt);
    return result['summary'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _call(
      String systemPrompt, String userPrompt) async {
    try {
      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $_openRouterApiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://aicareer.os',
          'X-Title': 'AI Career OS',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenRouter error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          json['choices']?[0]?['message']?['content'] as String? ?? '{}';
      return safeParseAiJson(content) ?? {};
    } catch (e) {
      throw Exception('OpenRouter fallback failed: $e');
    }
  }
}

final openRouterServiceProvider = Provider<OpenRouterService>((ref) {
  return OpenRouterService();
});

/// Resilient AI service — tries Gemini, falls back to OpenRouter
class ResilientAIService implements AIService {
  final AIService _primary;
  final AIService _fallback;

  const ResilientAIService(this._primary, this._fallback);

  @override
  Future<Map<String, dynamic>> analyzeJobDescription(String jd) =>
      _withFallback(() => _primary.analyzeJobDescription(jd),
          () => _fallback.analyzeJobDescription(jd));

  @override
  Future<ProjectRewriteResult> rewriteProjectBullets({
    required String projectTitle,
    required String projectDescription,
    required List<String> technologies,
    required String targetRole,
    required List<String> keywords,
    List<String> linkedSkills = const [],
  }) =>
      _withFallback(
        () => _primary.rewriteProjectBullets(
          projectTitle: projectTitle,
          projectDescription: projectDescription,
          technologies: technologies,
          targetRole: targetRole,
          keywords: keywords,
          linkedSkills: linkedSkills,
        ),
        () => _fallback.rewriteProjectBullets(
          projectTitle: projectTitle,
          projectDescription: projectDescription,
          technologies: technologies,
          targetRole: targetRole,
          keywords: keywords,
          linkedSkills: linkedSkills,
        ),
      );

  @override
  Future<String> generateProfessionalSummary({
    required String candidateBackground,
    required String targetRole,
    required List<String> keywords,
    required List<String> topSkills,
  }) =>
      _withFallback(
        () => _primary.generateProfessionalSummary(
          candidateBackground: candidateBackground,
          targetRole: targetRole,
          keywords: keywords,
          topSkills: topSkills,
        ),
        () => _fallback.generateProfessionalSummary(
          candidateBackground: candidateBackground,
          targetRole: targetRole,
          keywords: keywords,
          topSkills: topSkills,
        ),
      );

  Future<T> _withFallback<T>(
    Future<T> Function() primary,
    Future<T> Function() fallback,
  ) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await primary();
      } catch (_) {
        if (attempt == 2) {
          // Final attempt: use fallback
          return fallback();
        }
        // Exponential backoff: 500ms, 1000ms
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw Exception('All AI attempts failed');
  }
}
