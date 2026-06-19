import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/resume_generator/domain/entities/resume_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import 'generate_screen.dart';
import 'ai_analysis_screen.dart';
import 'project_selection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/providers/firebase_providers.dart';
import 'package:uuid/uuid.dart';

// ── Selected Template Provider ─────────────────────────────

final selectedTemplateProvider =
    StateProvider<ResumeTemplate>((ref) => ResumeTemplate.atsProfessional);

// ── Template Selection Screen ──────────────────────────────

class TemplateSelectionScreen extends ConsumerStatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  ConsumerState<TemplateSelectionScreen> createState() =>
      _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState
    extends ConsumerState<TemplateSelectionScreen> {
  bool _isGenerating = false;

  Future<void> _generateResume() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _isGenerating = true);

    try {
      final jd = ref.read(jobDescriptionProvider);
      final analysis = ref.read(jdAnalysisProvider).valueOrNull;
      final selectedIds = ref.read(selectedProjectIdsProvider);
      final template = ref.read(selectedTemplateProvider);

      if (analysis == null) throw Exception('No analysis available');

      final ai = ref.read(geminiServiceImplProvider);

      // Fetch user profile
      final user =
          await ref.read(profileRepositoryProvider).getUser(uid);
      if (user == null) throw Exception('User profile not found');

      // Fetch selected projects
      final List<ProjectModel> allProjects =
          await ref.read(projectRepositoryProvider).getAllProjects(uid);
      final List<ProjectModel> selectedProjects = allProjects
          .where((ProjectModel p) => selectedIds.contains(p.id))
          .toList();

      // AI: rewrite bullets for each project
      final rewrittenProjects = <ResumeProject>[];
      for (final ProjectModel project in selectedProjects) {
        final result = await ai.rewriteProjectBullets(
          projectTitle: project.title,
          projectDescription: project.description,
          technologies: project.technologies,
          targetRole: analysis.role,
          keywords: analysis.allKeywords,
          linkedSkills: project.linkedSkills,
        );
        
        final combinedTech = <String>{
          ...result.selectedSkills,
          ...project.technologies,
        }.toList();

        rewrittenProjects.add(ResumeProject(
          title: project.title,
          technologies: combinedTech,
          bullets: result.bullets,
          githubUrl: project.githubRepo,
          liveUrl: project.liveUrl,
        ));
      }

      // AI: generate professional summary
      final summary = await ai.generateProfessionalSummary(
        candidateBackground: user.summary.trim().isNotEmpty ? user.summary : 'Experienced software developer / IT professional',
        targetRole: analysis.role.trim().isNotEmpty ? analysis.role : 'Software Professional',
        keywords: analysis.allKeywords,
        topSkills: selectedProjects
            .expand((ProjectModel p) => p.technologies)
            .toSet()
            .take(8)
            .cast<String>()
            .toList(),
      );

      // Fetch user profile sub-collections (skills, education, experience, certifications, achievements)
      final skillsSnap = await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('skills')
          .orderBy('createdAt', descending: false)
          .get();
      final skillGroupsMap = <String, List<String>>{};
      for (final doc in skillsSnap.docs) {
        final d = doc.data();
        final cat = d['category'] as String? ?? 'Other';
        final name = d['name'] as String? ?? '';
        if (name.isNotEmpty) {
          skillGroupsMap.putIfAbsent(cat, () => []).add(name);
        }
      }
      final skillGroupsList = skillGroupsMap.entries
          .map((e) => ResumeSkillGroup(category: e.key, skills: e.value))
          .toList();

      final eduSnap = await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('education')
          .get();
      final educationList = eduSnap.docs.map((doc) {
        final m = doc.data();
        final cgpaVal = m['cgpa'] as String? ?? m['percentage'] as String? ?? '';
        final startMonth = m['startMonth'] as String? ?? '';
        final startYear = m['startYear'] as String? ?? '';
        final endMonth = m['endMonth'] as String? ?? '';
        final endYear = m['endYear'] as String? ?? '';
        
        // Format duration nicely
        String dur = "";
        final hasStart = startMonth.isNotEmpty || startYear.isNotEmpty;
        final hasEnd = endMonth.isNotEmpty || endYear.isNotEmpty;
        if (hasStart && hasEnd) {
          final startPart = "$startMonth $startYear".trim();
          final endPart = "$endMonth $endYear".trim();
          dur = "$startPart - $endPart";
        } else if (hasStart) {
          dur = "$startMonth $startYear".trim();
        } else if (hasEnd) {
          dur = "$endMonth $endYear".trim();
        }
        
        String inst = m['institution'] as String? ?? '';
        final loc = m['location'] as String? ?? '';
        if (loc.isNotEmpty && !inst.contains(loc)) {
          inst = "$inst, $loc";
        }
        
        return ResumeEducation(
          institution: inst,
          degree: m['degree'] as String? ?? '',
          field: m['field'] as String? ?? '',
          cgpa: cgpaVal,
          duration: dur,
        );
      }).toList();

      final expSnap = await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('experience')
          .get();
      final experienceList = expSnap.docs.map((doc) {
        final m = doc.data();
        final bulletsList = m['bullets'] != null ? List<String>.from(m['bullets'] as List) : <String>[];
        final startMonth = m['startMonth'] as String? ?? '';
        final startYear = m['startYear'] as String? ?? '';
        final endMonth = m['endMonth'] as String? ?? '';
        final endYear = m['endYear'] as String? ?? '';
        
        String dur = "";
        if (startMonth.isNotEmpty || startYear.isNotEmpty) {
          dur = "$startMonth $startYear".trim();
          if (endMonth.isNotEmpty || endYear.isNotEmpty) {
            dur += " - $endMonth $endYear".trim();
          } else {
            dur += " - Present";
          }
        }
        
        return ResumeExperience(
          company: m['company'] as String? ?? '',
          role: m['role'] as String? ?? '',
          duration: dur,
          bullets: bulletsList,
        );
      }).toList();

      final certsSnap = await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('certifications')
          .get();
      final certificationsList = certsSnap.docs.map((doc) {
        final m = doc.data();
        return ResumeCertification(
          title: m['title'] as String? ?? '',
          issuer: m['issuer'] as String? ?? '',
          date: m['date'] as String? ?? '',
          credentialUrl: m['credentialUrl'] as String? ?? '',
        );
      }).toList();

      final achsSnap = await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .get();
      final achievementsList = achsSnap.docs
          .map((doc) => doc.data()['title'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // Build ResumeData
      final resumeData = ResumeData(
        name: user.name,
        email: user.email,
        phone: user.phone,
        location: user.location,
        githubUrl: user.githubUrl,
        linkedinUrl: user.linkedinUrl,
        portfolioUrl: user.portfolioUrl,
        summary: summary.isNotEmpty ? summary : user.summary,
        projects: rewrittenProjects,
        skillGroups: skillGroupsList,
        education: educationList,
        experience: experienceList,
        certifications: certificationsList,
        achievements: achievementsList,
      );

      // Compute ATS score (code, not AI)
      final resumeText = _resumeToText(resumeData);
      final atsScore = _computeAtsScore(resumeText, analysis.allKeywords);

      // Save to Firestore
      final resumeId = const Uuid().v4();
      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('resumes')
          .doc(resumeId)
          .set({
        'jobDescription': jd,
        'jobRole': analysis.role,
        'detectedKeywords': analysis.keywords,
        'requiredSkills': analysis.requiredSkills,
        'matchedProjectIds': selectedIds.toList(),
        'matchPercentage':
            (selectedProjects.isNotEmpty ? 70 : 30),
        'generatedResumeData': resumeData.toJson(),
        'templateUsed': template.name,
        'atsScore': atsScore,
        'missingKeywords': _findMissingKeywords(
            resumeText, analysis.allKeywords),
        'status': 'complete',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.pushReplacement(
          RouteNames.generatePreview.replaceAll(':resumeId', resumeId),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _resumeToText(ResumeData data) {
    final buf = StringBuffer();
    buf.write(data.summary);
    for (final p in data.projects) {
      buf.write(' ${p.title}');
      buf.write(' ${p.technologies.join(' ')}');
      buf.write(' ${p.bullets.join(' ')}');
    }
    return buf.toString().toLowerCase();
  }

  int _computeAtsScore(String text, List<String> keywords) {
    if (keywords.isEmpty) return 50;
    int matched = 0;
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) matched++;
    }
    return ((matched / keywords.length) * 100).round().clamp(20, 100);
  }

  List<String> _findMissingKeywords(
      String text, List<String> keywords) {
    return keywords
        .where((kw) => !text.contains(kw.toLowerCase()))
        .take(10)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTemplateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(AppStrings.selectTemplate),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 4),
            child: Text(
              'Choose a resume template that fits your style.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _TemplateCard(
                  template: ResumeTemplate.atsProfessional,
                  title: AppStrings.templateAts,
                  subtitle: AppStrings.templateAtsSub,
                  icon: Icons.check_circle_outline_rounded,
                  description:
                      'Single column, clean formatting — maximally parseable by ATS systems. Best for corporate roles.',
                  isSelected:
                      selected == ResumeTemplate.atsProfessional,
                  accentColor: AppColors.success,
                  onTap: () => ref
                      .read(selectedTemplateProvider.notifier)
                      .state = ResumeTemplate.atsProfessional,
                ),
                const SizedBox(height: 12),
                _TemplateCard(
                  template: ResumeTemplate.modernMinimal,
                  title: AppStrings.templateModern,
                  subtitle: AppStrings.templateModernSub,
                  icon: Icons.grid_view_rounded,
                  description:
                      'Two-column layout with sidebar. Elegant for design and tech roles. Balances visual appeal with ATS.',
                  isSelected:
                      selected == ResumeTemplate.modernMinimal,
                  accentColor: AppColors.accent,
                  onTap: () => ref
                      .read(selectedTemplateProvider.notifier)
                      .state = ResumeTemplate.modernMinimal,
                ),
                const SizedBox(height: 12),
                _TemplateCard(
                  template: ResumeTemplate.compactClean,
                  title: AppStrings.templateCompact,
                  subtitle: AppStrings.templateCompactSub,
                  icon: Icons.compress_rounded,
                  description:
                      'Dense but highly readable. Smart truncation keeps everything to 1 page.',
                  isSelected: selected == ResumeTemplate.compactClean,
                  accentColor: AppColors.warning,
                  onTap: () => ref
                      .read(selectedTemplateProvider.notifier)
                      .state = ResumeTemplate.compactClean,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('AI is crafting your resume...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.generateNow,
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ResumeTemplate template;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.04)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : AppColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTypography.headlineSmall),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected',
                            style: AppTypography.labelSmall.copyWith(
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.labelMedium.copyWith(
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
