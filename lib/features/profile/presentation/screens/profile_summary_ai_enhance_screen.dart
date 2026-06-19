import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart'; // for userProfileProvider
import '../../../../services/ai/gemini_service.dart';

class ProfileSummaryAiEnhanceScreen extends ConsumerStatefulWidget {
  const ProfileSummaryAiEnhanceScreen({super.key});

  @override
  ConsumerState<ProfileSummaryAiEnhanceScreen> createState() => _ProfileSummaryAiEnhanceScreenState();
}

class _ProfileSummaryAiEnhanceScreenState extends ConsumerState<ProfileSummaryAiEnhanceScreen> {
  bool _loadingData = true;
  bool _generating = false;
  bool _saving = false;
  int _currentStep = 0; // 0 = Cosmic Bubbles, 1 = Minimalist Projects, 2 = AI Composing & Review

  // Actual section data loaded from Firestore
  List<Map<String, dynamic>> _education = [];
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _experience = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _achievements = [];
  List<ProjectModel> _projects = [];

  // Toggle selection states
  bool _useEducation = true;
  bool _useSkills = true;
  bool _useExperience = true;
  bool _useCertifications = true;
  bool _useAchievements = true;
  bool _useProjects = true;

  // Selected project IDs for context
  final Set<String> _selectedProjectIds = {};

  // Controllers
  late TextEditingController _summaryCtrl;

  // Typewriter loading parameters
  String _typewriterText = '';
  bool _caretVisible = true;
  Timer? _typewriterTimer;
  Timer? _caretTimer;
  int _typewriterPhaseIndex = 0;
  final List<String> _typewriterPhases = [
    'Parsing your education landmarks...',
    'Analyzing key skills & proficiencies...',
    'Extracting high-impact work experience...',
    'Verifying verified credentials & certifications...',
    'Ingesting project technical contributions...',
    'Synthesizing authentic work philosophy...',
    'Applying strict professional word constraints...',
    'Running the "read out loud / coffee test"...',
    'Polishing your final premium AI summary...'
  ];

  // ChatGPT/Gemini Stream parameters
  String _streamingDraftText = '';
  String _rawGeneratedSummary = '';
  bool _isStreamingActive = false;
  bool _isEditingDraft = false;
  Timer? _wordStreamTimer;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _typewriterTimer?.cancel();
    _caretTimer?.cancel();
    _wordStreamTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _loadingData = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      final projRepo = ref.read(projectRepositoryProvider);

      // Fetch all collections in parallel
      final results = await Future.wait([
        repo.watchEducation(uid).first,
        repo.watchSkills(uid).first,
        repo.watchExperience(uid).first,
        repo.watchCertifications(uid).first,
        repo.watchAchievements(uid).first,
        projRepo.watchProjects(uid).first,
      ]);

      _education = results[0] as List<Map<String, dynamic>>;
      _skills = results[1] as List<Map<String, dynamic>>;
      _experience = results[2] as List<Map<String, dynamic>>;
      _certifications = results[3] as List<Map<String, dynamic>>;
      _achievements = results[4] as List<Map<String, dynamic>>;
      _projects = results[5] as List<ProjectModel>;

      // Default disable sections that have no data
      if (_education.isEmpty) _useEducation = false;
      if (_skills.isEmpty) _useSkills = false;
      if (_experience.isEmpty) _useExperience = false;
      if (_certifications.isEmpty) _useCertifications = false;
      if (_achievements.isEmpty) _useAchievements = false;
      if (_projects.isEmpty) {
        _useProjects = false;
      } else {
        // By default select all active projects
        for (final p in _projects) {
          _selectedProjectIds.add(p.id);
        }
      }

      // Pre-fill existing summary if available
      final userProfile = await repo.getUser(uid);
      if (userProfile != null && userProfile.summary.isNotEmpty) {
        _summaryCtrl.text = userProfile.summary;
      }

      setState(() => _loadingData = false);
    } catch (e) {
      setState(() => _loadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile context: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // Starts the interactive caret typewriter loading simulation
  void _startTypewriterAnimation() {
    _typewriterPhaseIndex = 0;
    _typewriterText = '';
    _typewriterTimer?.cancel();
    _caretTimer?.cancel();

    // Blinking caret effect (every 450ms)
    _caretTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (mounted) {
        setState(() {
          _caretVisible = !_caretVisible;
        });
      }
    });

    // Animate phase typing lines
    _typewriterText = _typewriterPhases[_typewriterPhaseIndex];
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 2600), (timer) {
      if (mounted) {
        setState(() {
          _typewriterPhaseIndex = (_typewriterPhaseIndex + 1) % _typewriterPhases.length;
          _typewriterText = _typewriterPhases[_typewriterPhaseIndex];
        });
      }
    });
  }

  void _stopTypewriterAnimation() {
    _typewriterTimer?.cancel();
    _caretTimer?.cancel();
  }

  Future<void> _generateSummary() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    // Check if at least one section with data is selected
    final hasSelectedData = (_useEducation && _education.isNotEmpty) ||
        (_useSkills && _skills.isNotEmpty) ||
        (_useExperience && _experience.isNotEmpty) ||
        (_useCertifications && _certifications.isNotEmpty) ||
        (_useAchievements && _achievements.isNotEmpty) ||
        (_useProjects && _selectedProjectIds.isNotEmpty);

    if (!hasSelectedData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one section with data to generate summary context.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Move to step 2 (AI Typing Phase)
    setState(() {
      _currentStep = 2;
      _generating = true;
    });
    _startTypewriterAnimation();

    try {
      final repo = ref.read(profileRepositoryProvider);
      final userProfile = await repo.getUser(uid);
      final rawName = userProfile?.name ?? '';
      final name = rawName.trim().isNotEmpty ? rawName : 'Your Name';
      final rawRole = userProfile?.currentRole ?? '';
      final currentRole = rawRole.trim().isNotEmpty ? rawRole : 'Software Professional';

      // Filter context based on user toggles
      final skillsList = _useSkills ? _skills.map((s) => s['name'] as String).toList() : <String>[];
      final expList = _useExperience ? _experience : <Map<String, dynamic>>[];
      final eduList = _useEducation ? _education : <Map<String, dynamic>>[];
      final certList = _useCertifications ? _certifications : <Map<String, dynamic>>[];
      final achList = _useAchievements ? _achievements : <Map<String, dynamic>>[];

      // Filter projects based on individual user project box selections
      final projList = <Map<String, dynamic>>[];
      if (_useProjects) {
        for (final p in _projects) {
          if (_selectedProjectIds.contains(p.id)) {
            projList.add(p.toJson());
          }
        }
      }

      final summary = await ref.read(geminiServiceImplProvider).generateAuthenticSummary(
        name: name,
        currentRole: currentRole,
        skills: skillsList,
        experience: expList,
        education: eduList,
        projects: projList,
        certifications: certList,
        achievements: achList,
        currentSummary: _summaryCtrl.text,
      );

      if (summary.isNotEmpty) {
        _rawGeneratedSummary = summary;
        _startWordStream(summary);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: AppColors.error),
        );
      }
      // Return to selection if failed
      setState(() => _currentStep = 0);
    } finally {
      _stopTypewriterAnimation();
      setState(() => _generating = false);
    }
  }

  void _startWordStream(String fullText) {
    _stopWordStream();
    final words = fullText.split(' ');
    int currentWordIdx = 0;
    _summaryCtrl.text = '';
    
    setState(() {
      _streamingDraftText = '';
      _isStreamingActive = true;
      _isEditingDraft = false;
    });

    _wordStreamTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (currentWordIdx < words.length) {
        if (mounted) {
          setState(() {
            _streamingDraftText += (currentWordIdx == 0 ? '' : ' ') + words[currentWordIdx];
            _summaryCtrl.text = _streamingDraftText;
            currentWordIdx++;
          });
        }
      } else {
        _stopWordStream();
      }
    });
  }

  void _revealTextInstantly(String fullText) {
    _stopWordStream();
    setState(() {
      _streamingDraftText = fullText;
      _summaryCtrl.text = fullText;
      _isStreamingActive = false;
    });
  }

  void _stopWordStream() {
    _wordStreamTimer?.cancel();
    setState(() {
      _isStreamingActive = false;
    });
  }

  Future<void> _saveAndApply() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    if (_summaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary cannot be empty!'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateUser(uid, {'summary': _summaryCtrl.text.trim()});

      // Force refresh profile provider so main screen shows it reactively
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enhanced professional summary applied!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save summary: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  // Renders the glowing glassy Bottom Drawer to display actual entries (Image 2 style)
  void _showSectionDetailsDrawer(String sectionKey, String title, IconData icon, Color neonColor, List<Map<String, dynamic>> items, bool isEnabled, ValueChanged<bool> onToggle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDrawerState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xEC090714),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(color: neonColor.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: neonColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drawer Handle
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Top Circle Glowing Icon Header
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: neonColor.withValues(alpha: 0.12),
                        border: Border.all(color: neonColor, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: neonColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 36, color: neonColor),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Toggle Context Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Include in Summary context',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Switch.adaptive(
                            value: isEnabled,
                            activeColor: neonColor,
                            onChanged: (val) {
                              setDrawerState(() => isEnabled = val);
                              setState(() => onToggle(val));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Stored Section Records',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Record List Container
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                      child: items.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'No entries saved in profile. Add data to influence summary.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white30, fontSize: 12),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                String primary = '';
                                String secondary = '';

                                if (sectionKey == 'education') {
                                  primary = item['degree'] ?? 'Degree';
                                  secondary = '${item['institution'] ?? ''} • ${item['endYear'] ?? ''}';
                                } else if (sectionKey == 'skills') {
                                  primary = item['name'] ?? 'Skill';
                                  secondary = item['level'] ?? 'Expert';
                                } else if (sectionKey == 'experience') {
                                  primary = item['role'] ?? 'Job Title';
                                  secondary = '${item['company'] ?? ''} • ${item['duration'] ?? ''}';
                                } else if (sectionKey == 'certifications') {
                                  primary = item['title'] ?? 'Certificate';
                                  secondary = item['issuer'] ?? '';
                                } else if (sectionKey == 'achievements') {
                                  primary = item['title'] ?? 'Achievement';
                                  secondary = item['description'] ?? 'Award Details';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle_rounded, size: 8, color: neonColor),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              primary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              secondary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Back button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Dismiss View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Cosmic Bubble generator widget helper (Step 1)
  Widget _buildCosmicBubble({
    required String sectionKey,
    required String title,
    required IconData icon,
    required Color neonColor,
    required int count,
    required bool isSelected,
    required ValueChanged<bool> onToggle,
  }) {
    // Dynamic Size based on list entries count:
    // clamped between 42px (0 count) to 65px (10+ counts)
    final double radius = (42.0 + count * 2.5).clamp(42.0, 65.0);
    final hasData = count > 0;

    return FloatingBubbleWrapper(
      duration: Duration(milliseconds: 2200 + (sectionKey.hashCode % 800)),
      offset: 5.0 + (sectionKey.hashCode % 3.0),
      child: GestureDetector(
        onTap: () {
          // Open details bottom drawer
          _showSectionDetailsDrawer(sectionKey, title, icon, neonColor, 
            sectionKey == 'education' ? _education : 
            sectionKey == 'skills' ? _skills : 
            sectionKey == 'experience' ? _experience : 
            sectionKey == 'certifications' ? _certifications : _achievements,
            isSelected,
            onToggle
          );
        },
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected && hasData 
                ? neonColor.withValues(alpha: 0.16) 
                : const Color(0xFF0F0C20).withValues(alpha: 0.5),
            border: Border.all(
              color: isSelected && hasData ? neonColor : Colors.white12,
              width: isSelected && hasData ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected && hasData 
                    ? neonColor.withValues(alpha: 0.35) 
                    : Colors.black26,
                blurRadius: isSelected && hasData ? 20 : 6,
                spreadRadius: isSelected && hasData ? 3 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: (radius * 0.45).clamp(18.0, 32.0),
                        color: isSelected && hasData ? neonColor : Colors.white24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected && hasData ? Colors.white : Colors.white30,
                          fontWeight: FontWeight.bold,
                          fontSize: (radius * 0.22).clamp(8.5, 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Layout screen components for Step 1: Cosmic Floating Bubbles
  Widget _buildStep1BubbleView() {
    return Column(
      children: [
        // Immersive Description
        Text(
          'Step 1 of 2: Influence Focus'.toUpperCase(),
          style: GoogleFonts.outfit(
            color: const Color(0xFF6FB1FC),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure Influence Areas',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Dynamically sized bubbles cluster based on real records. Tap bubbles to view contents, checklist details, or influence configurations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Cosmic Layout Area
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 340,
              child: Stack(
                children: [
                  // Overlapping Cosmic Bubbles centered
                  // Bubble 1: Skills (Royal Indigo) - Middle-Right
                  Positioned(
                    left: 160,
                    top: 90,
                    child: _buildCosmicBubble(
                      sectionKey: 'skills',
                      title: 'Skills',
                      icon: Icons.bolt_outlined,
                      neonColor: const Color(0xFFA29BFE),
                      count: _skills.length,
                      isSelected: _useSkills,
                      onToggle: (val) => setState(() => _useSkills = val),
                    ),
                  ),

                  // Bubble 2: Experience (Emerald Green) - Middle-Left
                  Positioned(
                    left: 10,
                    top: 100,
                    child: _buildCosmicBubble(
                      sectionKey: 'experience',
                      title: 'Experience',
                      icon: Icons.work_outline_rounded,
                      neonColor: const Color(0xFF2ECC71),
                      count: _experience.length,
                      isSelected: _useExperience,
                      onToggle: (val) => setState(() => _useExperience = val),
                    ),
                  ),

                  // Bubble 3: Education (Bright Amber) - Top-Center
                  Positioned(
                    left: 85,
                    top: 10,
                    child: _buildCosmicBubble(
                      sectionKey: 'education',
                      title: 'Education',
                      icon: Icons.school_outlined,
                      neonColor: const Color(0xFFFF9F43),
                      count: _education.length,
                      isSelected: _useEducation,
                      onToggle: (val) => setState(() => _useEducation = val),
                    ),
                  ),

                  // Bubble 4: Certifications (Cyan) - Bottom-Left
                  Positioned(
                    left: 20,
                    top: 195,
                    child: _buildCosmicBubble(
                      sectionKey: 'certifications',
                      title: 'Certifications',
                      icon: Icons.verified_outlined,
                      neonColor: const Color(0xFF0DECFA),
                      count: _certifications.length,
                      isSelected: _useCertifications,
                      onToggle: (val) => setState(() => _useCertifications = val),
                    ),
                  ),

                  // Bubble 5: Achievements (Magenta) - Bottom-Right
                  Positioned(
                    left: 150,
                    top: 200,
                    child: _buildCosmicBubble(
                      sectionKey: 'achievements',
                      title: 'Achievements',
                      icon: Icons.emoji_events_outlined,
                      neonColor: const Color(0xFFEF5777),
                      count: _achievements.length,
                      isSelected: _useAchievements,
                      onToggle: (val) => setState(() => _useAchievements = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Navigation Footer Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: const Color(0xFF0052D4).withValues(alpha: 0.4),
                elevation: 6,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                if (_projects.isNotEmpty) {
                  setState(() => _currentStep = 1);
                } else {
                  _generateSummary();
                }
              },
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _projects.isNotEmpty ? 'Proceed to Projects' : 'Generate AI Summary',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Layout screen components for Step 2: Minimalist Projects Selector
  Widget _buildStep2ProjectsView() {
    return Column(
      children: [
        Text(
          'Step 2 of 2: Technical Focus'.toUpperCase(),
          style: GoogleFonts.outfit(
            color: const Color(0xFF6FB1FC),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select Profile Projects',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Check the specific items below you want the AI to parse as engineering contributions in your summary paragraph.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Minimalist Selector Options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROJECT PORTFOLIO (${_projects.length})',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedProjectIds.length == _projects.length) {
                      _selectedProjectIds.clear();
                      _useProjects = false;
                    } else {
                      _selectedProjectIds.clear();
                      for (final p in _projects) {
                        _selectedProjectIds.add(p.id);
                      }
                      _useProjects = true;
                    }
                  });
                },
                child: Text(
                  _selectedProjectIds.length == _projects.length ? 'DESELECT ALL' : 'SELECT ALL',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF6FB1FC),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List Container
        Expanded(
          child: _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      const Text('No Github or custom projects found.', style: TextStyle(color: Colors.white30, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final p = _projects[index];
                    final isSelected = _selectedProjectIds.contains(p.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF1E5FF5).withValues(alpha: 0.08) 
                            : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF6FB1FC).withValues(alpha: 0.35) 
                              : Colors.white.withValues(alpha: 0.05),
                          width: 1.2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedProjectIds.remove(p.id);
                              if (_selectedProjectIds.isEmpty) _useProjects = false;
                            } else {
                              _selectedProjectIds.add(p.id);
                              _useProjects = true;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sleek Check Indicator
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.accent : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? AppColors.accent : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 14),

                              // Text Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      p.description.isNotEmpty ? p.description : 'No description provided.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    if (p.technologies.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: p.technologies.take(4).map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? AppColors.accent.withValues(alpha: 0.12) 
                                                : Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? AppColors.accent : Colors.white54,
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Navigation controls footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: const Color(0xFF0052D4).withValues(alpha: 0.4),
                elevation: 6,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _generateSummary,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next: Generate AI Summary',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Layout screen components for Step 3: Typewriter Animation & Paragraph Review
  Widget _buildStep3ComposingAndReview() {
    if (_generating) {
      // Typewriter Composing Screen UI
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating Spinning AI Portal
              Container(
                width: 90,
                height: 90,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.05),
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 40),

              // Active glowing status label
              const Text(
                'AUTHENTIC AI COMPOSING',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),

              // Custom Typewriter pulsing caret block
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _typewriterText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: _caretVisible ? 1.0 : 0.0,
                      child: const Text(
                        '|',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Structuring custom professional context... This takes under 15 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    // Review Summary & Apply Screen UI
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Heading (Image 2 style)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
              children: [
                const TextSpan(text: 'Own Your Career,\n'),
                TextSpan(
                  text: 'Shape Your Future.',
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF3867F5), Color(0xFF6FB1FC)],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 60.0)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle (Image 2 style)
          Text(
            'From dynamic contributions to authentic metrics, your professional resume is ready to rise.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () {
              if (_isStreamingActive) {
                _revealTextInstantly(_rawGeneratedSummary);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _summaryCtrl,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                readOnly: _isStreamingActive,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15.0,
                  height: 1.65,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: const Color(0xFF1E5FF5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  setState(() {
                    _streamingDraftText = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Safe Guidelines Row (Prevent Horizontal Overflows!)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final words = _streamingDraftText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
                      final isCorrectLength = words >= 100 && words <= 150;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCorrectLength ? Colors.green.withValues(alpha: 0.12) : Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCorrectLength ? Colors.green.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$words words (Target: 100-150)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCorrectLength ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!_isStreamingActive)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _generateSummary,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Regenerate AI Draft', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Animated Dots Indicator (Image 2 style)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = index == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? const Color(0xFF4364F7) : Colors.white24,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Primary Blue Gradient Pill Button (Image 2 style)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: const Color(0xFF0052D4).withValues(alpha: 0.4),
                elevation: 6,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _saving || _streamingDraftText.trim().isEmpty || _isStreamingActive ? null : _saveAndApply,
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
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Apply & Save Summary',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Discard Link Button below it (Image 2 style)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: Text(
                'Discard and Go Back',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFF06060C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('Syncing cosmic profile details...', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06060C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06060C),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0 && !_generating) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'AI Professional Summary',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF040209),
                Color(0xFF08061C),
                Color(0xFF012175),
                Color(0xFF1E5FF5),
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          child: Column(
            children: [
              // Premium Progress indicators at the top
              if (!_generating) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      // Step 1
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _currentStep >= 0 ? AppColors.accent : Colors.white12,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Step 2
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _currentStep >= 1 ? AppColors.accent : Colors.white12,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Step 3
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _currentStep >= 2 ? AppColors.accent : Colors.white12,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Dynamically swap screen content depending on current step state
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _currentStep == 0
                      ? _buildStep1BubbleView()
                      : _currentStep == 1
                          ? _buildStep2ProjectsView()
                          : _buildStep3ComposingAndReview(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Organic float animation repeating physics-like controller for step 1 bubbles
class FloatingBubbleWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const FloatingBubbleWrapper({
    super.key,
    required this.child,
    required this.duration,
    this.offset = 8.0,
  });

  @override
  State<FloatingBubbleWrapper> createState() => _FloatingBubbleWrapperState();
}

class _FloatingBubbleWrapperState extends State<FloatingBubbleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: widget.offset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
