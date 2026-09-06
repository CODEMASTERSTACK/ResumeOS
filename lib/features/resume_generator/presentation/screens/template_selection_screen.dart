import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
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
import 'ai_resume_crafting_overlay.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';
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
  String? _generatedResumeId;

  List<String> _getSelectedProjectNames() {
    final selectedIds = ref.read(selectedProjectIdsProvider);
    final rankedProjects = ref.read(rankedProjectsProvider).valueOrNull ?? [];
    return rankedProjects
        .map((record) => record.$1)
        .where((p) => selectedIds.contains(p.id))
        .map((p) => p.title)
        .toList();
  }

  void _showPreview(BuildContext context, String imagePath, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _TemplatePreviewDialog(
        title: title,
        imagePath: imagePath,
      ),
    );
  }

  Future<void> _generateResume() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() {
      _isGenerating = true;
      _generatedResumeId = null;
    });

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

      if (user.points < 2.5) {
        if (mounted) {
          _showLowBalanceDialog();
        }
        setState(() {
          _isGenerating = false;
        });
        return;
      }

      // Fetch all sub-collections and projects concurrently
      final expFuture = ref.read(firestoreProvider).collection('users').doc(uid).collection('experience').get();
      final skillsFuture = ref.read(firestoreProvider).collection('users').doc(uid).collection('skills').orderBy('createdAt', descending: false).get();
      final eduFuture = ref.read(firestoreProvider).collection('users').doc(uid).collection('education').get();
      final certsFuture = ref.read(firestoreProvider).collection('users').doc(uid).collection('certifications').get();
      final achsFuture = ref.read(firestoreProvider).collection('users').doc(uid).collection('achievements').get();
      final projectsFuture = ref.read(projectRepositoryProvider).getAllProjects(uid);

      final fetched = await Future.wait([
        expFuture,
        skillsFuture,
        eduFuture,
        certsFuture,
        achsFuture,
        projectsFuture,
      ]);

      final expSnap = fetched[0] as QuerySnapshot<Map<String, dynamic>>;
      final skillsSnap = fetched[1] as QuerySnapshot<Map<String, dynamic>>;
      final eduSnap = fetched[2] as QuerySnapshot<Map<String, dynamic>>;
      final certsSnap = fetched[3] as QuerySnapshot<Map<String, dynamic>>;
      final achsSnap = fetched[4] as QuerySnapshot<Map<String, dynamic>>;
      final allProjects = fetched[5] as List<ProjectModel>;

      final List<ProjectModel> selectedProjects = allProjects
          .where((ProjectModel p) => selectedIds.contains(p.id))
          .toList();

      final targetRole = analysis.role.trim().isNotEmpty
          ? analysis.role
          : 'Software Developer';

      // Convert experiences to serializable format for summary context
      final rawExperiences = expSnap.docs.map((doc) {
        final m = doc.data();
        final startMonth = m['startMonth'] as String? ?? '';
        final startYear = m['startYear'] as String? ?? '';
        final endMonth = m['endMonth'] as String? ?? '';
        final endYear = m['endYear'] as String? ?? '';
        final isCurrent = m['isCurrent'] as bool? ?? false;

        String dur = '';
        if (startMonth.isNotEmpty || startYear.isNotEmpty) {
          dur = '$startMonth $startYear'.trim();
          if (isCurrent) {
            dur += ' - Present';
          } else if (endMonth.isNotEmpty || endYear.isNotEmpty) {
            dur += ' - $endMonth $endYear'.trim();
          }
        }

        return {
          'role': m['role'] as String? ?? '',
          'company': m['company'] as String? ?? '',
          'duration': dur,
          'bullets': m['bullets'] != null ? List<String>.from(m['bullets'] as List) : <String>[],
        };
      }).toList();

      // Launch ALL AI operations concurrently (Project rewrites + Professional Summary + Experience bullet refinements)
      final projectRewriteFutures = selectedProjects.map((project) async {
        final projectDesc = project.description.trim().isNotEmpty
            ? project.description
            : (project.bulletPoints.isNotEmpty
                ? project.bulletPoints.join('\n')
                : 'A project titled "${project.title}" utilizing ${project.technologies.join(', ')}.');

        final result = await ai.rewriteProjectBullets(
          projectTitle: project.title,
          projectDescription: projectDesc,
          technologies: project.technologies,
          targetRole: targetRole,
          keywords: analysis.allKeywords,
          linkedSkills: project.linkedSkills,
        );

        final combinedTech = <String>{
          ...result.selectedSkills,
          ...project.technologies,
        }.toList();

        return (
          project: ResumeProject(
            title: project.title,
            technologies: combinedTech,
            bullets: result.bullets,
            githubUrl: project.githubRepo,
            liveUrl: project.liveUrl,
            duration: project.duration,
          ),
          isResearch: project.isResearch,
        );
      });

      final summaryFuture = ai.generateProfessionalSummary(
        candidateBackground: user.summary.trim().isNotEmpty
            ? user.summary
            : 'Experienced software developer / IT professional',
        targetRole: targetRole,
        keywords: analysis.allKeywords,
        topSkills: selectedProjects
            .expand((ProjectModel p) => p.technologies)
            .toSet()
            .take(8)
            .cast<String>()
            .toList(),
        experiences: rawExperiences,
        jobDescription: jd,
      );

      final experienceFutures = expSnap.docs.map((doc) async {
        final m = doc.data();
        final bulletsList = m['bullets'] != null
            ? List<String>.from(m['bullets'] as List)
            : <String>[];
        final startMonth = m['startMonth'] as String? ?? '';
        final startYear = m['startYear'] as String? ?? '';
        final endMonth = m['endMonth'] as String? ?? '';
        final endYear = m['endYear'] as String? ?? '';
        final certLink = m['certificateLink'] as String? ?? '';
        final hasCert = certLink.trim().isNotEmpty;

        String dur = '';
        if (startMonth.isNotEmpty || startYear.isNotEmpty) {
          dur = '$startMonth $startYear'.trim();
          if (endMonth.isNotEmpty || endYear.isNotEmpty) {
            dur += ' - $endMonth $endYear'.trim();
          } else {
            dur += ' - Present';
          }
        }

        List<String> refinedBullets = bulletsList;
        try {
          refinedBullets = await ai.refineExperienceBullets(
            role: m['role'] as String? ?? '',
            company: m['company'] as String? ?? '',
            rawBullets: bulletsList,
            targetRole: targetRole,
            keywords: analysis.allKeywords,
            hasCertificateLink: hasCert,
          );
        } catch (e) {
          debugPrint('Error refining experience bullets via AI: $e');
        }

        final finalBullets = List<String>.from(refinedBullets);
        if (hasCert) {
          finalBullets.add('Certificate Link: $certLink');
        }

        return ResumeExperience(
          company: m['company'] as String? ?? '',
          role: m['role'] as String? ?? '',
          duration: dur,
          bullets: finalBullets,
          certificateLink: certLink,
        );
      });

      // Await all AI tasks concurrently
      final aiResults = await Future.wait([
        Future.wait(projectRewriteFutures),
        summaryFuture,
        Future.wait(experienceFutures),
      ]);

      final rewrittenItems = aiResults[0] as List<({ResumeProject project, bool isResearch})>;
      final summary = aiResults[1] as String;
      final experienceList = aiResults[2] as List<ResumeExperience>;

      final rewrittenProjects = <ResumeProject>[];
      final rewrittenResearch = <ResumeProject>[];
      for (final item in rewrittenItems) {
        if (item.isResearch) {
          rewrittenResearch.add(item.project);
        } else {
          rewrittenProjects.add(item.project);
        }
      }

      // Fetch user profile sub-collections
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

      final educationList = eduSnap.docs.map((doc) {
        final m = doc.data();
        final cgpaVal =
            m['cgpa'] as String? ?? m['percentage'] as String? ?? '';
        final startMonth = m['startMonth'] as String? ?? '';
        final startYear = m['startYear'] as String? ?? '';
        final endMonth = m['endMonth'] as String? ?? '';
        final endYear = m['endYear'] as String? ?? '';

        String dur = '';
        final hasStart =
            startMonth.isNotEmpty || startYear.isNotEmpty;
        final hasEnd = endMonth.isNotEmpty || endYear.isNotEmpty;
        if (hasStart && hasEnd) {
          final startPart = '$startMonth $startYear'.trim();
          final endPart = '$endMonth $endYear'.trim();
          dur = '$startPart - $endPart';
        } else if (hasStart) {
          dur = '$startMonth $startYear'.trim();
        } else if (hasEnd) {
          dur = '$endMonth $endYear'.trim();
        }

        String inst = m['institution'] as String? ?? '';
        final loc = m['location'] as String? ?? '';
        if (loc.isNotEmpty && !inst.contains(loc)) {
          inst = '$inst, $loc';
        }

        return ResumeEducation(
          institution: inst,
          degree: m['degree'] as String? ?? '',
          field: m['field'] as String? ?? '',
          cgpa: cgpaVal,
          duration: dur,
        );
      }).toList();

      final certificationsList = certsSnap.docs.map((doc) {
        final m = doc.data();
        return ResumeCertification(
          title: m['title'] as String? ?? '',
          issuer: m['issuer'] as String? ?? '',
          date: m['date'] as String? ?? '',
          credentialUrl: m['credentialUrl'] as String? ?? '',
        );
      }).toList();

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
        research: rewrittenResearch,
        showResearch: true,
        skillGroups: skillGroupsList,
        education: educationList,
        experience: experienceList,
        certifications: certificationsList,
        achievements: achievementsList,
      );

      // Compute ATS score
      final resumeText = _resumeToText(resumeData);
      final atsScore = _computeAtsScore(resumeText, analysis.allKeywords);

      // Save to Firestore and deduct points atomically
      final resumeId = const Uuid().v4();
      final userRef = ref.read(firestoreProvider).collection('users').doc(uid);
      final resumeRef = userRef.collection('resumes').doc(resumeId);
      final historyRef = userRef.collection('points_history').doc();

      await ref.read(firestoreProvider).runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User profile not found');
        }
        
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final currentPoints = (userData['points'] as num? ?? 10.0).toDouble();
        
        if (currentPoints < 2.5) {
          throw Exception('Low balance');
        }

        // Deduct points
        transaction.update(userRef, {
          'points': currentPoints - 2.5,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write transaction history log
        transaction.set(historyRef, {
          'title': 'AI Resume Generation',
          'description': 'Generated resume for role: ${analysis.role}',
          'points': -2.5,
          'type': 'deduction',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Write resume
        transaction.set(resumeRef, {
          'jobDescription': jd,
          'jobRole': analysis.role,
          'detectedKeywords': analysis.keywords,
          'requiredSkills': analysis.requiredSkills,
          'matchedProjectIds': selectedIds.toList(),
          'matchPercentage': atsScore,
          'generatedResumeData': resumeData.toJson(),
          'templateUsed': template.name,
          'atsScore': atsScore,
          'missingKeywords':
              _findMissingKeywords(resumeText, analysis.allKeywords),
          'status': 'complete',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        setState(() {
          _generatedResumeId = resumeId;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('Low balance')) {
          _showLowBalanceDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generation failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedResumeId = null;
        });
      }
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
    for (final r in data.research) {
      buf.write(' ${r.title}');
      buf.write(' ${r.technologies.join(' ')}');
      buf.write(' ${r.bullets.join(' ')}');
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

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTemplateProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final candidateName = ref.watch(userProfileProvider).valueOrNull?.name ?? '';

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
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          'Choose Template',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Aurora background
          Positioned(
            top: -60, left: -60, width: 200, height: 200,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.5, height: screenHeight * 0.4,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            width: screenHeight * 0.35, height: screenHeight * 0.35,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.35),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header subtitle ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Each template is ATS-optimised.\nPick the layout that fits your industry.',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ],
                  ),
                ),

                // ── Template list ───────────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      _TemplateCard(
                        template: ResumeTemplate.atsProfessional,
                        title: AppStrings.templateAts,
                        tag: 'Most Compatible',
                        tagColor: const Color(0xFF10B981),
                        description:
                            'Single column, clean formatting maximally parseable by ATS systems with professinal Summary. Best for corporate and enterprise roles.',
                        accentColor: const Color(0xFF10B981),
                        isSelected:
                            selected == ResumeTemplate.atsProfessional,
                        onTap: () => ref
                            .read(selectedTemplateProvider.notifier)
                            .state = ResumeTemplate.atsProfessional,
                        onInfoTap: () => _showPreview(
                          context,
                          'assets/images/template_icon/Ats_professional.png',
                          AppStrings.templateAts,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TemplateCard(
                        template: ResumeTemplate.modernMinimal,
                        title: AppStrings.templateModern,
                        tag: 'Design & Tech',
                        tagColor: const Color(0xFFCBE349),
                        description:
                            'A straightforward single column layout with a centered header and utilizes horizontal lines below section titles for a clean, organized, and highly readable structure.',
                        accentColor: const Color(0xFFCBE349),
                        isSelected:
                            selected == ResumeTemplate.modernMinimal,
                        onTap: () => ref
                            .read(selectedTemplateProvider.notifier)
                            .state = ResumeTemplate.modernMinimal,
                        onInfoTap: () => _showPreview(
                          context,
                          'assets/images/template_icon/modern_minimal.png',
                          AppStrings.templateModern,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TemplateCard(
                        template: ResumeTemplate.compactClean,
                        title: AppStrings.templateCompact,
                        tag: 'Space Efficient',
                        tagColor: const Color(0xFFF59E0B),
                        description:
                            'The resume template features a classic single column layout that uses thin horizontal lines to clearly separate distinct professional sections, ensuring a clean and easily readable document structure.',
                        accentColor: const Color(0xFFF59E0B),
                        isSelected:
                            selected == ResumeTemplate.compactClean,
                        onTap: () => ref
                            .read(selectedTemplateProvider.notifier)
                            .state = ResumeTemplate.compactClean,
                        onInfoTap: () => _showPreview(
                          context,
                          'assets/images/template_icon/compact_clean.png',
                          AppStrings.templateCompact,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Generate CTA ────────────────────────────
                _GenerateCTA(
                  isGenerating: _isGenerating,
                  onTap: _isGenerating ? null : _generateResume,
                ),
              ],
            ),
          ),
          if (_isGenerating)
            AiResumeCraftingOverlay(
              candidateName: candidateName,
              jobRole: ref.read(jdAnalysisProvider).valueOrNull?.role ?? '',
              keywords: ref.read(jdAnalysisProvider).valueOrNull?.allKeywords ?? [],
              projectNames: _getSelectedProjectNames(),
              templateName: selected.name,
              isGenerating: _isGenerating,
              isGenerationFinished: _generatedResumeId != null,
              onComplete: () {
                if (mounted && _generatedResumeId != null) {
                  final rid = _generatedResumeId!;
                  setState(() {
                    _isGenerating = false;
                    _generatedResumeId = null;
                  });
                  context.pushReplacement(
                    RouteNames.generatePreview.replaceAll(':resumeId', rid),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  void _showLowBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 12),
            Text(
              'Low Balance',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Generating a resume costs 2.5 points. Your current balance is insufficient.\n\nYou can claim weekly points in My Rewards or complete profile milestones to earn points.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCBE349),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/profile/points');
            },
            child: Text(
              'Go to Rewards',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}



// ── Template Card ──────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final ResumeTemplate template;
  final String title;
  final String tag;
  final Color tagColor;
  final String description;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _TemplateCard({
    required this.template,
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.description,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Card body — uniform border
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Info column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Info button + selected indicator
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _InfoButton(
                              onTap: onInfoTap,
                              accentColor: accentColor,
                            ),
                            const Spacer(),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: Color(0xFF07060F),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Tag pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: tagColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Left accent bar — separate overlay
          Positioned(
            top: 0, bottom: 0, left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isSelected ? 3.0 : 0.0,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Button with 5-Second Highlight Animation ────────────

class _InfoButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color accentColor;

  const _InfoButton({
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<_InfoButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wait 5 seconds to trigger highlighting
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _isHighlighted = true;
      });
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glowVal = _glowAnimation.value;
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHighlighted
                  ? widget.accentColor.withValues(alpha: 0.15 + (glowVal * 0.15))
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: _isHighlighted
                    ? widget.accentColor.withValues(alpha: 0.3 + (glowVal * 0.5))
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: _isHighlighted
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.25 * glowVal),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: _isHighlighted ? widget.accentColor : Colors.white60,
            ),
          );
        },
      ),
    );
  }
}

// ── Template Preview Dialog ─────────────────────────────────

class _TemplatePreviewDialog extends StatelessWidget {
  final String title;
  final String imagePath;

  const _TemplatePreviewDialog({
    required this.title,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0E17).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TEMPLATE PREVIEW',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),

              // Image Viewer
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      maxScale: 3.0,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, err, stack) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                'Preview not available',
                                style: GoogleFonts.outfit(color: Colors.white30),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Footer info & close CTA
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Your resume will be generated in this format.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close Preview',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// ── Generate CTA ──────────────────────────────────────────

class _GenerateCTA extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback? onTap;

  const _GenerateCTA({required this.isGenerating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
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
            onTap: isGenerating ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: isGenerating
                    ? const Color(0xFFCBE349).withValues(alpha: 0.3)
                    : const Color(0xFFCBE349),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isGenerating
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFCBE349)
                              .withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF07060F).withValues(alpha: isGenerating ? 0.4 : 1.0),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.generateNow,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF07060F).withValues(alpha: isGenerating ? 0.4 : 1.0),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
