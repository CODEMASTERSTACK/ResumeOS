import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart'; // for userProfileProvider
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile/settings'),
            icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 22),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD26EAB)),
        ),
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
                    color: const Color(0xFFFF5B5C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: Color(0xFFFF5B5C),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile Sync Incomplete',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t fetch your career data due to a temporary database sync issue.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => ref.invalidate(userProfileProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Retry Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text(
                'Profile not found',
                style: TextStyle(color: Colors.white70),
              ),
            );
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
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 108),
      children: [
        // Avatar + Name Header
        _ProfileHeader(user: user),
        const SizedBox(height: 24),

        // Personal Info Section
        _ProfileSection(
          title: 'Personal Info',
          icon: Icons.person_outline_rounded,
          child: _PersonalInfoContent(user: user),
        ),
        const SizedBox(height: 12),

        // Summary Section
        _ProfileSection(
          title: 'Professional Summary',
          icon: Icons.description_outlined,
          child: _SummaryContent(user: user),
        ),
        const SizedBox(height: 12),

        // Skills Section
        _ProfileSection(
          title: 'Skills',
          icon: Icons.bolt_outlined,
          child: _SkillsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Education Section
        _ProfileSection(
          title: 'Education',
          icon: Icons.school_outlined,
          child: _EducationContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Experience Section
        _ProfileSection(
          title: 'Experience',
          icon: Icons.work_outline_rounded,
          child: _ExperienceContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Projects Section
        _ProfileSection(
          title: 'Projects',
          icon: Icons.code_outlined,
          child: _ProjectsLinkContent(uid: uid),
        ),
        const SizedBox(height: 12),

        // Certifications Section
        _ProfileSection(
          title: 'Certifications',
          icon: Icons.verified_outlined,
          child: _CertificationsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Achievements Section
        _ProfileSection(
          title: 'Achievements',
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
    // Exact Profile image fallback matching dashboard/sidebar logic
    final profileImageUrl = user.profileImageUrl;
    ImageProvider? avatarImage;
    if (profileImageUrl.isNotEmpty) {
      avatarImage = NetworkImage(profileImageUrl);
    } else if (user.gender.toLowerCase() == 'female') {
      avatarImage = const AssetImage('assets/images/female.png');
    } else if (user.gender.toLowerCase() == 'male') {
      avatarImage = const AssetImage('assets/images/male.png');
    }

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 2.0,
            ),
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF723FFD).withValues(alpha: 0.15),
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name.isNotEmpty ? user.name : 'Your Name',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              if (user.currentRole.isNotEmpty)
                Text(
                  user.currentRole,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (user.email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/profile/edit/personal_info', extra: user.toJson()),
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
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
        color: Colors.white.withValues(alpha: 0.03), // Modern dark glassmorphic surface
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Icon(widget.icon, size: 16, color: const Color(0xFFCBE349)), // Neon green highlight
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Not set',
                  style: TextStyle(
                    color: hasValue ? Colors.white : Colors.white24,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
  @override
  Widget build(BuildContext context) {
    final hasSummary = widget.user.summary.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasSummary
              ? widget.user.summary
              : 'Add a professional summary to improve AI resume quality.',
          style: TextStyle(
            color: hasSummary ? Colors.white70 : Colors.white30,
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.push('/profile/summary-enhance'),
          icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFD26EAB)),
          label: const Text(
            'AI Enhance',
            style: TextStyle(
              color: Color(0xFFD26EAB),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 12),
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
                    style: TextStyle(
                      color: cat.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
                        style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, size: 18, color: Colors.white38),
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
              padding: const EdgeInsets.only(top: 8, left: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cat.color.withValues(alpha: 0.35), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 13, color: cat.color),
                          const SizedBox(width: 3),
                          Text(
                            'Add',
                            style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),
          Divider(height: 16, color: Colors.white.withValues(alpha: 0.04)),
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
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          name,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600),
        ),
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
              label: 'Add Education',
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
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Education', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$title"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5B5C)),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteEducation(uid, id);
              navigator.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF0C0B10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Education', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!has10th) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  icon: const Icon(Icons.school_outlined, color: Colors.white70),
                  label: const Text('Add 10th Standard', style: TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ctx.push('/profile/edit/education', extra: {'degree': '10th Standard'});
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (!has12th) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  icon: const Icon(Icons.school_rounded, color: Colors.white70),
                  label: const Text('Add 12th Standard', style: TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ctx.push('/profile/edit/education', extra: {'degree': '12th Standard'});
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                icon: const Icon(Icons.menu_book_rounded, color: Colors.white70),
                label: const Text('Add Higher Education', style: TextStyle(color: Colors.white70)),
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
              child: const Text('Close', style: TextStyle(color: Colors.white38)),
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
              label: 'Add Experience',
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
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Experience', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$title"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5B5C)),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteExperience(uid, id);
              navigator.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
              label: 'Add Certification',
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
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Certification', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$title"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5B5C)),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteCertification(uid, id);
              navigator.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
              label: 'Add Achievement',
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
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Achievement', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$title"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5B5C)),
            onPressed: () async {
              final navigator = Navigator.of(dCtx);
              await ref.read(profileRepositoryProvider).deleteAchievement(uid, id);
              navigator.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
        const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Manage your projects and research from the Projects tab',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Shared Sub-Widgets ─────────────────────────────────────

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
                  color: Color(0xFFCBE349), // Neon Lime Green
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (trailing.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    trailing,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B5C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF5B5C).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFFF5B5C)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.star_rounded, size: 14, color: Color(0xFFCBE349)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5B5C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF5B5C).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFFF5B5C)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
