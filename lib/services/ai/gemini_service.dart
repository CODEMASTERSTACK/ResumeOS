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
2. **Authenticity & Tone**: It must sound authentic, straightforward, human, and professional. It must NOT sound like a typical AI-generated marketing brochure or generic corporate copy.
3. **Forbid Clichés & Buzzwords**: Do NOT use corporate clichés like "seasoned," "dynamic," "visionary," "passionate," "detail-oriented," "results-driven," "proven track record," "highly motivated," "exceptional," "expert," "innovative," "creative," "go-getter," or "thought leader."
4. **Strip Filler Adjectives**: Do not use vague or melodramatic filler adjectives. Instead, focus on hard technical tools, methodologies, and factual descriptors.
5. **Rely on Hard Facts & Metrics**: Build the summary around concrete data points, specific metrics, achievements, and actual work philosophy extracted from the experience and projects list. (e.g. if they reduced latency by 30%, or built a pipeline handling 10k requests, mention it naturally). Do not invent or exaggerate any accomplishments, numbers, or tech stacks.
6. **Varied, Natural Sentence Structure**: Use natural, varied sentence structures. Avoid repetitive grammatical patterns.
7. **Implicit First-Person/Active Voice**: Write in the active professional voice (e.g. starting directly with the role or a direct statement like "Software engineer focused on..." or "Full-stack developer building..."). Do NOT use third-person pronouns ("he", "she", "they", "his", "her") which make it sound like a pretentious third-person biography.
8. **The "Read Out Loud" / Coffee Test**: Self-correct your draft. If the summary would sound pretentious, bragging, or unnatural to say directly to a recruiter over a casual cup of coffee, simplify the language, drop the melodrama, and make it more direct.

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
      return parsed ?? {};
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    }
  }
}

final geminiServiceImplProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
