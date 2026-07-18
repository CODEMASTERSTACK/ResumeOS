import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../shared/widgets/custom_toast.dart';

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

  List<Map<String, dynamic>> _localSkills = [];
  List<Map<String, dynamic>> _initialSkills = [];
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        _fetchInitialSkills(uid);
      }
    });
  }

  Future<void> _fetchInitialSkills(String uid) async {
    try {
      final skills = await ref.read(profileRepositoryProvider).watchSkills(uid).first;
      setState(() {
        _initialSkills = skills.map((s) => Map<String, dynamic>.from(s)).toList();
        _localSkills = skills.map((s) => Map<String, dynamic>.from(s)).toList();
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error loading skills: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addManualSkill(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    if (_localSkills.any((s) => (s['name'] as String).toLowerCase() == cleanName.toLowerCase())) {
      CustomToast.show(
        context,
        message: 'Skill already added!',
        type: ToastType.info,
      );
      return;
    }

    // Check what category fits best, default to "Tools/Platforms"
    String category = 'Tools/Platforms';
    for (final entry in _kRecommendedSkills.entries) {
      if (entry.value.any((s) => s.toLowerCase() == cleanName.toLowerCase())) {
        category = entry.key;
        break;
      }
    }

    setState(() {
      _localSkills.add({
        'name': cleanName,
        'category': category,
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}_$cleanName',
      });
      _searchCtrl.clear();
    });
  }

  void _toggleRecommendationSkill(String name, String category) {
    final existingIndex = _localSkills.indexWhere(
      (s) => (s['name'] as String).toLowerCase() == name.toLowerCase(),
    );

    setState(() {
      if (existingIndex != -1) {
        _localSkills.removeAt(existingIndex);
      } else {
        _localSkills.add({
          'name': name,
          'category': category,
          'id': 'temp_${DateTime.now().millisecondsSinceEpoch}_$name',
        });
      }
    });
  }

  Future<void> _saveSkills(String uid) async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);

      final localNames = _localSkills.map((s) => (s['name'] as String).toLowerCase()).toSet();
      final toDelete = _initialSkills.where((s) => !localNames.contains((s['name'] as String).toLowerCase())).toList();

      final initialNames = _initialSkills.map((s) => (s['name'] as String).toLowerCase()).toSet();
      final toAdd = _localSkills.where((s) => !initialNames.contains((s['name'] as String).toLowerCase())).toList();

      for (final skill in toDelete) {
        final id = skill['id'] as String;
        await repo.deleteSkill(uid, id);
      }

      for (final skill in toAdd) {
        final name = skill['name'] as String;
        final category = skill['category'] as String? ?? 'Tools/Platforms';
        await repo.addSkill(uid, name, category);
      }

      if (mounted) {
        CustomToast.show(
          context,
          message: 'Skills updated successfully!',
          type: ToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error saving skills: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF07060F),
        body: Center(child: Text('Please log in', style: TextStyle(color: Colors.white70))),
      );
    }

    final ownedNames = _localSkills.map((s) => (s['name'] as String).toLowerCase()).toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Skills',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: !_isInitialized
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD26EAB),
                ),
              )
            : Column(
                children: [
                  // Top Search & Input Box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search or add a skill manually...',
                              hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.white38),
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
                            onSubmitted: (val) => _addManualSkill(val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _addManualSkill(_searchCtrl.text),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD26EAB),
                                  Color(0xFFE88BB4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Owned Skills Panel
                  if (_localSkills.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'My Skills',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _localSkills.map((s) {
                            final name = s['name'] as String;
                            final id = s['id'] as String;
                            final cat = s['category'] as String? ?? 'Tools/Platforms';
                            final color = _kCategoryColors[cat] ?? const Color(0xFFD26EAB);

                            return Container(
                              padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _localSkills.removeWhere((item) => item['id'] == id);
                                      });
                                    },
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

                  // Recommended Skills Grid
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Suggested Skills for You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Render Categories
                          ..._kRecommendedSkills.entries.map((catEntry) {
                            final category = catEntry.key;
                            final color = _kCategoryColors[category] ?? const Color(0xFFCBE349);
                            final allRecommendations = catEntry.value;

                            // Show only 5 if not expanded, otherwise show all
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
                                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: visibleRecommendations.map((name) {
                                      final owned = ownedNames.contains(name.toLowerCase());

                                      return GestureDetector(
                                        onTap: () => _toggleRecommendationSkill(name, category),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: owned ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: owned ? color : Colors.white.withValues(alpha: 0.08),
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
                                                style: TextStyle(
                                                  color: owned ? color : Colors.white70,
                                                  fontSize: 11,
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
                                side: const BorderSide(color: Color(0xFFD26EAB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              ),
                              icon: Icon(
                                _showMore ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 16,
                                color: const Color(0xFFD26EAB),
                              ),
                              label: Text(
                                _showMore ? 'Show Less' : 'Show More Recommendations',
                                style: const TextStyle(color: Color(0xFFD26EAB), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Save Changes button at the bottom
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: const Color(0xFF0052D4).withValues(alpha: 0.4),
                          elevation: 6,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _isSaving ? null : () => _saveSkills(uid),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0052D4), Color(0xFF1E5FF5), Color(0xFF6FB1FC)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Save Changes',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
