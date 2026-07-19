import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
          headerTrailing: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showSummaryInfoDialog(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
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
  final Widget? headerTrailing;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.child,
    this.headerTrailing,
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
                  if (widget.headerTrailing != null) ...[
                    widget.headerTrailing!,
                    const SizedBox(width: 8),
                  ],
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: const Color(0xFF0052D4).withValues(alpha: 0.3),
              elevation: 4,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => context.push('/profile/summary-enhance'),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF1E5FF5), Color(0xFF6FB1FC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'AI Enhance Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
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

void _showSummaryInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _SummaryHelpDialog(),
  );
}

class _SummaryHelpDialog extends StatelessWidget {
  const _SummaryHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: _SummaryHelpDialogContent(),
    );
  }
}

class _SummaryHelpDialogContent extends StatefulWidget {
  const _SummaryHelpDialogContent({super.key});

  @override
  State<_SummaryHelpDialogContent> createState() => _SummaryHelpDialogContentState();
}

class _SummaryHelpDialogContentState extends State<_SummaryHelpDialogContent> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  // Animations for Slide 1
  late AnimationController _pulseController;

  // Animations for Slide 2
  int _selectedSkillIndex = -1;
  int _selectedProjectIndex = -1;
  Timer? _slide2Timer;

  // Animations for Slide 3
  String _typedText = "";
  Timer? _slide3Timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startSlide2Animation();
    _startSlide3Animation();
  }

  void _startSlide2Animation() {
    _slide2Timer?.cancel();
    _slide2Timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) return;
      setState(() {
        if (_selectedSkillIndex < 2) {
          _selectedSkillIndex++;
        } else if (_selectedProjectIndex < 0) {
          _selectedProjectIndex++;
        } else {
          // Reset
          _selectedSkillIndex = -1;
          _selectedProjectIndex = -1;
        }
      });
    });
  }

  void _startSlide3Animation() {
    const fullText = "Flutter Developer";
    int charIndex = 0;
    _slide3Timer?.cancel();
    _slide3Timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      setState(() {
        if (charIndex <= fullText.length) {
          _typedText = fullText.substring(0, charIndex);
          charIndex++;
        } else {
          if (charIndex > fullText.length + 5) {
            charIndex = 0;
            _typedText = "";
          } else {
            charIndex++;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _slide2Timer?.cancel();
    _slide3Timer?.cancel();
    super.dispose();
  }

  Widget _buildSlide1Visual() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1926),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 80, height: 8, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF723FFD).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 10, color: Color(0xFF723FFD)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(width: 180, height: 6, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 4),
                  Container(width: 140, height: 6, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.05);
                      final glow = _pulseController.value * 8.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: double.infinity,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF723FFD), Color(0xFF6FB1FC)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF723FFD).withValues(alpha: 0.4),
                                blurRadius: glow,
                                spreadRadius: glow / 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFCBE349)),
                              const SizedBox(width: 4),
                              Text(
                                'AI Enhance Summary',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide2Visual() {
    final skills = ['Flutter', 'Firebase', 'Dart'];
    final projects = ['E-Commerce App'];

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Highlight Key Experience',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(skills.length, (index) {
              final isSelected = index <= _selectedSkillIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF723FFD).withValues(alpha: 0.15) : const Color(0xFF1B1926),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF723FFD) : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFFCBE349)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      skills[index],
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(projects.length, (index) {
              final isSelected = index <= _selectedProjectIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF723FFD).withValues(alpha: 0.08) : const Color(0xFF1B1926),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF723FFD).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 14,
                      color: isSelected ? const Color(0xFFCBE349) : Colors.white30,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        projects[index],
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide3Visual() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1926),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Target Job Role',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                height: 32,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF723FFD).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Text(
                      _typedText,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      width: 1.5,
                      height: 14,
                      color: const Color(0xFFCBE349),
                      margin: const EdgeInsets.only(left: 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF723FFD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Generate summary',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide4Visual() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'ATS-Optimized Result',
                style: GoogleFonts.outfit(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1926),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10.5, height: 1.35),
                  children: [
                    const TextSpan(text: 'Results-driven '),
                    TextSpan(
                      text: 'Flutter Developer',
                      style: GoogleFonts.outfit(color: const Color(0xFFCBE349), fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' with hands-on experience building '),
                    TextSpan(
                      text: 'E-Commerce Apps',
                      style: GoogleFonts.outfit(color: const Color(0xFF6FB1FC), fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' and native components. Skilled in '),
                    TextSpan(
                      text: 'Firebase Integration',
                      style: GoogleFonts.outfit(color: const Color(0xFF723FFD), fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' and cross-platform architecture to deliver beautiful, responsive UIs.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard({required String title, required Widget richText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFFCBE349), // Neon accent
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          richText,
        ],
      ),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return Column(
          key: const ValueKey(0),
          children: [
            _buildSlide1Visual(),
            const SizedBox(height: 16),
            _buildInstructionCard(
              title: "Step 1: Open AI Enhance",
              richText: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Go to your Profile screen, locate the Professional Summary section, and tap the Edit button '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 11, color: Colors.white),
                      ),
                    ),
                    const TextSpan(text: '. In the editing screen, tap the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF723FFD), Color(0xFF6FB1FC)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 8, color: Color(0xFFCBE349)),
                            const SizedBox(width: 3),
                            Text(
                              'AI Enhance',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const TextSpan(text: ' button to launch the AI wizard.'),
                  ],
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          children: [
            _buildSlide2Visual(),
            const SizedBox(height: 16),
            _buildInstructionCard(
              title: "Step 2: Select Highlights",
              richText: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Tick the key skills '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF723FFD).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF723FFD), width: 0.5),
                        ),
                        child: Text('Skill', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8)),
                      ),
                    ),
                    const TextSpan(text: ' and projects '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: const Icon(Icons.check_box_rounded, size: 14, color: Color(0xFFCBE349)),
                    ),
                    const TextSpan(text: ' that you want to showcase. The AI will weave these specific technical highlights and achievements directly into your customized bio.'),
                  ],
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          children: [
            _buildSlide3Visual(),
            const SizedBox(height: 16),
            _buildInstructionCard(
              title: "Step 3: Define Target Role",
              richText: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enter your desired target job role (e.g., '),
                    TextSpan(text: '"Flutter Developer"', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    const TextSpan(text: ') in the input field '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: const Icon(Icons.keyboard_alt_outlined, size: 14, color: Colors.white54),
                    ),
                    const TextSpan(text: '. This helps the AI optimize keywords to pass applicant tracking systems (ATS). Then tap '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF723FFD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Generate', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey(3),
          children: [
            _buildSlide4Visual(),
            const SizedBox(height: 16),
            _buildInstructionCard(
              title: "Step 4: Review & Save",
              richText: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Read the generated summary '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: const Icon(Icons.article_outlined, size: 14, color: Color(0xFFCBE349)),
                    ),
                    const TextSpan(text: '. You can make manual tweaks directly to the text. Once satisfied, tap the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF723FFD), Color(0xFF6FB1FC)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 8, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('Save Changes', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const TextSpan(text: ' button to save it to your profile.'),
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF723FFD).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF723FFD).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFCBE349),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AI Resume Guide',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step ${_currentPage + 1} of 4',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // PageView content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: 4,
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildPageContent(index),
                );
              },
            ),
          ),

          // Dots Indicator & Navigation buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFCBE349) : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                // Action Buttons row
                Row(
                  children: [
                    if (_currentPage > 0) ...[
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              foregroundColor: Colors.white70,
                            ),
                            child: Text(
                              'Back',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < 3) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: const Color(0xFF723FFD).withValues(alpha: 0.2),
                            elevation: 4,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF723FFD), Color(0xFF6FB1FC)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_currentPage == 3) ...[
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    _currentPage < 3 ? 'Next' : 'Got it',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
