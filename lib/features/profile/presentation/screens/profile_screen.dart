import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart'; // for userProfileProvider
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../shared/widgets/app_button.dart';


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
          onPressed: () => _showEditProfileDialog(context, user, ref),
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

  void _showEditProfileDialog(BuildContext ctx, UserModel user, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: user.name);
    final roleCtrl = TextEditingController(text: user.currentRole);
    final phoneCtrl = TextEditingController(text: user.phone);
    final locationCtrl = TextEditingController(text: user.location);
    final githubCtrl = TextEditingController(text: user.githubUrl);
    final linkedinCtrl = TextEditingController(text: user.linkedinUrl);
    final summaryCtrl = TextEditingController(text: user.summary);

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Current Role / Headline'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: githubCtrl,
                decoration: const InputDecoration(labelText: 'GitHub URL'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: linkedinCtrl,
                decoration: const InputDecoration(labelText: 'LinkedIn URL'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                decoration: const InputDecoration(labelText: 'Professional Summary'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .updateUser(user.uid, {
                'name': nameCtrl.text.trim(),
                'currentRole': roleCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'location': locationCtrl.text.trim(),
                'githubUrl': githubCtrl.text.trim(),
                'linkedinUrl': linkedinCtrl.text.trim(),
                'summary': summaryCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
      children: [
        _InfoRow(label: 'Name', value: user.name, icon: Icons.person_outline),
        _InfoRow(label: 'Email', value: user.email, icon: Icons.email_outlined),
        _InfoRow(label: 'Phone', value: user.phone, icon: Icons.phone_outlined),
        _InfoRow(label: 'Location', value: user.location, icon: Icons.location_on_outlined),
        _InfoRow(label: 'GitHub', value: user.githubUrl, icon: Icons.code),
        _InfoRow(label: 'LinkedIn', value: user.linkedinUrl, icon: Icons.link),
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

class _SummaryContent extends StatelessWidget {
  final UserModel user;
  const _SummaryContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.summary.isNotEmpty
              ? user.summary
              : 'Add a professional summary to improve AI resume quality.',
          style: AppTypography.bodyMedium.copyWith(
            color: user.summary.isNotEmpty
                ? AppColors.textPrimary
                : AppColors.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.auto_awesome_rounded,
              size: 14, color: AppColors.accent),
          label: Text(AppStrings.aiEnhance,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.accent,
              )),
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
                        onEdit: () => _showEditSkillDialog(
                            context, s['id'] as String, s['name'] as String),
                        onDelete: () => _confirmDelete(
                            context, s['id'] as String, s['name'] as String),
                      )),
                  // "+ Add" chip
                  GestureDetector(
                    onTap: () => _showAddDialog(context),
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

  void _showAddDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.category.icon,
                  size: 15, color: widget.category.color),
            ),
            const SizedBox(width: 10),
            Text('Add ${widget.category.name}'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.category.hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                final navigator = Navigator.of(dCtx);
                await widget.ref
                    .read(profileRepositoryProvider)
                    .addSkill(widget.uid, text, widget.category.name);
                navigator.pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditSkillDialog(
      BuildContext ctx, String skillId, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.edit_outlined,
                  size: 15, color: widget.category.color),
            ),
            const SizedBox(width: 10),
            const Text('Edit Skill'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Skill name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && text != currentName) {
                final navigator = Navigator.of(dCtx);
                await widget.ref
                    .read(profileRepositoryProvider)
                    .updateSkill(widget.uid, skillId, text);
                navigator.pop();
              } else {
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String skillId, String skillName) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remove Skill'),
        content: Text('Remove "$skillName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await widget.ref
                  .read(profileRepositoryProvider)
                  .deleteSkill(widget.uid, skillId);
              navigator.pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SkillChip({
    required this.name,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      onLongPress: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: AppTypography.labelSmall),
            const SizedBox(width: 5),
            Icon(Icons.more_horiz_rounded,
                size: 13, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        offset.dy + size.height + 4 + 100,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: color),
              const SizedBox(width: 10),
              const Text('Edit'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Delete',
                  style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') onEdit();
      if (value == 'delete') onDelete();
    });
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
                onEdit: () => isSchool
                    ? _showEditSchoolDialog(context, uid, e)
                    : _showEditHigherEducationDialog(context, uid, e),
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

  void _showEditSchoolDialog(BuildContext ctx, String uid, Map<String, dynamic> e) {
    final schoolCtrl = TextEditingController(text: e['institution'] as String? ?? '');
    final boardCtrl = TextEditingController(text: e['board'] as String? ?? '');
    final pctCtrl = TextEditingController(text: e['percentage'] as String? ?? '');
    final yearCtrl = TextEditingController(text: e['endYear'] as String? ?? '');
    final degree = e['degree'] as String;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit $degree Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: schoolCtrl, decoration: const InputDecoration(hintText: 'School Name')),
              const SizedBox(height: 8),
              TextField(controller: boardCtrl, decoration: const InputDecoration(hintText: 'Board (e.g. CBSE)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: pctCtrl, decoration: const InputDecoration(hintText: 'Percentage (%)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: yearCtrl, decoration: const InputDecoration(hintText: 'Passing Year'), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).updateEducation(uid, e['id'] as String, {
                'institution': schoolCtrl.text.trim(),
                'board': boardCtrl.text.trim(),
                'percentage': pctCtrl.text.trim(),
                'endYear': yearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditHigherEducationDialog(BuildContext ctx, String uid, Map<String, dynamic> e) {
    final institutionCtrl = TextEditingController(text: e['institution'] as String? ?? '');
    final degreeCtrl = TextEditingController(text: e['degree'] as String? ?? '');
    final fieldCtrl = TextEditingController(text: e['field'] as String? ?? '');
    final startYearCtrl = TextEditingController(text: e['startYear'] as String? ?? '');
    final endYearCtrl = TextEditingController(text: e['endYear'] as String? ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Higher Education'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: institutionCtrl, decoration: const InputDecoration(hintText: 'Institution / College')),
              const SizedBox(height: 8),
              TextField(controller: degreeCtrl, decoration: const InputDecoration(hintText: 'Degree (e.g. B.Tech)')),
              const SizedBox(height: 8),
              TextField(controller: fieldCtrl, decoration: const InputDecoration(hintText: 'Field of Study')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: startYearCtrl, decoration: const InputDecoration(hintText: 'Start Year'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: endYearCtrl, decoration: const InputDecoration(hintText: 'End Year'), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).updateEducation(uid, e['id'] as String, {
                'institution': institutionCtrl.text.trim(),
                'degree': degreeCtrl.text.trim(),
                'field': fieldCtrl.text.trim(),
                'startYear': startYearCtrl.text.trim(),
                'endYear': endYearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref, List<Map<String, dynamic>> items) {
    final has10th = items.any((e) => e['degree'] == '10th Standard');
    final has12th = items.any((e) => e['degree'] == '12th Standard');

    if (has10th && has12th) {
      _showAddHigherEducationDialog(ctx, uid, ref);
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
                    _showAddSchoolDialog(ctx, uid, ref, '10th Standard');
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
                    _showAddSchoolDialog(ctx, uid, ref, '12th Standard');
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Add Higher Education'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showAddHigherEducationDialog(ctx, uid, ref);
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

  void _showAddSchoolDialog(BuildContext ctx, String uid, WidgetRef ref, String degree) {
    final schoolCtrl = TextEditingController();
    final boardCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Add $degree Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: schoolCtrl, decoration: const InputDecoration(hintText: 'School Name')),
              const SizedBox(height: 8),
              TextField(controller: boardCtrl, decoration: const InputDecoration(hintText: 'Board (e.g. CBSE, State Board)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: pctCtrl, decoration: const InputDecoration(hintText: 'Percentage (%)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: yearCtrl, decoration: const InputDecoration(hintText: 'Passing Year'), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).addEducation(uid, {
                'degree': degree,
                'institution': schoolCtrl.text.trim(),
                'board': boardCtrl.text.trim(),
                'percentage': pctCtrl.text.trim(),
                'endYear': yearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddHigherEducationDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final institutionCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    final fieldCtrl = TextEditingController();
    final startYearCtrl = TextEditingController();
    final endYearCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Higher Education'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: institutionCtrl, decoration: const InputDecoration(hintText: 'Institution / College')),
              const SizedBox(height: 8),
              TextField(controller: degreeCtrl, decoration: const InputDecoration(hintText: 'Degree (e.g. B.Tech, MBA)')),
              const SizedBox(height: 8),
              TextField(controller: fieldCtrl, decoration: const InputDecoration(hintText: 'Field of Study (e.g. Computer Science)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: startYearCtrl, decoration: const InputDecoration(hintText: 'Start Year'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: endYearCtrl, decoration: const InputDecoration(hintText: 'End Year'), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).addEducation(uid, {
                'institution': institutionCtrl.text.trim(),
                'degree': degreeCtrl.text.trim(),
                'field': fieldCtrl.text.trim(),
                'startYear': startYearCtrl.text.trim(),
                'endYear': endYearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
                  onEdit: () => _showEditDialog(context, uid, e),
                  onDelete: () => _confirmDelete(context, uid, e['id'] as String, e['role'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addExperience,
              onTap: () => _showAddDialog(context, uid, ref),
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

  void _showEditDialog(BuildContext ctx, String uid, Map<String, dynamic> e) {
    final roleCtrl = TextEditingController(text: e['role'] as String? ?? '');
    final companyCtrl = TextEditingController(text: e['company'] as String? ?? '');
    final durationCtrl = TextEditingController(text: e['duration'] as String? ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: roleCtrl, decoration: const InputDecoration(hintText: 'Role / Job Title')),
            const SizedBox(height: 8),
            TextField(controller: companyCtrl, decoration: const InputDecoration(hintText: 'Company')),
            const SizedBox(height: 8),
            TextField(controller: durationCtrl, decoration: const InputDecoration(hintText: 'Duration (e.g. 2024 - Present)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).updateExperience(uid, e['id'] as String, {
                'role': roleCtrl.text.trim(),
                'company': companyCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final roleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: roleCtrl, decoration: const InputDecoration(hintText: 'Role / Job Title')),
            const SizedBox(height: 8),
            TextField(controller: companyCtrl, decoration: const InputDecoration(hintText: 'Company')),
            const SizedBox(height: 8),
            TextField(controller: durationCtrl, decoration: const InputDecoration(hintText: 'Duration (e.g. 2024 - Present)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).addExperience(uid, {
                'role': roleCtrl.text.trim(),
                'company': companyCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
                'startDate': DateTime.now(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
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
                  onEdit: () => _showEditDialog(context, uid, c),
                  onDelete: () => _confirmDelete(context, uid, c['id'] as String, c['title'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addCertification,
              onTap: () => _showAddDialog(context, uid, ref),
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

  void _showEditDialog(BuildContext ctx, String uid, Map<String, dynamic> c) {
    final titleCtrl = TextEditingController(text: c['title'] as String? ?? '');
    final issuerCtrl = TextEditingController(text: c['issuer'] as String? ?? '');
    final dateCtrl = TextEditingController(text: c['date'] as String? ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Certification Name')),
            const SizedBox(height: 8),
            TextField(controller: issuerCtrl, decoration: const InputDecoration(hintText: 'Issuer')),
            const SizedBox(height: 8),
            TextField(controller: dateCtrl, decoration: const InputDecoration(hintText: 'Date (e.g. May 2026)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).updateCertification(uid, c['id'] as String, {
                'title': titleCtrl.text.trim(),
                'issuer': issuerCtrl.text.trim(),
                'date': dateCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Certification Name')),
            const SizedBox(height: 8),
            TextField(controller: issuerCtrl, decoration: const InputDecoration(hintText: 'Issuer')),
            const SizedBox(height: 8),
            TextField(controller: dateCtrl, decoration: const InputDecoration(hintText: 'Date (e.g. May 2026)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).addCertification(uid, {
                'title': titleCtrl.text.trim(),
                'issuer': issuerCtrl.text.trim(),
                'date': dateCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
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
                  onEdit: () => _showEditDialog(context, uid, a),
                  onDelete: () => _confirmDelete(context, uid, a['id'] as String, a['title'] as String? ?? 'this entry'),
                )),
            _AddButton(
              label: AppStrings.addAchievement,
              onTap: () => _showAddDialog(context, uid, ref),
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

  void _showEditDialog(BuildContext ctx, String uid, Map<String, dynamic> a) {
    final titleCtrl = TextEditingController(text: a['title'] as String? ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Achievement'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'e.g. First place in Google Hackathon'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).updateAchievement(uid, a['id'] as String, {
                'title': titleCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final titleCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Achievement'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'e.g. First place in Google Hackathon'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).addAchievement(uid, {
                'title': titleCtrl.text.trim(),
              });
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
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
