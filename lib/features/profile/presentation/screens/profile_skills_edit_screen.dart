import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';

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

class ProfileSkillsEditScreen extends ConsumerStatefulWidget {
  const ProfileSkillsEditScreen({super.key});

  @override
  ConsumerState<ProfileSkillsEditScreen> createState() => _ProfileSkillsEditScreenState();
}

class _ProfileSkillsEditScreenState extends ConsumerState<ProfileSkillsEditScreen> {
  final _searchCtrl = TextEditingController();
  bool _showMore = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addManualSkill(String uid, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    // Check what category fits best, default to "Tools/Platforms"
    String category = 'Tools/Platforms';
    for (final entry in _kRecommendedSkills.entries) {
      if (entry.value.any((s) => s.toLowerCase() == cleanName.toLowerCase())) {
        category = entry.key;
        break;
      }
    }

    try {
      await ref.read(profileRepositoryProvider).addSkill(uid, cleanName, category);
      _searchCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added skill "$cleanName"!'), backgroundColor: AppColors.success, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding skill: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleRecommendationSkill(String uid, String name, String category, List<Map<String, dynamic>> mySkills) async {
    final possessed = mySkills.firstWhere(
      (s) => (s['name'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );

    try {
      final repo = ref.read(profileRepositoryProvider);
      if (possessed.isNotEmpty) {
        await repo.deleteSkill(uid, possessed['id'] as String);
      } else {
        await repo.addSkill(uid, name, category);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating skills: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Manage Skills',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: ref.read(profileRepositoryProvider).watchSkills(uid),
          builder: (context, snap) {
            final mySkills = snap.data ?? [];
            final ownedNames = mySkills.map((s) => (s['name'] as String).toLowerCase()).toSet();

            return Column(
              children: [
                // Top Search & Input Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search or add a skill manually...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (val) => _addManualSkill(uid, val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _addManualSkill(uid, _searchCtrl.text),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),

                // Owned Skills Panel
                if (mySkills.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'My Skills (${mySkills.length})',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mySkills.map((s) {
                          final name = s['name'] as String;
                          final id = s['id'] as String;
                          final cat = s['category'] as String? ?? 'Tools/Platforms';
                          final color = _kCategoryColors[cat] ?? AppColors.accent;

                          return Container(
                            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: AppTypography.labelSmall),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => ref.read(profileRepositoryProvider).deleteSkill(uid, id),
                                  child: Icon(Icons.cancel_rounded, size: 14, color: color.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                // Recommended Skills grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested Skills for You',
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),

                        // Render Categories
                        ..._kRecommendedSkills.entries.map((catEntry) {
                          final category = catEntry.key;
                          final color = _kCategoryColors[category] ?? AppColors.accent;
                          final allRecommendations = catEntry.value;

                          // Show only 5 if not expanded, otherwise show all 20
                          final visibleRecommendations = _showMore ? allRecommendations : allRecommendations.take(5).toList();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category,
                                      style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: visibleRecommendations.map((name) {
                                    final owned = ownedNames.contains(name.toLowerCase());

                                    return GestureDetector(
                                      onTap: () => _toggleRecommendationSkill(uid, name, category, mySkills),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: owned ? color.withValues(alpha: 0.12) : AppColors.surface,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: owned ? color : AppColors.border,
                                            width: owned ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (owned) ...[
                                              Icon(Icons.check_rounded, size: 13, color: color),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              name,
                                              style: AppTypography.labelSmall.copyWith(
                                                color: owned ? color : AppColors.textSecondary,
                                                fontWeight: owned ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),

                        // "Show More / Show Less" Category toggling button
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _showMore = !_showMore),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            ),
                            icon: Icon(
                              _showMore ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            label: Text(
                              _showMore ? 'Show Less' : 'Show More (+15 Recommendations)',
                              style: AppTypography.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
