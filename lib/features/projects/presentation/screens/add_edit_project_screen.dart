import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../shared/widgets/custom_toast.dart';
import 'package:uuid/uuid.dart';

import '../widgets/link_skills_bottom_sheet.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AddEditProjectScreen({super.key, this.projectId});

  @override
  ConsumerState<AddEditProjectScreen> createState() =>
      _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _liveCtrl = TextEditingController();
  final _techCtrl = TextEditingController();

  ProjectModel? _existingProject;
  List<String> _technologies = [];
  List<String> _linkedSkills = [];
  bool _isLoading = false;
  bool _isGeneratingAI = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _isEditing = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final project = await ref
        .read(projectRepositoryProvider)
        .getProject(uid, widget.projectId!);
    if (project != null && mounted) {
      setState(() {
        _existingProject = project;
        _titleCtrl.text = project.title;
        _descCtrl.text = project.description;
        _githubCtrl.text = project.githubRepo;
        _liveCtrl.text = project.liveUrl;
        _technologies = List.from(project.technologies);
        _linkedSkills = List.from(project.linkedSkills);
      });
    }
  }

  void _addTech(String tech) {
    final t = tech.trim();
    if (t.isNotEmpty && !_technologies.contains(t)) {
      setState(() => _technologies.add(t));
      _techCtrl.clear();
    }
  }

  Future<void> _openLinkSkillsBottomSheet() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final result = await showLinkSkillsBottomSheet(
      context: context,
      uid: uid,
      projectTitle: _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : 'Current Project',
      initialSkills: _linkedSkills,
      projectId: widget.projectId,
      onSkillsUpdated: (updatedSkills) {
        if (mounted) {
          setState(() {
            _linkedSkills = List.from(updatedSkills);
          });
        }
      },
    );

    if (result != null && mounted) {
      setState(() {
        _linkedSkills = List.from(result);
      });
    }
  }

  Future<void> _generateAISummary() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      CustomToast.show(
        context,
        message: 'Fill in title and description first',
        type: ToastType.error,
      );
      return;
    }
    setState(() => _isGeneratingAI = true);
    try {
      final ai = ref.read(geminiServiceImplProvider);
      final result = await ai.rewriteProjectBullets(
        projectTitle: _titleCtrl.text,
        projectDescription: _descCtrl.text,
        technologies: _technologies,
        targetRole: 'Software Engineer',
        keywords: _technologies,
      );
      if (mounted) {
        _descCtrl.text = result.bullets.join('\n• ');
        CustomToast.show(
          context,
          message: 'AI summary generated!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: AppStrings.aiError,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final project = (_existingProject != null)
          ? _existingProject!.copyWith(
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              githubRepo: _githubCtrl.text.trim(),
              liveUrl: _liveCtrl.text.trim(),
              technologies: _technologies,
              linkedSkills: _linkedSkills,
            )
          : ProjectModel(
              id: widget.projectId ?? const Uuid().v4(),
              uid: uid,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              githubRepo: _githubCtrl.text.trim(),
              liveUrl: _liveCtrl.text.trim(),
              technologies: _technologies,
              linkedSkills: _linkedSkills,
            );

      if (_isEditing) {
        await ref
            .read(projectRepositoryProvider)
            .updateProject(uid, widget.projectId!, project.toJson());
      } else {
        await ref.read(projectRepositoryProvider).addProject(uid, project);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: AppStrings.genericError,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _githubCtrl.dispose();
    _liveCtrl.dispose();
    _techCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputStyle({
    required String hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _isEditing ? 'Edit Project' : AppStrings.addProject,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Core Bright focal light source (top-left) - almost white-pink bloom
          Positioned(
            top: -60,
            left: -60,
            width: 220,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6), // White-pink core bloom
              ),
            ),
          ),

          // 2. Neon Sunlight effect (bright warm golden sunlight leak)
          Positioned(
            top: -100,
            left: -100,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    const Color(0xFFFFFFE0), // Hot golden white sun core
                    const Color(0xFFFFEE55).withValues(alpha: 0.5), // Vibrant neon yellow bloom
                    const Color(0xFFFFB300).withValues(alpha: 0.25), // Neon amber halo
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 2. Volumetric Diagonal Light Leak / Spotlight beam
          Positioned(
            top: -120,
            left: -120,
            width: screenHeight * 0.55,
            height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15, // Soft diagonal sweep toward center-right
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.6), // Magenta highlight
                      const Color(0xFF723FFD).withValues(alpha: 0.45), // Purple highlight
                      const Color(0xFF1E6AFF).withValues(alpha: 0.25), // Blue accent
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Layered ambient purple glow layer for surrounding bloom
          Positioned(
            top: -50,
            left: -50,
            width: screenHeight * 0.4,
            height: screenHeight * 0.4,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.3),
              ),
            ),
          ),

          // 4. Secondary soft blue highlight (extends center-right)
          Positioned(
            top: 60,
            left: 100,
            width: screenHeight * 0.4,
            height: screenHeight * 0.3,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E6AFF).withValues(alpha: 0.22),
              ),
            ),
          ),

          // 5. Cinematic Blur overlay to blend layers into an immersive aurora bloom
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30), // Integrated background overlay
              ),
            ),
          ),

          // 6. Content Form Layer
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  const SizedBox(height: 56),

                  // Title
                  _FormField(
                    label: 'Project Title *',
                    child: TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle(hintText: 'e.g., AI Resume Builder'),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Title is required' : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _FormField(
                    label: 'Description *',
                    action: _isGeneratingAI || _isEditing
                        ? null
                        : TextButton.icon(
                            onPressed: _generateAISummary,
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AppColors.accent),
                            label: const Text(
                              'AI Enhance',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                    child: TextFormField(
                      controller: _descCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle(
                        hintText: 'Describe what you built, your role, and impact...',
                      ),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Description is required' : null,
                    ),
                  ),
                  if (_isGeneratingAI)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'AI is rewriting your bullets...',
                            style: TextStyle(color: AppColors.accent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── Linked Profile Skills Section ───────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13111C).withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _linkedSkills.isNotEmpty
                            ? AppColors.accent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _linkedSkills.isNotEmpty
                              ? AppColors.accent.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.30),
                                ),
                              ),
                              child: const Icon(
                                Icons.hub_rounded,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Linked Skills',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.accent.withValues(alpha: 0.30),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          '${_linkedSkills.length}',
                                          style: GoogleFonts.outfit(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Profile skills mapped for AI resume tailoring',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.50),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Link / Manage Skills button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _openLinkSkillsBottomSheet,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accent.withValues(alpha: 0.20),
                                        const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.accent.withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_link_rounded,
                                        size: 14,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _linkedSkills.isEmpty ? 'Link Skills' : 'Manage',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Skills Wrap or Empty Prompt
                        if (_linkedSkills.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _linkedSkills.map((skill) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.28),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.link_rounded,
                                      size: 12,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      skill,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() => _linkedSkills.remove(skill)),
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.08),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 11,
                                          color: Colors.white.withValues(alpha: 0.70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        else
                          GestureDetector(
                            onTap: _openLinkSkillsBottomSheet,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.hub_outlined,
                                    size: 26,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No skills linked from your profile yet',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(alpha: 0.70),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tap here to link verified skills from your profile',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.40),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Technologies & Stack Section ───────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13111C).withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E5FF5).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF6FB1FC).withValues(alpha: 0.30),
                                ),
                              ),
                              child: const Icon(
                                Icons.terminal_rounded,
                                color: Color(0xFF6FB1FC),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Technologies & Stack',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (_technologies.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E5FF5).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFF6FB1FC).withValues(alpha: 0.30),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '${_technologies.length}',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF6FB1FC),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Languages, libraries, and tools used in this project',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.50),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Tech Input Field + Add Button
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _techCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                decoration: _inputStyle(
                                  hintText: 'e.g., Flutter, Node.js, Docker...',
                                  prefixIcon: Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.white.withValues(alpha: 0.35),
                                    size: 17,
                                  ),
                                ),
                                onSubmitted: _addTech,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _addTech(_techCtrl.text),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0052D4), Color(0xFF1E5FF5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0052D4).withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Technologies Wrap
                        if (_technologies.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _technologies.map((tech) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E5FF5).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6FB1FC).withValues(alpha: 0.30),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.code_rounded,
                                      size: 12,
                                      color: Color(0xFF6FB1FC),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      tech,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() => _technologies.remove(tech)),
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.08),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 11,
                                          color: Colors.white.withValues(alpha: 0.70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // GitHub
                  _FormField(
                    label: 'GitHub Repository URL',
                    child: TextFormField(
                      controller: _githubCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle(
                        hintText: 'https://github.com/username/repo',
                        prefixIcon: Icon(Icons.code, color: Colors.white.withValues(alpha: 0.4), size: 18),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Live URL
                  _FormField(
                    label: 'Live Demo URL',
                    child: TextFormField(
                      controller: _liveCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle(
                        hintText: 'https://myproject.com',
                        prefixIcon: Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.4), size: 18),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Save Button
                  GestureDetector(
                    onTap: _isLoading ? null : _save,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0052D4), Color(0xFF1E5FF5), Color(0xFF6FB1FC)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0052D4).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEditing ? Icons.save_rounded : Icons.add_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditing ? AppStrings.saveChanges : 'Add Project',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        AppStrings.cancel,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? action;

  const _FormField({
    required this.label,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
