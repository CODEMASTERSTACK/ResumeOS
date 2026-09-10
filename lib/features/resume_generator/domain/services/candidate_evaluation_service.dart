import 'dart:math' as math;
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../services/ai/ai_service.dart';

/// Detailed breakdown of the ATS evaluation across 4 pillars.
class CandidateScoreBreakdown {
  final double overallScore; // 0.0 to 1.0 (0% - 100%)
  final double skillsScore; // 0.0 to 1.0
  final double projectsScore; // 0.0 to 1.0
  final double experienceScore; // 0.0 to 1.0
  final double credentialsScore; // 0.0 to 1.0

  // Effective weights used for this calculation
  final double skillsWeight;
  final double projectsWeight;
  final double experienceWeight;
  final double credentialsWeight;

  // Granular metrics
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> matchedKeywords;
  final List<String> gapRecommendations;
  final String seniorityVerdict;
  final bool isEarlyCareerAdjusted;

  const CandidateScoreBreakdown({
    required this.overallScore,
    required this.skillsScore,
    required this.projectsScore,
    required this.experienceScore,
    required this.credentialsScore,
    required this.skillsWeight,
    required this.projectsWeight,
    required this.experienceWeight,
    required this.credentialsWeight,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchedKeywords,
    required this.gapRecommendations,
    required this.seniorityVerdict,
    required this.isEarlyCareerAdjusted,
  });

  int get overallPercentage => (overallScore * 100).round().clamp(0, 100);
  int get skillsPercentage => (skillsScore * 100).round().clamp(0, 100);
  int get projectsPercentage => (projectsScore * 100).round().clamp(0, 100);
  int get experiencePercentage => (experienceScore * 100).round().clamp(0, 100);
  int get credentialsPercentage => (credentialsScore * 100).round().clamp(0, 100);

  String get verdictTitle {
    if (overallPercentage >= 80) return 'Exceptional Match';
    if (overallPercentage >= 65) return 'Strong Competitive Fit';
    if (overallPercentage >= 45) return 'Good Match — Tailoring Recommended';
    return 'Skill Gap Detected — AI Can Bridge';
  }

  String get verdictSubtitle {
    if (overallPercentage >= 80) {
      return 'Your profile strongly meets or exceeds the core technical requirements for this role.';
    }
    if (overallPercentage >= 65) {
      return 'Solid foundation with high core overlap. Focusing on key standout bullets will elevate your candidacy.';
    }
    if (overallPercentage >= 45) {
      return 'Moderate overlap. Linking relevant project skills and highlighting transferable experience will boost interview rates.';
    }
    return 'Some required competencies are missing from your profile. Check the gap recommendations below to optimize.';
  }
}

/// Intelligent Candidate Evaluation Service.
/// Evaluates candidate readiness using multi-pillar ATS heuristics,
/// smart skill taxonomy synonyms, quality multipliers, and seniority calibration.
class CandidateEvaluationService {
  /// Known skill synonyms & equivalence maps for modern tech stacks.
  static final Map<String, List<String>> _skillSynonyms = {
    'flutter': ['dart', 'mobile app', 'cross-platform', 'flutter framework'],
    'dart': ['flutter'],
    'react': ['react.js', 'reactjs', 'javascript', 'typescript', 'frontend'],
    'react native': ['react', 'mobile app', 'javascript', 'typescript'],
    'node.js': ['node', 'nodejs', 'express', 'backend', 'javascript'],
    'python': ['django', 'fastapi', 'flask', 'data science', 'machine learning'],
    'java': ['spring', 'spring boot', 'jvm', 'backend'],
    'kotlin': ['android', 'mobile app', 'jvm'],
    'swift': ['ios', 'mobile app', 'swiftui'],
    'sql': ['postgresql', 'mysql', 'postgres', 'sqlite', 'database', 'relational db'],
    'postgresql': ['sql', 'postgres', 'rdbms'],
    'nosql': ['mongodb', 'firebase', 'firestore', 'dynamodb'],
    'firebase': ['firestore', 'cloud functions', 'firebase auth'],
    'docker': ['containerization', 'containers', 'devops', 'kubernetes'],
    'kubernetes': ['k8s', 'docker', 'devops', 'cloud'],
    'aws': ['amazon web services', 'cloud', 's3', 'ec2', 'lambda'],
    'gcp': ['google cloud', 'google cloud platform', 'cloud', 'bigquery'],
    'azure': ['microsoft azure', 'cloud'],
    'graphql': ['api', 'rest api', 'backend'],
    'rest': ['restful', 'rest api', 'api', 'http'],
    'git': ['github', 'version control', 'gitlab'],
    'ci/cd': ['github actions', 'jenkins', 'devops', 'continuous integration'],
    'machine learning': ['ml', 'ai', 'deep learning', 'tensorflow', 'pytorch'],
    'state management': ['bloc', 'riverpod', 'provider', 'redux', 'mobx'],
  };

  /// Smart matching checking exact term, whole-word boundary regex, or synonym graph.
  static bool hasSkillMatch(String targetSkill, Iterable<String> candidateSkills) {
    final cleanTarget = targetSkill.trim().toLowerCase();
    if (cleanTarget.isEmpty) return false;

    final targetVariants = <String>{cleanTarget};
    if (_skillSynonyms.containsKey(cleanTarget)) {
      targetVariants.addAll(_skillSynonyms[cleanTarget]!);
    }

    for (final candidate in candidateSkills) {
      final cleanCand = candidate.trim().toLowerCase();
      if (cleanCand.isEmpty) return false;

      // 1. Direct equality
      if (cleanCand == cleanTarget || targetVariants.contains(cleanCand)) {
        return true;
      }

      // 2. Exact word boundary regex check
      for (final variant in targetVariants) {
        if (_matchesWordBoundary(cleanCand, variant) || _matchesWordBoundary(variant, cleanCand)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _matchesWordBoundary(String text, String term) {
    if (term.length < 2) return text == term;
    final escaped = RegExp.escape(term);
    final reg = RegExp(r'(^|[\s,.\-_/])' + escaped + r'($|[\s,.\-_/])', caseSensitive: false);
    return reg.hasMatch(text);
  }

  /// Evaluates the complete candidate profile against a [JdAnalysisResult].
  static CandidateScoreBreakdown evaluate({
    required JdAnalysisResult analysis,
    required List<ProjectModel> projects,
    required List<String> profileSkills,
    required List<Map<String, dynamic>> experiences,
    required List<Map<String, dynamic>> educations,
    required List<Map<String, dynamic>> certifications,
    UserModel? user,
  }) {
    // ── 1. Aggregate candidate skills from all sources ──
    final allCandidateSkills = <String>{};
    for (final s in profileSkills) {
      allCandidateSkills.add(s.trim().toLowerCase());
    }
    for (final p in projects) {
      for (final t in p.technologies) {
        allCandidateSkills.add(t.trim().toLowerCase());
      }
      for (final s in p.linkedSkills) {
        allCandidateSkills.add(s.trim().toLowerCase());
      }
    }

    // ── 2. Pillar 1: Skills Competency (40% base) ──
    final nonNeg = analysis.nonNegotiableSkills.isNotEmpty
        ? analysis.nonNegotiableSkills
        : analysis.requiredSkills.take(3).toList();
    final required = analysis.requiredSkills;
    final preferred = [
      ...analysis.preferredSkills,
      ...analysis.highDemandSkills,
    ];

    int matchedNonNeg = 0;
    int matchedReq = 0;
    int matchedPref = 0;

    final matchedSkillsList = <String>[];
    final missingSkillsList = <String>[];

    for (final skill in nonNeg) {
      if (hasSkillMatch(skill, allCandidateSkills)) {
        matchedNonNeg++;
        matchedSkillsList.add(skill);
      } else {
        missingSkillsList.add(skill);
      }
    }

    for (final skill in required) {
      if (hasSkillMatch(skill, allCandidateSkills)) {
        matchedReq++;
        if (!matchedSkillsList.contains(skill)) matchedSkillsList.add(skill);
      } else {
        if (!missingSkillsList.contains(skill)) missingSkillsList.add(skill);
      }
    }

    for (final skill in preferred) {
      if (hasSkillMatch(skill, allCandidateSkills)) {
        matchedPref++;
        if (!matchedSkillsList.contains(skill)) matchedSkillsList.add(skill);
      }
    }

    final double nonNegRatio = nonNeg.isEmpty ? 1.0 : (matchedNonNeg / nonNeg.length).clamp(0.0, 1.0);
    final double reqRatio = required.isEmpty ? 1.0 : (matchedReq / required.length).clamp(0.0, 1.0);
    final double prefRatio = preferred.isEmpty ? 1.0 : (matchedPref / preferred.length).clamp(0.0, 1.0);

    // Weighted skills sub-score: 50% non-negotiable, 35% required, 15% preferred
    final double skillsScore = (nonNegRatio * 0.50) + (reqRatio * 0.35) + (prefRatio * 0.15);

    // ── 3. Pillar 2: Project Portfolio Proof (35% base) ──
    double projectsScore = 0.0;
    final allKeywords = analysis.allKeywords;

    if (projects.isNotEmpty) {
      final projectScores = <double>[];
      for (final p in projects) {
        // Keyword relevance
        final baseRel = p.scoreAgainst(allKeywords).clamp(0.0, 1.0);

        // Quality multipliers
        double qualityMultiplier = 1.0;
        if (p.githubRepo.trim().isNotEmpty) qualityMultiplier += 0.10;
        if (p.liveUrl.trim().isNotEmpty) qualityMultiplier += 0.15;
        if (p.linkedSkills.isNotEmpty) qualityMultiplier += 0.10;
        if (p.isFeatured || p.isResearch) qualityMultiplier += 0.15;

        final projectEffectiveScore = (baseRel * qualityMultiplier).clamp(0.0, 1.0);
        projectScores.add(projectEffectiveScore);
      }

      projectScores.sort((a, b) => b.compareTo(a));
      final topProj = projectScores.first;
      final secondProj = projectScores.length > 1 ? projectScores[1] : topProj * 0.5;
      final thirdProj = projectScores.length > 2 ? projectScores[2] : secondProj * 0.5;

      // Cumulative project portfolio weight: 50% top project, 30% second, 20% third
      projectsScore = ((topProj * 0.50) + (secondProj * 0.30) + (thirdProj * 0.20)).clamp(0.0, 1.0);
    }

    // ── 4. Pillar 3: Experience & Seniority Calibration (15% base) ──
    int totalExperienceMonths = 0;
    final expKeywordsMatched = <String>{};

    for (final exp in experiences) {
      final roleTitle = (exp['role'] ?? exp['title'] ?? '').toString().toLowerCase();
      final company = (exp['company'] ?? '').toString().toLowerCase();
      final desc = (exp['description'] ?? exp['summary'] ?? '').toString().toLowerCase();

      // Estimate tenure in months
      final isCurrent = exp['isCurrent'] == true;
      final startYear = int.tryParse(exp['startYear']?.toString() ?? '') ?? 2023;
      final endYear = isCurrent ? DateTime.now().year : (int.tryParse(exp['endYear']?.toString() ?? '') ?? startYear);
      final years = math.max(0, endYear - startYear);
      totalExperienceMonths += math.max(6, years * 12);

      // Check keyword alignment
      for (final kw in allKeywords) {
        final lkw = kw.toLowerCase();
        if (roleTitle.contains(lkw) || company.contains(lkw) || desc.contains(lkw)) {
          expKeywordsMatched.add(kw);
        }
      }
    }

    // Seniority benchmark
    final targetLevel = analysis.experienceLevel.toLowerCase();
    int targetMonthsRequired = 12; // default entry/junior
    if (targetLevel.contains('senior') || targetLevel.contains('lead') || targetLevel.contains('principal')) {
      targetMonthsRequired = 48; // 4+ years
    } else if (targetLevel.contains('mid')) {
      targetMonthsRequired = 24; // 2+ years
    } else if (targetLevel.contains('entry') || targetLevel.contains('junior') || targetLevel.contains('intern')) {
      targetMonthsRequired = 0; // entry level
    }

    double tenureRatio = targetMonthsRequired == 0
        ? 1.0
        : (totalExperienceMonths / targetMonthsRequired).clamp(0.0, 1.0);

    double expRelevanceRatio = allKeywords.isEmpty
        ? 1.0
        : (expKeywordsMatched.length / math.min(10, allKeywords.length)).clamp(0.0, 1.0);

    double experienceScore = experiences.isEmpty
        ? 0.0
        : ((tenureRatio * 0.6) + (expRelevanceRatio * 0.4)).clamp(0.0, 1.0);

    String seniorityVerdict;
    if (totalExperienceMonths >= 48) {
      seniorityVerdict = 'Senior Level (${(totalExperienceMonths / 12).toStringAsFixed(1)} yrs)';
    } else if (totalExperienceMonths >= 24) {
      seniorityVerdict = 'Mid Level (${(totalExperienceMonths / 12).toStringAsFixed(1)} yrs)';
    } else if (totalExperienceMonths > 0) {
      seniorityVerdict = 'Junior / Early Career ($totalExperienceMonths mos)';
    } else {
      seniorityVerdict = 'Student / Graduate Portfolio';
    }

    // ── 5. Pillar 4: Education & Certifications (10% base) ──
    double credentialsScore = 0.0;
    if (certifications.isNotEmpty || educations.isNotEmpty) {
      double certScore = 0.0;
      if (certifications.isNotEmpty) {
        certScore = (certifications.length * 0.4).clamp(0.0, 1.0);
      }

      double eduScore = 0.0;
      if (educations.isNotEmpty) {
        // Having completed or active degree
        eduScore = 0.7;
        for (final edu in educations) {
          final degree = (edu['degree'] ?? '').toString().toLowerCase();
          final field = (edu['field'] ?? '').toString().toLowerCase();
          if (field.contains('computer') ||
              field.contains('software') ||
              field.contains('tech') ||
              field.contains('data') ||
              field.contains('engineering') ||
              degree.contains('b.tech') ||
              degree.contains('b.e.') ||
              degree.contains('bachelor') ||
              degree.contains('master')) {
            eduScore = 1.0;
            break;
          }

        }
      }

      credentialsScore = ((certScore * 0.5) + (eduScore * 0.5)).clamp(0.0, 1.0);
    }

    // ── 6. Dynamic Rebalancing for Fresh Graduates / Students ──
    final bool isEarlyCareer = experiences.isEmpty && (certifications.isEmpty || educations.isEmpty);
    double wSkills = 0.40;
    double wProjects = 0.35;
    double wExp = 0.15;
    double wCred = 0.10;

    if (isEarlyCareer) {
      // Re-allocate experience & credential weights directly into verified skills and demonstrated projects
      wSkills = 0.55;
      wProjects = 0.45;
      wExp = 0.0;
      wCred = 0.0;
    } else if (experiences.isEmpty) {
      wSkills = 0.50;
      wProjects = 0.40;
      wExp = 0.0;
      wCred = 0.10;
    }

    final overall = ((skillsScore * wSkills) +
            (projectsScore * wProjects) +
            (experienceScore * wExp) +
            (credentialsScore * wCred))
        .clamp(0.0, 1.0);

    // ── 7. Generate Targeted Actionable Recommendations ──
    final recommendations = <String>[];
    if (missingSkillsList.isNotEmpty) {
      final topMissing = missingSkillsList.take(3).join(', ');
      recommendations.add('Add missing core skills to profile: $topMissing');
    }

    final projectsWithoutRepo = projects.where((p) => p.githubRepo.trim().isEmpty).length;
    if (projectsWithoutRepo > 0) {
      recommendations.add('Attach GitHub repository links to projects to increase ATS score by up to +10%.');
    }

    final projectsWithoutLive = projects.where((p) => p.liveUrl.trim().isEmpty).length;
    if (projectsWithoutLive > 0) {
      recommendations.add('Provide live demo / deployment links to boost portfolio credibility by +15%.');
    }

    final projectsWithoutLinkedSkills = projects.where((p) => p.linkedSkills.isEmpty).length;
    if (projectsWithoutLinkedSkills > 0) {
      recommendations.add('Link verified skills to your projects in the Projects tab for +10% relevance proof.');
    }

    if (experiences.isEmpty && targetMonthsRequired > 0) {
      recommendations.add('Target role expects $targetLevel experience. Frame project contributions around business impact.');
    }

    // Matched ATS keywords
    final matchedKw = <String>[];
    for (final kw in allKeywords) {
      if (allCandidateSkills.contains(kw.toLowerCase()) ||
          projects.any((p) => p.title.toLowerCase().contains(kw.toLowerCase()))) {
        matchedKw.add(kw);
      }
    }

    return CandidateScoreBreakdown(
      overallScore: overall,
      skillsScore: skillsScore,
      projectsScore: projectsScore,
      experienceScore: experienceScore,
      credentialsScore: credentialsScore,
      skillsWeight: wSkills,
      projectsWeight: wProjects,
      experienceWeight: wExp,
      credentialsWeight: wCred,
      matchedSkills: matchedSkillsList,
      missingSkills: missingSkillsList,
      matchedKeywords: matchedKw,
      gapRecommendations: recommendations,
      seniorityVerdict: seniorityVerdict,
      isEarlyCareerAdjusted: isEarlyCareer,
    );
  }
}
