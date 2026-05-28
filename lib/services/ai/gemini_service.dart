import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

const _geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

const _openRouterApiKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
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

  Future<String> generateAuthenticSummary({
    required String name,
    required String currentRole,
    required List<String> skills,
    required List<Map<String, dynamic>> experience,
    required List<Map<String, dynamic>> education,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> certifications,
    required List<Map<String, dynamic>> achievements,
    String? currentSummary,
  }) async {
    final expList = experience.map((e) {
      final role = e['role'] ?? '';
      final company = e['company'] ?? '';
      final duration = e['duration'] ?? '';
      final bullets = e['bullets'] is List ? (e['bullets'] as List).join('; ') : '';
      return '- $role at $company ($duration): $bullets';
    }).join('\n');

    final projList = projects.map((p) {
      final title = p['title'] ?? '';
      final tech = p['technologies'] is List ? (p['technologies'] as List).join(', ') : '';
      final bullets = p['bullets'] is List ? (p['bullets'] as List).join('; ') : '';
      return '- $title (Tech: $tech): $bullets';
    }).join('\n');

    final eduList = education.map((e) {
      final degree = e['degree'] ?? '';
      final inst = e['institution'] ?? '';
      final spec = e['specialisation'] ?? e['field'] ?? '';
      final years = '${e['startYear'] ?? ''} - ${e['endYear'] ?? ''}';
      final grade = e['cgpa'] ?? e['percentage'] ?? '';
      return '- $degree in $spec from $inst ($years), Grade: $grade';
    }).join('\n');

    final certsList = certifications.map((c) => '- ${c['title'] ?? ''} from ${c['issuer'] ?? ''} (${c['date'] ?? ''})').join('\n');
    final achsList = achievements.map((a) => '- ${a['title'] ?? ''}').join('\n');

    final prompt = '''
Write a highly professional, realistic, and authentic professional summary for a candidate's resume/profile.
The summary must be strictly between 100 and 150 words in length.

Candidate Background:
- Name: $name
- Headline / Target Role: $currentRole
- Existing Summary (if any): ${currentSummary ?? ''}

Key Skills:
${skills.join(', ')}

Work Experience:
$expList

Projects:
$projList

Education:
$eduList

Certifications:
$certsList

Achievements:
$achsList

Strict Rules for Generation:
1. **Length Constraints**: The generated summary MUST be strictly between 100 and 150 words. Do not make it shorter than 100 words or longer than 150 words.
2. **Authenticity & Tone**: Keep the professional summary authentic and human-sounding. Do NOT make it sound like a typical corporate AI brochure or generic marketing fluff.
3. **Forbid Clichés**: Avoid buzzword clichés like "seasoned," "dynamic," "visionary," "passionate," "detail-oriented," "results-driven," "highly motivated," "thought leader," or "expert."
4. **Strip Filler Adjectives**: Strip out generic filler adjectives in favor of varied, natural sentence structures.
5. **Rely on Hard Facts & Metrics**: Instead of inventing melodramatic fluff or generic job titles, rely strictly on hard facts, specific metrics, measurable achievements, and actual work philosophy from the provided user data (experience, education, and projects). Do not exaggerate or fabricate numbers or experiences.
6. **Varied, Natural Sentence Structure**: Use clean, straightforward, varied sentence structures. Avoid repetitive paragraph patterns.
7. **Implicit First-Person/Active Voice**: Write in the active professional voice (e.g., starting with the role name, like "Software engineer building..." or "Backend developer focusing on..."). Do not use third-person biography pronouns ("he", "she", "they").
8. **The "Read Out Loud" / Coffee Test**: Always apply the "read out loud" test to self-correct the draft. If the candidate would feel pretentious saying the summary directly to a recruiter over a cup of coffee, simplify the language until it sounds like a straightforward, confident professional describing their actual value.

Return ONLY valid JSON:
{
  "summary": "Your generated authentic professional summary here."
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
      if (parsed != null) return parsed;
      throw Exception('Failed to parse Gemini response as JSON');
    } catch (e) {
      // Log the primary failure and try OpenRouter fallback
      print('Gemini primary generation failed: $e. Trying OpenRouter fallback...');
      try {
        return await _generateWithOpenRouter(prompt);
      } catch (openRouterError) {
        // If fallback also fails, throw a combined error
        throw Exception('AI generation failed. Primary Gemini error: $e. Fallback OpenRouter error: $openRouterError');
      }
    }
  }

  Future<Map<String, dynamic>> _generateWithOpenRouter(String prompt) async {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_openRouterApiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://aicareer.os',
        'X-Title': 'AI Career OS',
      },
      body: jsonEncode({
        'model': 'anthropic/claude-3-haiku',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenRouter API error (status ${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['choices']?[0]?['message']?['content'] as String? ?? '{}';
    final parsed = safeParseAiJson(content);
    if (parsed == null) {
      throw Exception('Failed to parse OpenRouter response as JSON');
    }
    return parsed;
  }
}

final geminiServiceImplProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
