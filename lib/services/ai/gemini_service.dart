import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_service.dart';

const _geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

/// Gemini Flash primary AI service
class GeminiService implements AIService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> analyzeJobDescription(
      String jobDescription) async {
    final prompt = '''
Analyze the following job description and extract structured information.
Return ONLY valid JSON matching this exact schema:
{
  "role": "string (job title)",
  "experienceLevel": "junior|mid|senior",
  "requiredSkills": ["skill1", "skill2"],
  "preferredSkills": ["skill1"],
  "keywords": ["keyword1", "keyword2"],
  "domainKeywords": ["domain1"]
}

Rules:
- keywords should be technical terms, tools, frameworks found in the JD
- domainKeywords should be business/domain terms (e.g., "fintech", "e-commerce")  
- Do NOT add skills not mentioned in the JD
- requiredSkills = explicitly required, preferredSkills = nice-to-have

Job Description:
$jobDescription
''';

    return _generate(prompt);
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
    final skillsPrompt = linkedSkills.isNotEmpty
        ? 'Linked skills to naturally incorporate and highlight: ${linkedSkills.join(', ')}\n'
        : '';
    final prompt = '''
Rewrite the following project description as 3-4 ATS-optimized resume bullet points.

Target role: $targetRole
Project: $projectTitle
Description: $projectDescription
Technologies: ${technologies.join(', ')}
$skillsPrompt
Keywords to incorporate naturally: ${keywords.take(8).join(', ')}

Rules:
- Start each bullet with a strong action verb (Built, Developed, Engineered, Designed, Optimized, etc.)
- Be specific with numbers/metrics where possible (use realistic estimates if not provided)
- Keep each bullet to 1-2 lines maximum
- Sound human and professional, not robotic
- Never invent technologies or experiences not present in the description
- ATS-friendly: no symbols, special characters, or graphics
- Select the 3-4 most relevant linked skills (from the linked list above, if any) or project technologies for a $targetRole role.

Return ONLY valid JSON:
{
  "bullets": ["bullet 1", "bullet 2", "bullet 3"],
  "selectedSkills": ["skill 1", "skill 2", "skill 3"]
}
''';

    final result = await _generate(prompt);
    return ProjectRewriteResult.fromJson(result);
  }

  @override
  Future<String> generateProfessionalSummary({
    required String candidateBackground,
    required String targetRole,
    required List<String> keywords,
    required List<String> topSkills,
  }) async {
    final prompt = '''
Write a 2-3 sentence professional summary for a resume.

Target role: $targetRole
Candidate background: $candidateBackground
Key skills: ${topSkills.take(6).join(', ')}
Keywords to incorporate: ${keywords.take(6).join(', ')}

Rules:
- Write in third person (no "I" or "me")
- Sound confident but not arrogant
- Be specific and technical where appropriate
- ATS-optimized: include role title and 2-3 key skills naturally
- No clichés ("passionate", "team player", "go-getter")
- 40-60 words maximum

Return ONLY valid JSON:
{
  "summary": "Your generated summary here."
}
''';

    final result = await _generate(prompt);
    return result['summary'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _generate(String prompt) async {
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '{}';
      final parsed = safeParseAiJson(raw);
      return parsed ?? {};
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    }
  }
}

final geminiServiceImplProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
