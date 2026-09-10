import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../shared/widgets/custom_toast.dart';

/// Curated industry skills catalog categorized for instant project attachment
const Map<String, List<String>> _kDefaultSkillsCatalog = {
  'Languages': [
    'Python', 'Dart', 'JavaScript', 'TypeScript', 'Java', 'C++', 'C#', 'SQL',
    'Go', 'Rust', 'Kotlin', 'Swift', 'PHP', 'Ruby', 'HTML/CSS', 'Shell Scripting',
  ],
  'Frontend & Mobile': [
    'Flutter', 'React', 'React Native', 'Android', 'iOS', 'Next.js', 'Vue.js',
    'Tailwind CSS', 'Redux', 'Jetpack Compose', 'SwiftUI', 'Material UI',
  ],
  'Backend & APIs': [
    'Node.js', 'Express.js', 'FastAPI', 'Django', 'Spring Boot', 'REST APIs',
    'GraphQL', 'gRPC', 'WebSockets', 'Microservices',
  ],
  'Database & Cloud': [
    'Firebase', 'Firestore', 'PostgreSQL', 'MongoDB', 'MySQL', 'Redis', 'SQLite',
    'AWS', 'Google Cloud (GCP)', 'Microsoft Azure', 'Supabase',
  ],
  'DevOps & Tools': [
    'Git', 'GitHub', 'Docker', 'Kubernetes', 'CI/CD (GitHub Actions)', 'Linux',
    'Postman', 'Figma', 'VS Code', 'Jira', 'Terraform',
  ],
  'AI & Data Science': [
    'Machine Learning', 'Gemini API', 'OpenAI', 'TensorFlow', 'PyTorch',
    'LangChain', 'Pandas', 'NumPy', 'Data Analysis', 'NLP',
  ],
  'Architecture & Testing': [
    'Clean Architecture', 'Bloc / Riverpod', 'Unit Testing', 'Widget Testing',
    'Design Patterns', 'System Design', 'Agile / Scrum',
  ],
  'Soft Skills': [
    'Problem Solving', 'Team Collaboration', 'Communication', 'Leadership',
    'Critical Thinking', 'Time Management', 'Mentoring',
  ],
};

String _detectCategory(String name) {
  final clean = name.trim().toLowerCase();

  if (clean.contains('flutter') ||
      clean.contains('react') ||
      clean.contains('android') ||
      clean.contains('ios') ||
      clean.contains('swiftui') ||
      clean.contains('compose') ||
      clean.contains('web') ||
      clean.contains('ui') ||
      clean.contains('html') ||
      clean.contains('css') ||
      clean.contains('tailwind')) {
    return 'Frontend & Mobile';
  }
  if (clean.contains('node') ||
      clean.contains('express') ||
      clean.contains('api') ||
      clean.contains('backend') ||
      clean.contains('fastapi') ||
      clean.contains('django') ||
      clean.contains('spring') ||
      clean.contains('graphql') ||
      clean.contains('grpc')) {
    return 'Backend & APIs';
  }
  if (clean.contains('sql') ||
      clean.contains('db') ||
      clean.contains('mongo') ||
      clean.contains('redis') ||
      clean.contains('postgres') ||
      clean.contains('firebase') ||
      clean.contains('firestore') ||
      clean.contains('supabase')) {
    return 'Database & Cloud';
  }
  if (clean.contains('cloud') ||
      clean.contains('aws') ||
      clean.contains('gcp') ||
      clean.contains('azure') ||
      clean.contains('docker') ||
      clean.contains('k8s') ||
      clean.contains('kubernetes') ||
      clean.contains('devops') ||
      clean.contains('git') ||
      clean.contains('linux') ||
      clean.contains('ci/cd')) {
    return 'DevOps & Tools';
  }
  if (clean.contains('ai') ||
      clean.contains('ml') ||
      clean.contains('model') ||
      clean.contains('gpt') ||
      clean.contains('gemini') ||
      clean.contains('tensor') ||
      clean.contains('pytorch') ||
      clean.contains('data') ||
      clean.contains('vision') ||
      clean.contains('nlp')) {
    return 'AI & Data Science';
  }
  if (clean.contains('clean') ||
      clean.contains('arch') ||
      clean.contains('pattern') ||
      clean.contains('test') ||
      clean.contains('tdd') ||
      clean.contains('agile') ||
      clean.contains('scrum')) {
    return 'Architecture & Testing';
  }
  if (clean.contains('lead') ||
      clean.contains('comm') ||
      clean.contains('team') ||
      clean.contains('problem') ||
      clean.contains('time') ||
      clean.contains('soft')) {
    return 'Soft Skills';
  }
  return 'Languages';
}

/// Shows the high-end, structured Link Skills bottom sheet.
Future<List<String>?> showLinkSkillsBottomSheet({
  required BuildContext context,
  required String uid,
  required String projectTitle,
  required List<String> initialSkills,
  String? projectId,
  ValueChanged<List<String>>? onSkillsUpdated,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.70),
    builder: (context) {
      return LinkSkillsBottomSheetContent(
        uid: uid,
        projectTitle: projectTitle,
        initialSkills: initialSkills,
        projectId: projectId,
        onSkillsUpdated: onSkillsUpdated,
      );
    },
  );
}

class LinkSkillsBottomSheetContent extends ConsumerStatefulWidget {
  final String uid;
  final String projectTitle;
  final List<String> initialSkills;
  final String? projectId;
  final ValueChanged<List<String>>? onSkillsUpdated;

  const LinkSkillsBottomSheetContent({
    super.key,
    required this.uid,
    required this.projectTitle,
    required this.initialSkills,
    this.projectId,
    this.onSkillsUpdated,
  });

  @override
  ConsumerState<LinkSkillsBottomSheetContent> createState() =>
      _LinkSkillsBottomSheetContentState();
}

class _LinkSkillsBottomSheetContentState
    extends ConsumerState<LinkSkillsBottomSheetContent> {
  late Set<String> _selectedSkills;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryTab = 'All';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSkills = Set<String>.from(widget.initialSkills);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('front') || lower.contains('ui') || lower.contains('web')) {
      return Icons.palette_outlined;
    } else if (lower.contains('back') || lower.contains('server') || lower.contains('api')) {
      return Icons.dns_rounded;
    } else if (lower.contains('lang') || lower.contains('code') || lower.contains('programming')) {
      return Icons.code_rounded;
    } else if (lower.contains('cloud') || lower.contains('devops') || lower.contains('infra')) {
      return Icons.cloud_outlined;
    } else if (lower.contains('data') || lower.contains('sql') || lower.contains('db')) {
      return Icons.storage_rounded;
    } else if (lower.contains('mobile') || lower.contains('app') || lower.contains('android') || lower.contains('ios')) {
      return Icons.smartphone_rounded;
    } else if (lower.contains('ai') || lower.contains('ml') || lower.contains('machine')) {
      return Icons.auto_awesome_rounded;
    } else if (lower.contains('tool') || lower.contains('platform')) {
      return Icons.construction_rounded;
    }
    return Icons.psychology_outlined;
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  void _toggleCategoryAll(List<String> categorySkills) {
    final allSelected = categorySkills.every(_selectedSkills.contains);
    setState(() {
      if (allSelected) {
        _selectedSkills.removeAll(categorySkills);
      } else {
        _selectedSkills.addAll(categorySkills);
      }
    });
  }

  Future<void> _addCustomSkill(String rawSkill) async {
    final skill = rawSkill.trim();
    if (skill.isEmpty) return;

    setState(() {
      _selectedSkills.add(skill);
      _searchController.clear();
      _searchQuery = '';
    });

    try {
      final category = _detectCategory(skill);
      await ref
          .read(profileRepositoryProvider)
          .addSkill(widget.uid, skill, category);
    } catch (_) {
      // Ignored if offline or already exists
    }

    if (mounted) {
      CustomToast.show(
        context,
        message: 'Linked "$skill" to project & saved to profile',
        type: ToastType.success,
      );
    }
  }

  Future<void> _saveLinks() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final updatedList = _selectedSkills.toList();

    try {
      if (widget.projectId != null) {
        await ref.read(projectRepositoryProvider).updateProject(
          widget.uid,
          widget.projectId!,
          {'linkedSkills': updatedList},
        );
      }

      if (widget.onSkillsUpdated != null) {
        widget.onSkillsUpdated!(updatedList);
      }

      // Background sync: also ensure newly selected skills are saved to user profile
      try {
        final profileRepo = ref.read(profileRepositoryProvider);
        final existingSkills = await profileRepo.watchSkills(widget.uid).first;
        final existingNames = existingSkills
            .map((s) => (s['name'] as String?)?.toLowerCase().trim())
            .whereType<String>()
            .toSet();

        for (final skill in updatedList) {
          if (!existingNames.contains(skill.toLowerCase().trim())) {
            final cat = _detectCategory(skill);
            await profileRepo.addSkill(widget.uid, skill, cat);
          }
        }
      } catch (_) {
        // Non-blocking sync
      }

      if (mounted) {
        Navigator.pop(context, updatedList);
        CustomToast.show(
          context,
          message:
              'Linked ${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'} to "${widget.projectTitle}"',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        CustomToast.show(
          context,
          message: 'Failed to update linked skills: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileRepo = ref.watch(profileRepositoryProvider);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;
    final topPadding = mediaQuery.padding.top;
    final maxAvailableHeight = mediaQuery.size.height - topPadding - 16;
    final sheetHeight = isKeyboardOpen
        ? (maxAvailableHeight - bottomInset).clamp(240.0, maxAvailableHeight)
        : mediaQuery.size.height * 0.84;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Drag Handle ──────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header Bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link Skills to Project',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.projectTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Selection count pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedSkills.isNotEmpty
                          ? AppColors.accent.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedSkills.isNotEmpty
                            ? AppColors.accent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedSkills.isNotEmpty
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 13,
                          color: _selectedSkills.isNotEmpty
                              ? AppColors.accent
                              : Colors.white38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_selectedSkills.length} Linked',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _selectedSkills.isNotEmpty
                                ? AppColors.accent
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white60,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0x1AFFFFFF)),

            // ── Search & Filter Bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? AppColors.accent.withValues(alpha: 0.40)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 19),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                color: Colors.white38, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search skills (e.g. Flutter, Docker, Python)...',
                    hintStyle: GoogleFonts.outfit(
                        color: Colors.white30, fontSize: 12.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // ── Stream Content ───────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: profileRepo.watchSkills(widget.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2.5),
                    );
                  }

                  final allSkills = snapshot.data ?? [];

                  // 1. Initialize with the curated skills catalog
                  final Map<String, Set<String>> mergedSkills = {};
                  for (final entry in _kDefaultSkillsCatalog.entries) {
                    mergedSkills[entry.key] = Set<String>.from(entry.value);
                  }

                  // 2. Add user's profile skills into appropriate categories
                  for (final s in allSkills) {
                    final cat = (s['category'] as String?)?.trim();
                    final name = (s['name'] as String?)?.trim() ?? '';
                    if (name.isNotEmpty) {
                      final category =
                          (cat != null && cat.isNotEmpty && cat != 'General')
                              ? cat
                              : _detectCategory(name);
                      mergedSkills
                          .putIfAbsent(category, () => <String>{})
                          .add(name);
                    }
                  }

                  // 3. Ensure already linked skills are included in catalog
                  for (final skill in _selectedSkills) {
                    final category = _detectCategory(skill);
                    mergedSkills
                        .putIfAbsent(category, () => <String>{})
                        .add(skill);
                  }

                  final categories = mergedSkills.keys.toList();

                  // Apply search and category filters
                  final filteredGroupedSkills = <String, List<String>>{};
                  final lowerQuery = _searchQuery.toLowerCase();
                  bool hasExactMatch = false;

                  for (final entry in mergedSkills.entries) {
                    final cat = entry.key;
                    if (_selectedCategoryTab != 'All' &&
                        cat != _selectedCategoryTab) {
                      continue;
                    }

                    final matchedSkills = entry.value.where((skill) {
                      if (skill.toLowerCase() == lowerQuery) {
                        hasExactMatch = true;
                      }
                      if (_searchQuery.isEmpty) return true;
                      return skill.toLowerCase().contains(lowerQuery) ||
                          cat.toLowerCase().contains(lowerQuery);
                    }).toList();

                    if (matchedSkills.isNotEmpty) {
                      // Sort: selected skills first, then alphabetical
                      matchedSkills.sort((a, b) {
                        final aSel = _selectedSkills.contains(a);
                        final bSel = _selectedSkills.contains(b);
                        if (aSel && !bSel) return -1;
                        if (!aSel && bSel) return 1;
                        return a.compareTo(b);
                      });
                      filteredGroupedSkills[cat] = matchedSkills;
                    }
                  }

                  // Total skills count
                  int totalSkillCount = 0;
                  for (final list in mergedSkills.values) {
                    totalSkillCount += list.length;
                  }

                  return Column(
                    children: [
                      // Category Filter Tabs
                      if (categories.isNotEmpty && _searchQuery.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          child: SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildCategoryPill(
                                  title: 'All',
                                  count: totalSkillCount,
                                  isSelected: _selectedCategoryTab == 'All',
                                  onTap: () => setState(
                                      () => _selectedCategoryTab = 'All'),
                                ),
                                ...categories.map((cat) {
                                  final count = mergedSkills[cat]?.length ?? 0;
                                  return _buildCategoryPill(
                                    title: cat,
                                    count: count,
                                    isSelected: _selectedCategoryTab == cat,
                                    onTap: () => setState(
                                        () => _selectedCategoryTab = cat),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),

                      // Quick hint or Add & Link Custom Skill Banner
                      if (_searchQuery.isNotEmpty && !hasExactMatch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: InkWell(
                            onTap: () => _addCustomSkill(_searchQuery),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded,
                                      size: 18, color: AppColors.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Add & Link: ',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '"$_searchQuery"',
                                            style: GoogleFonts.outfit(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Add',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (allSkills.isEmpty &&
                          _searchQuery.isEmpty &&
                          _selectedCategoryTab == 'All')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: AppColors.accent.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tap any skills below to link to this project (they will also save to your profile).',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 4),

                      // Skills List View
                      Expanded(
                        child: filteredGroupedSkills.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.search_off_rounded,
                                          size: 38, color: Colors.white24),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No predefined skills matching "$_searchQuery"',
                                        style: GoogleFonts.outfit(
                                            color: Colors.white70, fontSize: 14),
                                      ),
                                      const SizedBox(height: 14),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _addCustomSkill(_searchQuery),
                                        icon: const Icon(Icons.add_rounded,
                                            size: 16),
                                        label: Text('Add "$_searchQuery"'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _selectedCategoryTab = 'All';
                                          });
                                        },
                                        child: Text(
                                          'Reset Filters',
                                          style: GoogleFonts.outfit(
                                              color: Colors.white60,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 8, 20, 16),
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredGroupedSkills.length,
                                itemBuilder: (context, index) {
                                  final cat =
                                      filteredGroupedSkills.keys.elementAt(index);
                                  final skills = filteredGroupedSkills[cat]!;
                                  final selectedInCat = skills
                                      .where(_selectedSkills.contains)
                                      .length;
                                  final isAllSelected =
                                      selectedInCat == skills.length;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141220),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Category Header Row
                                          Row(
                                            children: [
                                              Icon(
                                                _getCategoryIcon(cat),
                                                size: 16,
                                                color: AppColors.accent,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                cat,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: selectedInCat > 0
                                                      ? AppColors.accent
                                                          .withValues(
                                                              alpha: 0.15)
                                                      : Colors.white
                                                          .withValues(
                                                              alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '$selectedInCat/${skills.length}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: selectedInCat > 0
                                                        ? AppColors.accent
                                                        : Colors.white38,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              // Select All / Deselect All Action
                                              GestureDetector(
                                                onTap: () =>
                                                    _toggleCategoryAll(skills),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 2),
                                                  child: Text(
                                                    isAllSelected
                                                        ? 'Deselect All'
                                                        : 'Select All',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isAllSelected
                                                          ? Colors.white38
                                                          : AppColors.accent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Skill Chips Wrap
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: skills.map((skill) {
                                              final isSelected =
                                                  _selectedSkills.contains(skill);
                                              return _buildSkillChip(
                                                  skill, isSelected);
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Bottom Action Footer ─────────────────────────────
            Container(
              padding:
                  EdgeInsets.fromLTRB(20, 12, 20, isKeyboardOpen ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0B12),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: !isKeyboardOpen,
                child: Row(
                  children: [
                    if (_selectedSkills.isNotEmpty) ...[
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedSkills.clear()),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveLinks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.link_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedSkills.isEmpty
                                        ? 'Save (0 Skills Linked)'
                                        : 'Save Connections (${_selectedSkills.length})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.accent : Colors.white60,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.accent : Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillChip(String skill, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSkill(skill),
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.accent.withValues(alpha: 0.15),
        highlightColor: AppColors.accent.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.add_rounded,
                  key: ValueKey<bool>(isSelected),
                  size: 14,
                  color: isSelected ? AppColors.accent : Colors.white38,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                skill,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
