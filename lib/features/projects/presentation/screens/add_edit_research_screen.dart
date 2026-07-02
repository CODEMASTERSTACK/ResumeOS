import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../shared/widgets/custom_toast.dart';

class ContributorInput {
  final TextEditingController nameCtrl;
  final TextEditingController contributionCtrl;

  ContributorInput({String name = '', String contribution = ''})
      : nameCtrl = TextEditingController(text: name),
        contributionCtrl = TextEditingController(text: contribution);

  void dispose() {
    nameCtrl.dispose();
    contributionCtrl.dispose();
  }
}

class AddEditResearchScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AddEditResearchScreen({super.key, this.projectId});

  @override
  ConsumerState<AddEditResearchScreen> createState() =>
      _AddEditResearchScreenState();
}

class _AddEditResearchScreenState extends ConsumerState<AddEditResearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicCtrl = TextEditingController();
  final _bullet1Ctrl = TextEditingController();
  final _bullet2Ctrl = TextEditingController();
  final _bullet3Ctrl = TextEditingController();

  String? _selectedMonth;
  String? _selectedYear;
  bool _hasContributors = false;
  List<ContributorInput> _contributors = [];
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _years = List.generate(21, (index) => (2020 + index).toString());

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
        _topicCtrl.text = project.title;

        // Parse duration
        if (project.duration.isNotEmpty) {
          final parts = project.duration.split(' ');
          if (parts.length >= 2) {
            final monthCandidate = parts[0];
            final yearCandidate = parts[1];
            if (_months.contains(monthCandidate)) {
              _selectedMonth = monthCandidate;
            }
            if (_years.contains(yearCandidate)) {
              _selectedYear = yearCandidate;
            }
          }
        }

        // Parse bullets
        if (project.bulletPoints.isNotEmpty) {
          _bullet1Ctrl.text = project.bulletPoints.isNotEmpty ? project.bulletPoints[0] : '';
          _bullet2Ctrl.text = project.bulletPoints.length >= 2 ? project.bulletPoints[1] : '';
          _bullet3Ctrl.text = project.bulletPoints.length >= 3 ? project.bulletPoints[2] : '';
        }

        // Parse contributors
        if (project.contributors.isNotEmpty) {
          _hasContributors = true;
          _contributors = project.contributors
              .map((c) => ContributorInput(name: c.name, contribution: c.contribution))
              .toList();
        }
      });
    }
  }

  void _addContributor() {
    setState(() {
      _contributors.add(ContributorInput());
    });
  }

  void _removeContributor(int index) {
    setState(() {
      _contributors[index].dispose();
      _contributors.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMonth == null || _selectedYear == null) {
      CustomToast.show(
        context,
        message: 'Please select both month and year for duration',
        type: ToastType.error,
      );
      return;
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final durationStr = '$_selectedMonth $_selectedYear';
      final List<Contributor> mappedContributors = _hasContributors
          ? _contributors.map((c) {
              return Contributor(
                name: c.nameCtrl.text.trim(),
                contribution: c.contributionCtrl.text.trim(),
              );
            }).toList()
          : [];

      final project = ProjectModel(
        id: widget.projectId ?? const Uuid().v4(),
        uid: uid,
        title: _topicCtrl.text.trim(),
        duration: durationStr,
        bulletPoints: [
          _bullet1Ctrl.text.trim(),
          _bullet2Ctrl.text.trim(),
          _bullet3Ctrl.text.trim(),
        ],
        isResearch: true,
        contributors: mappedContributors,
      );

      if (_isEditing) {
        await ref
            .read(projectRepositoryProvider)
            .updateProject(uid, widget.projectId!, project.toJson());
      } else {
        await ref.read(projectRepositoryProvider).addProject(uid, project);
      }

      if (mounted) {
        CustomToast.show(
          context,
          message: _isEditing ? 'Research work updated!' : 'Research work added!',
          type: ToastType.success,
        );
        context.pop();
      }
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
    _topicCtrl.dispose();
    _bullet1Ctrl.dispose();
    _bullet2Ctrl.dispose();
    _bullet3Ctrl.dispose();
    for (final c in _contributors) {
      c.dispose();
    }
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

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
          dropdownColor: const Color(0xFF1E1C28),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
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
          _isEditing ? 'Edit Research Work' : 'Add Research Work',
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

                  // Topic/Title
                  _FormField(
                    label: 'Research Topic / Title *',
                    child: TextFormField(
                      controller: _topicCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle(hintText: 'e.g., Deep Learning Methods in NLP'),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Topic is required' : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Duration
                  _FormField(
                    label: 'Duration (Month & Year) *',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedMonth,
                            hint: 'Month',
                            items: _months,
                            onChanged: (val) {
                              setState(() => _selectedMonth = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedYear,
                            hint: 'Year',
                            items: _years,
                            onChanged: (val) {
                              setState(() => _selectedYear = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description - 3 Bullet points
                  _FormField(
                    label: 'Research Description (3 bullet points) *',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _bullet1Ctrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputStyle(hintText: 'Bullet Point 1: Core problem studied or goal'),
                          validator: (v) =>
                              v?.isEmpty == true ? 'Bullet point 1 is required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bullet2Ctrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputStyle(hintText: 'Bullet Point 2: Methodologies or data used'),
                          validator: (v) =>
                              v?.isEmpty == true ? 'Bullet point 2 is required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bullet3Ctrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputStyle(hintText: 'Bullet Point 3: Key outcomes, findings or publication status'),
                          validator: (v) =>
                              v?.isEmpty == true ? 'Bullet point 3 is required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contributor Section Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Any Contributors?',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add collaborators who contributed to this research',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _hasContributors,
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.white70,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (val) {
                            setState(() {
                              _hasContributors = val;
                              if (val && _contributors.isEmpty) {
                                _addContributor();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Contributors List
                  if (_hasContributors) ...[
                    const SizedBox(height: 16),
                    ..._contributors.asMap().entries.map((entry) {
                      final i = entry.key;
                      final input = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Contributor #${i + 1}',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF6FB1FC),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_contributors.length > 1)
                                    GestureDetector(
                                      onTap: () => _removeContributor(i),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: input.nameCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputStyle(hintText: 'Contributor Name'),
                                validator: (v) =>
                                    _hasContributors && (v?.isEmpty == true)
                                        ? 'Name is required'
                                        : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: input.contributionCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputStyle(hintText: 'Role / Contribution (e.g., Data Analysis)'),
                                validator: (v) =>
                                    _hasContributors && (v?.isEmpty == true)
                                        ? 'Contribution description is required'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _addContributor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, color: Color(0xFF6FB1FC), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Add Contributor',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF6FB1FC),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Save Button
                  GestureDetector(
                    onTap: _isLoading ? null : _save,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0052D4), Color(0xFF1E5FF5), Color(0xFF6FB1FC)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0052D4).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _isEditing ? 'Save Changes' : 'Add Research Work',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
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

  const _FormField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
