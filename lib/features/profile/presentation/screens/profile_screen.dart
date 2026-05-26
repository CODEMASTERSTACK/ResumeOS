import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart'; // for userProfileProvider
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../shared/providers/firebase_providers.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.navProfile),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded, size: 16,
                color: AppColors.textMuted),
            label: Text(AppStrings.signOut,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textMuted,
                )),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Sync Incomplete',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t fetch your career data due to a temporary database sync issue.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Retry Connection',
                  fullWidth: false,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(userProfileProvider),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Profile not found'));
          }
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final UserModel user;

  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user.uid;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar + Name
        _ProfileHeader(user: user),
        const SizedBox(height: 24),

        // Personal Info Section
        _ProfileSection(
          title: AppStrings.personalInfo,
          icon: Icons.person_outline_rounded,
          child: _PersonalInfoContent(user: user),
        ),
        const SizedBox(height: 12),

        // Summary
        _ProfileSection(
          title: AppStrings.professionalSummary,
          icon: Icons.description_outlined,
          child: _SummaryContent(user: user),
        ),
        const SizedBox(height: 12),

        // Skills
        _ProfileSection(
          title: AppStrings.skills,
          icon: Icons.bolt_outlined,
          child: _SkillsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Education
        _ProfileSection(
          title: AppStrings.education,
          icon: Icons.school_outlined,
          child: _EducationContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Experience
        _ProfileSection(
          title: AppStrings.experience,
          icon: Icons.work_outline_rounded,
          child: _ExperienceContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Projects
        _ProfileSection(
          title: AppStrings.projects,
          icon: Icons.code_outlined,
          child: _ProjectsLinkContent(uid: uid),
        ),
        const SizedBox(height: 12),

        // Certifications
        _ProfileSection(
          title: AppStrings.certifications,
          icon: Icons.verified_outlined,
          child: _CertificationsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Achievements
        _ProfileSection(
          title: AppStrings.achievements,
          icon: Icons.emoji_events_outlined,
          child: _AchievementsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Profile Header ─────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.accentContainer,
          backgroundImage: user.profileImageUrl.isNotEmpty
              ? NetworkImage(user.profileImageUrl)
              : null,
          child: user.profileImageUrl.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.accent,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name.isNotEmpty ? user.name : 'Your Name',
                style: AppTypography.headlineLarge,
              ),
              if (user.currentRole.isNotEmpty)
                Text(
                  user.currentRole,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              if (user.email.isNotEmpty)
                Text(user.email, style: AppTypography.bodySmall),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/profile/edit/personal_info', extra: user.toJson()),
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}

// ── Section Wrapper ────────────────────────────────────────

class _ProfileSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 16, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: AppTypography.headlineSmall),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Section Contents ───────────────────────────────────────

class _PersonalInfoContent extends StatelessWidget {
  final UserModel user;
  const _PersonalInfoContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Name', value: user.name, icon: Icons.person_outline),
        _InfoRow(label: 'Email', value: user.email, icon: Icons.email_outlined),
        _InfoRow(label: 'Phone', value: user.phone, icon: Icons.phone_outlined),
        _InfoRow(label: 'Location', value: user.location, icon: Icons.location_on_outlined),
        _InfoRow(label: 'GitHub', value: user.githubUrl, icon: Icons.code),
        _InfoRow(label: 'LinkedIn', value: user.linkedinUrl, icon: Icons.link),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _EditButton(
            label: 'Edit Personal Details',
            onTap: () => context.push('/profile/edit/personal_info', extra: user.toJson()),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: AppTypography.bodySmall.copyWith(
                    color: value.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryContent extends ConsumerStatefulWidget {
  final UserModel user;
  const _SummaryContent({required this.user});

  @override
  ConsumerState<_SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends ConsumerState<_SummaryContent> {
  bool _enhancing = false;

  Widget _buildStatusRow(String title, bool isFilled) {
    return Row(
      children: [
        Icon(
          isFilled ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isFilled ? AppColors.success : AppColors.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.user.summary.isNotEmpty
              ? widget.user.summary
              : 'Add a professional summary to improve AI resume quality.',
          style: AppTypography.bodyMedium.copyWith(
            color: widget.user.summary.isNotEmpty
                ? AppColors.textPrimary
                : AppColors.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        if (_enhancing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI is polishing your professional summary...',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: () async {
              final uid = widget.user.uid;
              final repo = ref.read(profileRepositoryProvider);

              setState(() => _enhancing = true);

              try {
                final education = await repo.watchEducation(uid).first;
                final skills = await repo.watchSkills(uid).first;
                final experience = await repo.watchExperience(uid).first;

                if (education.isEmpty || skills.isEmpty || experience.isEmpty) {
                  setState(() => _enhancing = false);
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                          SizedBox(width: 10),
                          Text('Enhance with AI'),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To generate a tailored, authentic career summary, please complete these essential profile sections first:',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            _buildStatusRow('Education', education.isNotEmpty),
                            const SizedBox(height: 8),
                            _buildStatusRow('Skills', skills.isNotEmpty),
                            const SizedBox(height: 8),
                            _buildStatusRow('Experience', experience.isNotEmpty),
                            const SizedBox(height: 16),
                            const Text(
                              'Having these details filled allows the AI to rely on real metrics and factual achievements, avoiding generic clichés.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final certifications = await repo.watchCertifications(uid).first;
                final achievements = await repo.watchAchievements(uid).first;

                final projectsSnap = await ref
                    .read(firestoreProvider)
                    .collection('users')
                    .doc(uid)
                    .collection('projects')
                    .get();
                final projects = projectsSnap.docs.map((d) => d.data()).toList();

                final skillsList = skills.map((s) => s['name'] as String).toList();

                final newSummary = await ref
                    .read(geminiServiceImplProvider)
                    .generateAuthenticSummary(
                      name: widget.user.name,
                      currentRole: widget.user.currentRole.isNotEmpty
                          ? widget.user.currentRole
                          : 'Software Professional',
                      skills: skillsList,
                      experience: experience,
                      education: education,
                      projects: projects,
                      certifications: certifications,
                      achievements: achievements,
                      currentSummary: widget.user.summary,
                    );

                if (newSummary.isNotEmpty) {
                  await repo.updateUser(uid, {'summary': newSummary});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Professional summary enhanced by AI successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to enhance summary: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _enhancing = false);
                }
              }
            },
            icon: const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.accent),
            label: Text(AppStrings.aiEnhance,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                )),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _EditButton(
            label: 'Edit Summary',
            onTap: () => context.push('/profile/edit/personal_info', extra: widget.user.toJson()),
          ),
        ),
      ],
    );
  }
}

// ── Skills ────────────────────────────────────────────────

/// The four fixed skill categories used throughout the app.
/// These exact strings are stored as the `category` field in Firestore
/// and are used by the PDF renderer to produce the labelled resume rows.
const List<_SkillCategory> _kSkillCategories = [
  _SkillCategory(
    name: 'Languages',
    icon: Icons.code_rounded,
    hint: 'e.g. C, C++, Python, Java, SQL',
    color: Color(0xFF6366F1), // indigo
  ),
  _SkillCategory(
    name: 'Tools/Platforms',
    icon: Icons.build_rounded,
    hint: 'e.g. Git & GitHub, Power BI, Tableau',
    color: Color(0xFF0EA5E9), // sky blue
  ),
  _SkillCategory(
    name: 'DevOps & Cloud',
    icon: Icons.cloud_rounded,
    hint: 'e.g. CI/CD (GitHub Actions), Azure',
    color: Color(0xFF10B981), // emerald
  ),
  _SkillCategory(
    name: 'Soft Skills',
    icon: Icons.psychology_rounded,
    hint: 'e.g. Problem-Solving, Team Player',
    color: Color(0xFFF59E0B), // amber
  ),
];

class _SkillCategory {
  final String name;
  final IconData icon;
  final String hint;
  final Color color;
  const _SkillCategory({
    required this.name,
    required this.icon,
    required this.hint,
    required this.color,
  });
}

class _SkillsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _SkillsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchSkills(uid),
      builder: (context, snap) {
        final allSkills = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _kSkillCategories.map((cat) {
            final catSkills = allSkills
                .where((s) => (s['category'] as String? ?? '') == cat.name)
                .toList();
            return _SkillCategoryRow(
              category: cat,
              skills: catSkills,
              uid: uid,
              ref: ref,
            );
          }).toList(),
        );
      },
    );
  }
}

class _SkillCategoryRow extends StatefulWidget {
  final _SkillCategory category;
  final List<Map<String, dynamic>> skills;
  final String uid;
  final WidgetRef ref;

  const _SkillCategoryRow({
    required this.category,
    required this.skills,
    required this.uid,
    required this.ref,
  });

  @override
  State<_SkillCategoryRow> createState() => _SkillCategoryRowState();
}

class _SkillCategoryRowState extends State<_SkillCategoryRow> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final skills = widget.skills;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(cat.icon, size: 13, color: cat.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat.name,
                    style: AppTypography.labelMedium.copyWith(
                      color: cat.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (skills.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${skills.length}',
                        style: AppTypography.caption.copyWith(color: cat.color),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more_rounded,
                        size: 18, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Chips + add button
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...skills.map((s) => _SkillChip(
                        name: s['name'] as String,
                        color: cat.color,
                        onTap: () => context.push('/profile/skills'),
                      )),
                  // "+ Add" chip
                  GestureDetector(
                    onTap: () => context.push('/profile/skills'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: cat.color.withValues(alpha: 0.35),
                            width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 13, color: cat.color),
                          const SizedBox(width: 3),
                          Text(
                            'Add',
                            style: AppTypography.labelSmall
                                .copyWith(color: cat.color),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 16, color: AppColors.border.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;

  const _SkillChip({
    required this.name,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(name, style: AppTypography.labelSmall),
      ),
    );
  }
}

// ── Education ─────────────────────────────────────────────

class _EducationContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _EducationContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchEducation(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((e) {
              final isSchool = e['degree'] == '10th Standard' || e['degree'] == '12th Standard';
              final title = isSchool ? (e['degree'] as String) : (e['institution'] as String? ?? '');
              final subtitle = isSchool
                  ? '${e['institution'] ?? ''}${e['board'] != null && e['board'].toString().isNotEmpty ? " (${e['board']})" : ""}'
                  : '${e['degree'] ?? ''}${e['field'] != null && e['field'].toString().isNotEmpty ? " - ${e['field']}" : ""}';

              final trailing = isSchool
                  ? '${e['percentage'] != null && e['percentage'].toString().isNotEmpty ? "${e['percentage']} | " : ""}${e['endYear'] ?? ''}'
                  : '${e['startYear'] != null && e['startYear'].toString().isNotEmpty ? "${e['startYear']} – " : ""}${e['endYear'] ?? ''}';

              return _EditableTimelineItem(
                title: title,
                subtitle: subtitle,
                trailing: trailing,
                onEdit: () => context.push('/profile/edit/education', extra: e),
                onDelete: () => _confirmDelete(context, uid, e['id'] as String, title),
              );
            }),
            _AddButton(
              label: AppStrings.addEducation,
              onTap: () => _showAddDialog(context, uid, ref, items),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext ctx, String uid, String id, String title) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Education'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteEducation(uid, id);
              navigator.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref, List<Map<String, dynamic>> items) {
    final has10th = items.any((e) => e['degree'] == '10th Standard');
    final has12th = items.any((e) => e['degree'] == '12th Standard');

    if (has10th && has12th) {
      ctx.push('/profile/edit/education', extra: {'degree': 'Higher Education'});
    } else {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Add Education'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!has10th) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Add 10th Standard'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ctx.push('/profile/edit/education', extra: {'degree': '10th Standard'});
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (!has12th) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.school_rounded),
                  label: const Text('Add 12th Standard'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ctx.push('/profile/edit/education', extra: {'degree': '12th Standard'});
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Add Higher Education'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  ctx.push('/profile/edit/education', extra: {'degree': 'Higher Education'});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}

// ── Experience ────────────────────────────────────────────

class _ExperienceContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _ExperienceContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchExperience(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((e) => _EditableTimelineItem(
                  title: e['role'] as String? ?? '',
                  subtitle: e['company'] as String? ?? '',
                  trailing: e['duration'] as String? ?? '',
                  onEdit: () => context.push('/profile/edit/experience', extra: e),
                  onDelete: () => _confirmDelete(context, uid, e['id'] as String, e['role'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addExperience,
              onTap: () => context.push('/profile/edit/experience'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext ctx, String uid, String id, String title) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Experience'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteExperience(uid, id);
              navigator.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Certifications ────────────────────────────────────────

class _CertificationsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _CertificationsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchCertifications(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((c) => _EditableTimelineItem(
                  title: c['title'] as String? ?? '',
                  subtitle: c['issuer'] as String? ?? '',
                  trailing: c['date'] as String? ?? '',
                  onEdit: () => context.push('/profile/edit/certifications', extra: c),
                  onDelete: () => _confirmDelete(context, uid, c['id'] as String, c['title'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addCertification,
              onTap: () => context.push('/profile/edit/certifications'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext ctx, String uid, String id, String title) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Certification'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteCertification(uid, id);
              navigator.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Achievements ──────────────────────────────────────────

class _AchievementsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _AchievementsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchAchievements(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((a) => _EditableAchievementItem(
                  title: a['title'] as String? ?? '',
                  onEdit: () => context.push('/profile/edit/achievements', extra: a),
                  onDelete: () => _confirmDelete(context, uid, a['id'] as String, a['title'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addAchievement,
              onTap: () => context.push('/profile/edit/achievements'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext ctx, String uid, String id, String title) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Achievement'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteAchievement(uid, id);
              navigator.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Projects Link ─────────────────────────────────────────

class _ProjectsLinkContent extends StatelessWidget {
  final String uid;
  const _ProjectsLinkContent({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          'Manage your projects from the Projects tab',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}

// ── Shared Sub-Widgets ─────────────────────────────────────

/// A timeline item with edit and delete icons in the trailing area.
class _EditableTimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EditableTimelineItem({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                Text(subtitle, style: AppTypography.bodySmall),
                if (trailing.isNotEmpty)
                  Text(trailing, style: AppTypography.caption),
              ],
            ),
          ),
          // Edit / Delete action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.accent),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 14, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An achievement row with edit and delete icons.
class _EditableAchievementItem extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EditableAchievementItem({
    required this.title,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: AppTypography.bodySmall),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accentContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.edit_outlined,
                  size: 14, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  size: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EditButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
      ),
    );
  }
}
