import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract AI service interface — allows swapping Gemini / OpenRouter
abstract class AIService {
  Future<Map<String, dynamic>> analyzeJobDescription(String jobDescription);
  Future<ProjectRewriteResult> rewriteProjectBullets({
    required String projectTitle,
    required String projectDescription,
    required List<String> technologies,
    required String targetRole,
    required List<String> keywords,
    List<String> linkedSkills = const [],
  });
  Future<List<String>> refineExperienceBullets({
    required String role,
    required String company,
    required List<String> rawBullets,
    required String targetRole,
    required List<String> keywords,
    required bool hasCertificateLink,
  });
  Future<String> generateProfessionalSummary({
    required String candidateBackground,
    required String targetRole,
    required List<String> keywords,
    required List<String> topSkills,
    List<Map<String, dynamic>>? experiences,
    String? jobDescription,
  });
}

class JdAnalysisResult {
  final String role;
  final String experienceLevel;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final List<String> keywords;
  final List<String> domainKeywords;

  // New deep research fields
  final List<String> nonNegotiableSkills;
  final List<String> highDemandSkills;
  final List<String> companyProblems;
  final List<String> companyTraits;
  final List<String> topKeywords;
  final List<String> highImpactBullets;
  final List<String> standoutProjects;
  final String roleStrategy;

  const JdAnalysisResult({
    required this.role,
    required this.experienceLevel,
    required this.requiredSkills,
    required this.preferredSkills,
    required this.keywords,
    required this.domainKeywords,
    this.nonNegotiableSkills = const [],
    this.highDemandSkills = const [],
    this.companyProblems = const [],
    this.companyTraits = const [],
    this.topKeywords = const [],
    this.highImpactBullets = const [],
    this.standoutProjects = const [],
    this.roleStrategy = '',
  });

  factory JdAnalysisResult.fromJson(Map<String, dynamic> json) {
    return JdAnalysisResult(
      role: json['role'] as String? ?? 'Software Engineer',
      experienceLevel: json['experienceLevel'] as String? ?? 'mid',
      requiredSkills: _toStringList(json['requiredSkills']),
      preferredSkills: _toStringList(json['preferredSkills']),
      keywords: _toStringList(json['keywords']),
      domainKeywords: _toStringList(json['domainKeywords']),
      nonNegotiableSkills: _toStringList(json['nonNegotiableSkills']),
      highDemandSkills: _toStringList(json['highDemandSkills']),
      companyProblems: _toStringList(json['companyProblems']),
      companyTraits: _toStringList(json['companyTraits']),
      topKeywords: _toStringList(json['topKeywords']),
      highImpactBullets: _toStringList(json['highImpactBullets']),
      standoutProjects: _toStringList(json['standoutProjects']),
      roleStrategy: json['roleStrategy'] as String? ?? '',
    );
  }

  List<String> get allKeywords => [
        ...keywords,
        ...requiredSkills,
        ...domainKeywords,
        ...topKeywords,
      ];

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }
}

/// AI project rewrite result model
class ProjectRewriteResult {
  final List<String> bullets;
  final List<String> selectedSkills;

  const ProjectRewriteResult({
    required this.bullets,
    required this.selectedSkills,
  });

  factory ProjectRewriteResult.fromJson(Map<String, dynamic> json) {
    return ProjectRewriteResult(
      bullets: _toStringList(json['bullets']),
      selectedSkills: _toStringList(json['selectedSkills']),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }
}

/// Validates and safely parses AI JSON responses
Map<String, dynamic>? safeParseAiJson(String raw) {
  try {
    // Extract JSON block if wrapped in markdown
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(raw);
    if (match == null) return null;
    return json.decode(match.group(0)!) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

List<String>? safeParseStringList(dynamic value) {
  if (value is List) return value.cast<String>();
  return null;
}

/// Provider exposing the active AI service
final aiServiceProvider = Provider<AIService>((ref) {
  return ref.watch(geminiServiceProvider);
});

// Circular import prevention — declare here, implement in gemini_service.dart
final geminiServiceProvider = Provider<AIService>((ref) {
  return throw UnimplementedError('Override in main.dart ProviderScope');
});
