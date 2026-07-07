import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import 'ai_analysis_screen.dart';

// Recommended skills list for category lookup
const Map<String, List<String>> _kRecommendedSkills = {
  'Languages': [
    'Java', 'Python', 'Dart', 'JavaScript', 'TypeScript',
    'C++', 'C#', 'HTML/CSS', 'SQL', 'Go', 'Rust', 'Kotlin', 'Swift', 'Ruby', 'PHP', 'Scala', 'R', 'Shell Scripting', 'GraphQL', 'Dart/Flutter'
  ],
  'Tools/Platforms': [
    'Git', 'GitHub', 'VS Code', 'Docker', 'Kubernetes',
    'Power BI', 'Tableau', 'Figma', 'Jira', 'Postman', 'Firebase', 'Amplitude', 'Xcode', 'Android Studio', 'Unity', 'Webpack', 'Vite', 'Slack', 'Trello', 'Confluence'
  ],
  'DevOps & Cloud': [
    'AWS', 'Google Cloud (GCP)', 'Microsoft Azure', 'CI/CD (GitHub Actions)', 'Terraform',
    'Jenkins', 'Linux', 'Nginx', 'Prometheus', 'Grafana', 'Ansible', 'Puppet', 'Chef', 'Travis CI', 'AWS Lambda', 'Cloudflare', 'S3', 'EC2', 'Docker Compose', 'Helm'
  ],
  'Soft Skills': [
    'Problem-Solving', 'Team Player', 'Communication', 'Agile/Scrum', 'Leadership',
    'Critical Thinking', 'Time Management', 'Adaptability', 'Mentoring', 'Collaboration', 'Negotiation', 'Conflict Resolution', 'Decision Making', 'Empathy', 'Public Speaking', 'Creativity', 'Active Listening', 'Strategic Planning', 'Emotional Intelligence', 'Presentation'
  ],
};

const Map<String, Color> _kCategoryColors = {
  'Languages': Color(0xFF6366F1),
  'Tools/Platforms': Color(0xFF0EA5E9),
  'DevOps & Cloud': Color(0xFF10B981),
  'Soft Skills': Color(0xFFF59E0B),
};

String _getCategoryForSkill(String name) {
  final cleanName = name.trim().toLowerCase();
  
  const Map<String, String> explicitMappings = {
    'javascript': 'Languages',
    'typescript': 'Languages',
    'python': 'Languages',
    'dart': 'Languages',
    'java': 'Languages',
    'c++': 'Languages',
    'c#': 'Languages',
    'go': 'Languages',
    'golang': 'Languages',
    'rust': 'Languages',
    'ruby': 'Languages',
    'php': 'Languages',
    'swift': 'Languages',
    'kotlin': 'Languages',
    'sql': 'Languages',
    'html': 'Languages',
    'css': 'Languages',
    'html/css': 'Languages',
    
    'aws': 'DevOps & Cloud',
    'gcp': 'DevOps & Cloud',
    'azure': 'DevOps & Cloud',
    'docker': 'DevOps & Cloud',
    'kubernetes': 'DevOps & Cloud',
    'ci/cd': 'DevOps & Cloud',
    'github actions': 'DevOps & Cloud',
    'jenkins': 'DevOps & Cloud',
    'terraform': 'DevOps & Cloud',
    'ansible': 'DevOps & Cloud',
    'linux': 'DevOps & Cloud',
    'nginx': 'DevOps & Cloud',
    
    'communication': 'Soft Skills',
    'problem-solving': 'Soft Skills',
    'leadership': 'Soft Skills',
    'teamwork': 'Soft Skills',
    'agile': 'Soft Skills',
    'scrum': 'Soft Skills',
    'adaptability': 'Soft Skills',
    'time management': 'Soft Skills',
    'collaboration': 'Soft Skills',
  };

  if (explicitMappings.containsKey(cleanName)) {
    return explicitMappings[cleanName]!;
  }

  for (final entry in _kRecommendedSkills.entries) {
    if (entry.value.any((s) => s.toLowerCase() == cleanName)) {
      return entry.key;
    }
  }

  if (cleanName.contains('cloud') || cleanName.contains('devops') || cleanName.contains('kubernetes') || cleanName.contains('pipeline')) {
    return 'DevOps & Cloud';
  }

  return 'Tools/Platforms';
}

class SkillPreferenceScreen extends ConsumerStatefulWidget {
  const SkillPreferenceScreen({super.key});

  @override
  ConsumerState<SkillPreferenceScreen> createState() => _SkillPreferenceScreenState();
}

class _SkillPreferenceScreenState extends ConsumerState<SkillPreferenceScreen> {
  final _manualSkillCtrl = TextEditingController();

  @override
  void dispose() {
    _manualSkillCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSkill(String uid, String name, String category) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    try {
      await ref.read(profileRepositoryProvider).addSkill(uid, cleanName, category);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$cleanName" to your resume!'),
            backgroundColor: AppColors.success,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add skill: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _removeSkill(String uid, String id, String name) async {
    try {
      await ref.read(profileRepositoryProvider).deleteSkill(uid, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$name"'),
            backgroundColor: Colors.white12,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove skill: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final analysisAsync = ref.watch(jdAnalysisProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF07060F),
        body: Center(child: Text('Please log in', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          'Skill Preference',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Aurora gradients
          Positioned(
            top: -60, left: -60, width: 200, height: 200,
            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF0F6))),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.5, height: screenHeight * 0.4,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(color: const Color(0xFF07060F).withValues(alpha: 0.35)),
            ),
          ),

          SafeArea(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref.read(profileRepositoryProvider).watchSkills(uid),
              builder: (context, skillsSnap) {
                final mySkills = skillsSnap.data ?? [];
                final ownedLower = mySkills.map((s) => (s['name'] as String).toLowerCase().trim()).toSet();

                return analysisAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFCBE349))),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
                  data: (analysis) {
                    final jdRequired = analysis?.requiredSkills ?? [];
                    final jdPreferred = analysis?.preferredSkills ?? [];

                    // Compute missing and matching skills from the JD
                    final matchingJdSkills = <String>[];
                    final recommendedJdSkills = <String>[];

                    for (final req in jdRequired) {
                      if (ownedLower.contains(req.toLowerCase().trim())) {
                        matchingJdSkills.add(req);
                      } else {
                        recommendedJdSkills.add(req);
                      }
                    }
                    for (final pref in jdPreferred) {
                      if (ownedLower.contains(pref.toLowerCase().trim())) {
                        if (!matchingJdSkills.contains(pref)) {
                          matchingJdSkills.add(pref);
                        }
                      } else {
                        if (!recommendedJdSkills.contains(pref)) {
                          recommendedJdSkills.add(pref);
                        }
                      }
                    }

                    // Group current profile skills by category
                    final groupedSkills = <String, List<Map<String, dynamic>>>{};
                    for (final skill in mySkills) {
                      final cat = skill['category'] as String? ?? 'Tools/Platforms';
                      groupedSkills.putIfAbsent(cat, () => []).add(skill);
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Align your skills with the Job Description to maximize your ATS compatibility score.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // ── 1. RECOMMENDED SKILLS TO ADD ───────────────────────
                                if (recommendedJdSkills.isNotEmpty) ...[
                                  Text(
                                    'RECOMMENDED SKILLS TO STAND OUT',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFCBE349),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'These required skills were found in the JD but are missing from your profile. Tap to add them to your resume.',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white38,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: recommendedJdSkills.map((name) {
                                      final category = _getCategoryForSkill(name);
                                      final catColor = _kCategoryColors[category] ?? const Color(0xFFCBE349);

                                      return GestureDetector(
                                        onTap: () => _addSkill(uid, name, category),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 76),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: catColor.withValues(alpha: 0.25),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.add_rounded, size: 14, color: catColor),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 28),
                                ],

                                // ── 2. MATCHING SKILLS ─────────────────────────────────
                                if (matchingJdSkills.isNotEmpty) ...[
                                  Text(
                                    'MATCHED REQUIREMENTS',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: matchingJdSkills.map((name) {
                                      final category = _getCategoryForSkill(name);
                                      final catColor = _kCategoryColors[category] ?? const Color(0xFF10B981);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 76),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: catColor.withValues(alpha: 0.4),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 28),
                                ],

                                // ── 3. ADD CUSTOM SKILL ───────────────────────────────
                                Text(
                                  'ADD CUSTOM SKILL',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white30,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _manualSkillCtrl,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Enter a custom skill...',
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 0.03),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onSubmitted: (val) {
                                          final cat = _getCategoryForSkill(val);
                                          _addSkill(uid, val, cat);
                                          _manualSkillCtrl.clear();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        final val = _manualSkillCtrl.text.trim();
                                        if (val.isNotEmpty) {
                                          final cat = _getCategoryForSkill(val);
                                          _addSkill(uid, val, cat);
                                          _manualSkillCtrl.clear();
                                        }
                                      },
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCBE349),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.add_rounded, color: Color(0xFF07060F), size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // ── 4. RESUME SKILL GROUPS (CURRENT RESUME LAYOUT) ─────
                                Text(
                                  'MY RESUME SKILL CATEGORIES',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white30,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (mySkills.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.01),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No skills added to your resume yet.',
                                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                      ),
                                    ),
                                  )
                                else
                                  ...groupedSkills.entries.map((group) {
                                    final catName = group.key;
                                    final color = _kCategoryColors[catName] ?? const Color(0xFFCBE349);
                                    final list = group.value;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.02),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 3.5,
                                                height: 12,
                                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                catName.toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: list.map((item) {
                                              final name = item['name'] as String;
                                              final id = item['id'] as String;

                                              return Container(
                                                padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 104),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.03),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        name,
                                                        style: GoogleFonts.outfit(
                                                          color: Colors.white70,
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    GestureDetector(
                                                      onTap: () => _removeSkill(uid, id, name),
                                                      child: Icon(Icons.close_rounded, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),

                        // ── Bottom CTA Bar ──────────────────────────────
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                20, 12, 20,
                                MediaQuery.of(context).padding.bottom + 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF07060F).withValues(alpha: 0.7),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () => context.push(RouteNames.generateSelectTemplate),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 17),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCBE349),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFCBE349).withValues(alpha: 0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Continue to Template',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF07060F),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Color(0xFF07060F),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
