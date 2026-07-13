import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../services/pdf/pdf_service.dart';
import '../../domain/entities/resume_model.dart';
import '../../../../features/projects/presentation/screens/projects_screen.dart';
import '../../../../features/projects/domain/entities/project_model.dart';

class ResumeEditScreen extends ConsumerStatefulWidget {
  final String resumeId;

  const ResumeEditScreen({super.key, required this.resumeId});

  @override
  ConsumerState<ResumeEditScreen> createState() => _ResumeEditScreenState();
}

class _ResumeEditScreenState extends ConsumerState<ResumeEditScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showLivePreview = false; // Toggle state between form and live PDF
  ResumeModel? _resumeModel;
  ResumeData? _resumeData;

  // Controllers for general fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _githubController;
  late TextEditingController _linkedinController;
  late TextEditingController _portfolioController;
  late TextEditingController _summaryController;

  // Styling settings
  late String _selectedColorHex;
  late String _selectedFontFamily;
  late double _selectedFontSizeScale;

  // Form State lists for dynamic sections
  List<ResumeSkillGroup> _skillGroups = [];
  List<ResumeEducation> _education = [];
  List<ResumeExperience> _experience = [];
  List<ResumeProject> _projects = [];
  List<ResumeProject> _research = [];
  bool _showResearch = true;
  bool _showCertifications = true;
  bool _showAchievements = true;
  List<ResumeCertification> _certifications = [];
  List<String> _achievements = [];
  String? _activeFullscreenSection;

  // Stable controllers for certifications (prevents stale-closure RangeError)
  final List<TextEditingController> _certTitleCtrls = [];
  final List<TextEditingController> _certIssuerCtrls = [];
  final List<TextEditingController> _certUrlCtrls = [];
  // Stable controllers for achievements
  final List<TextEditingController> _achBulletCtrls = [];

  final List<Map<String, String>> _availableColors = [
    {'name': 'Navy Blue', 'hex': '#1E3A8A'},
    {'name': 'Cool Indigo', 'hex': '#6366F1'},
    {'name': 'Teal Rain', 'hex': '#0F766E'},
    {'name': 'Emerald Green', 'hex': '#059669'},
    {'name': 'Crimson Rose', 'hex': '#BE123C'},
    {'name': 'Charcoal Grey', 'hex': '#1E293B'},
    {'name': 'Deep Purple', 'hex': '#7C3AED'},
  ];

  final List<Map<String, String>> _availableFonts = [
    {'label': 'Clean Sans', 'value': 'sans', 'desc': 'Helvetica style'},
    {'label': 'Classic Serif', 'value': 'serif', 'desc': 'Times style'},
    {'label': 'Technical Mono', 'value': 'mono', 'desc': 'Courier style'},
  ];

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _summaryController.dispose();
    for (final c in _certTitleCtrls) c.dispose();
    for (final c in _certIssuerCtrls) c.dispose();
    for (final c in _certUrlCtrls) c.dispose();
    for (final c in _achBulletCtrls) c.dispose();
    super.dispose();
  }

  /// Sync the stable cert controller lists to match [_certifications] length.
  void _syncCertControllers() {
    while (_certTitleCtrls.length < _certifications.length) {
      final i = _certTitleCtrls.length;
      _certTitleCtrls.add(TextEditingController(text: _certifications[i].title));
      _certIssuerCtrls.add(TextEditingController(text: _certifications[i].issuer));
      _certUrlCtrls.add(TextEditingController(text: _certifications[i].credentialUrl));
    }
    while (_certTitleCtrls.length > _certifications.length) {
      _certTitleCtrls.removeLast().dispose();
      _certIssuerCtrls.removeLast().dispose();
      _certUrlCtrls.removeLast().dispose();
    }
  }

  /// Sync the stable achievement controller list to match [_achievements] length.
  void _syncAchControllers() {
    while (_achBulletCtrls.length < _achievements.length) {
      final i = _achBulletCtrls.length;
      final parts = _achievements[i].split('|');
      _achBulletCtrls.add(TextEditingController(text: parts[0].trim()));
    }
    while (_achBulletCtrls.length > _achievements.length) {
      _achBulletCtrls.removeLast().dispose();
    }
  }

  Future<void> _loadResume() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('resumes')
          .doc(widget.resumeId)
          .get();

      if (doc.exists && mounted) {
        final model = ResumeModel.fromFirestore(doc);
        final data = model.generatedResumeData;

        if (data != null) {
          setState(() {
            _resumeModel = model;
            _resumeData = data;

            _nameController = TextEditingController(text: data.name);
            _emailController = TextEditingController(text: data.email);
            _phoneController = TextEditingController(text: data.phone);
            _locationController = TextEditingController(text: data.location);
            _githubController = TextEditingController(text: data.githubUrl);
            _linkedinController = TextEditingController(text: data.linkedinUrl);
            _portfolioController = TextEditingController(text: data.portfolioUrl);
            _summaryController = TextEditingController(text: data.summary);

            _selectedColorHex = data.primaryColorHex;
            _selectedFontFamily = data.fontFamily;
            _selectedFontSizeScale = data.fontSizeScale;

            _skillGroups = List<ResumeSkillGroup>.from(data.skillGroups);
            _education = List<ResumeEducation>.from(data.education);
            _experience = List<ResumeExperience>.from(data.experience);
            _projects = List<ResumeProject>.from(data.projects);
            _research = List<ResumeProject>.from(data.research);
            _showResearch = data.showResearch;
            _showCertifications = data.showCertifications;
            _showAchievements = data.showAchievements;
            _certifications = List<ResumeCertification>.from(data.certifications);
            _achievements = List<String>.from(data.achievements);

            // Initialise stable controllers
            _syncCertControllers();
            _syncAchControllers();

            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveResume() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null || _resumeData == null) return;

    setState(() => _saving = true);

    try {
      final updatedData = ResumeData(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        githubUrl: _githubController.text.trim(),
        linkedinUrl: _linkedinController.text.trim(),
        portfolioUrl: _portfolioController.text.trim(),
        summary: _summaryController.text.trim(),
        skillGroups: _skillGroups,
        education: _education,
        experience: _experience,
        projects: _projects,
        research: _research,
        showResearch: _showResearch,
        showCertifications: _showCertifications,
        showAchievements: _showAchievements,
        certifications: _certifications,
        achievements: _achievements,
        primaryColorHex: _selectedColorHex,
        fontFamily: _selectedFontFamily,
        fontSizeScale: _selectedFontSizeScale,
      );

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('resumes')
          .doc(widget.resumeId)
          .update({
        'generatedResumeData': updatedData.toJson(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume updated and styling saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save resume: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAttachLinkDialog(TextEditingController controller) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');

    await showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F0E17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: Text(
            'Insert Asset URL Link',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Link Title (e.g. GitHub, Credential)',
                  labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.transparent,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCBE349)),
                  ),
                ),
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL Address',
                  labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.transparent,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCBE349)),
                  ),
                ),
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final label = titleController.text.trim();
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  final linkStr = label.isNotEmpty ? '$label: $url' : url;
                  final currentText = controller.text;
                  final cursorPosition = controller.selection.baseOffset;

                  String newText;
                  if (cursorPosition >= 0) {
                    newText = currentText.substring(0, cursorPosition) +
                        linkStr +
                        currentText.substring(cursorPosition);
                  } else {
                    newText = currentText + (currentText.isNotEmpty ? ' ' : '') + linkStr;
                  }

                  controller.text = newText;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(
                        offset: cursorPosition >= 0
                            ? cursorPosition + linkStr.length
                            : newText.length),
                  );
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCBE349),
                foregroundColor: const Color(0xFF07060F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Insert',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeFullscreenSection != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07060F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _activeFullscreenSection = null;
              });
            },
          ),
          title: Text(
            _activeFullscreenSection!,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final sectionSaved = _activeFullscreenSection;
                setState(() {
                  _activeFullscreenSection = null;
                });
                if (sectionSaved != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Changes to $sectionSaved updated! Click "Save & Close" to persist to Firestore.'),
                      backgroundColor: const Color(0xFFCBE349),
                    ),
                  );
                }
              },
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFCBE349),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getActiveSectionChildren(_activeFullscreenSection!),
            ),
          ),
        ),
      );
    }
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
        title: Text(
          'Format & Style',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: _saving ? null : _saveResume,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBE349),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCBE349).withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _saving
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF07060F),
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 14, color: Color(0xFF07060F)),
                      const SizedBox(width: 6),
                      Text(
                        'Save & Close',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF07060F),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Ambient Background Glows ──
          Positioned(
            top: -60, left: -60, width: 220, height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.5, height: screenHeight * 0.4,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            width: screenHeight * 0.35, height: screenHeight * 0.35,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.35),
              ),
            ),
          ),

          // ── Content ──
          _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCBE349)))
              : _resumeData == null
                  ? Center(
                      child: Text(
                        'Failed to load resume details',
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                      ),
                    )
                  : Column(
                      children: [
                        // Sticky top styling toolkit
                        _buildStyleToolkit(),

                        // Sliding segment switch between Form fields and Live high-fidelity PDF preview!
                        _buildToggleRow(),

                        // Main editor content or high-fidelity Live PDF page
                        Expanded(
                          child: _showLivePreview
                              ? _buildLivePdfPreview()
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                                  child: Column(
                                    children: [
                                      _buildPersonalInfoSection(),
                                      const SizedBox(height: 16),
                                      _buildSummarySection(),
                                      const SizedBox(height: 16),
                                      _buildSkillGroupsSection(),
                                      const SizedBox(height: 16),
                                      _buildExperienceSection(),
                                      const SizedBox(height: 16),
                                      _buildProjectsSection(),
                                      const SizedBox(height: 16),
                                      _buildResearchSection(),
                                      const SizedBox(height: 16),
                                      _buildEducationSection(),
                                      const SizedBox(height: 16),
                                      _buildCertificationsSection(),
                                      const SizedBox(height: 16),
                                      _buildAchievementsSection(),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  // ── Toggle Switch Widget ──────────────────────────────
  Widget _buildToggleRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Form Editor',
              isActive: !_showLivePreview,
              icon: Icons.edit_note_rounded,
              onTap: () => setState(() => _showLivePreview = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'Live PDF Preview',
              isActive: _showLivePreview,
              icon: Icons.picture_as_pdf_rounded,
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _showLivePreview = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFCBE349) : Colors.white60,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live High-fidelity PDF Preview Widget ──────────────────────────
  Widget _buildLivePdfPreview() {
    final pdfService = PdfService();
    final currentData = ResumeData(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      location: _locationController.text.trim(),
      githubUrl: _githubController.text.trim(),
      linkedinUrl: _linkedinController.text.trim(),
      portfolioUrl: _portfolioController.text.trim(),
      summary: _summaryController.text.trim(),
      skillGroups: _skillGroups,
      education: _education,
      experience: _experience,
      projects: _projects,
      research: _research,
      showResearch: _showResearch,
      certifications: _certifications,
      achievements: _achievements,
      primaryColorHex: _selectedColorHex,
      fontFamily: _selectedFontFamily,
      fontSizeScale: _selectedFontSizeScale,
    );

    return Container(
      color: const Color(0xFF0C0B12), // Slate canvas background matching preview
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: PdfPreview(
          build: (format) => pdfService.generatePdf(
            currentData,
            _resumeModel?.templateUsed ?? ResumeTemplate.atsProfessional,
          ),
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          loadingWidget: const Center(
              child: CircularProgressIndicator(color: Color(0xFFCBE349))),
          pdfFileName: 'Resume_Preview.pdf',
        ),
      ),
    );
  }

  // ── Style Customizer Widget Toolkit ──────────────────────────────
  Widget _buildStyleToolkit() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, color: Color(0xFFCBE349), size: 16),
              const SizedBox(width: 8),
              Text(
                'VISUAL THEME ENGINE',
                style: GoogleFonts.firaCode(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Accent Color Choice Row
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _availableColors.length,
              itemBuilder: (context, idx) {
                final col = _availableColors[idx];
                final hex = col['hex']!;
                final name = col['name']!;
                final isSelected = _selectedColorHex.toLowerCase() == hex.toLowerCase();
                final color = Color(int.parse(hex.replaceFirst('#', '0xff')));

                return GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.white54,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Font selection
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TYPOGRAPHY FONT',
                      style: GoogleFonts.firaCode(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _availableFonts.length,
                        itemBuilder: (context, idx) {
                          final f = _availableFonts[idx];
                          final value = f['value']!;
                          final label = f['label']!;
                          final isSelected = _selectedFontFamily == value;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedFontFamily = value),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF723FFD).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF723FFD)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Font size scale selector
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FONT SIZE: ${(_selectedFontSizeScale * 100).toInt()}%',
                      style: GoogleFonts.firaCode(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildSizeOption('90%', 0.9),
                        const SizedBox(width: 4),
                        _buildSizeOption('100%', 1.0),
                        const SizedBox(width: 4),
                        _buildSizeOption('110%', 1.1),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Section Toggles
          Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Color(0xFFCBE349), size: 16),
              const SizedBox(width: 8),
              Text(
                'CONTENT TOGGLES',
                style: GoogleFonts.firaCode(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildToggleOption(
                  label: 'Certifications',
                  value: _showCertifications,
                  onChanged: (val) => setState(() => _showCertifications = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleOption(
                  label: 'Achievements',
                  value: _showAchievements,
                  onChanged: (val) => setState(() => _showAchievements = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF723FFD).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value
                ? const Color(0xFF723FFD)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 14,
              color: value ? const Color(0xFFCBE349) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: value ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeOption(String label, double scale) {
    final isSelected = _selectedFontSizeScale == scale;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFontSizeScale = scale),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF723FFD).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF723FFD) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Card Builder Wrapper ─────────────────────────────────
  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFullscreenSection = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white70, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  List<Widget> _getActiveSectionChildren(String title) {
    switch (title) {
      case 'Contact Details':
        return _buildPersonalInfoChildren();
      case 'Professional Summary':
        return _buildSummaryChildren();
      case 'Skills & Proficiencies':
        return _buildSkillGroupsChildren();
      case 'Work / Training Experience':
        return _buildExperienceChildren();
      case 'Projects Portfolio':
        return _buildProjectsChildren();
      case 'Research Work':
        return _buildResearchChildren(ref.watch(projectsProvider));
      case 'Certifications':
        return _buildCertificationsChildren();
      case 'Achievements & Awards':
        return _buildAchievementsChildren();
      case 'Education History':
        return _buildEducationChildren();
      default:
        return [];
    }
  }

  List<Widget> _buildPersonalInfoChildren() {
    return [
      _buildTextField(controller: _nameController, label: 'Full Name'),
      _buildTextField(controller: _emailController, label: 'Email Address'),
      _buildTextField(controller: _phoneController, label: 'Phone / Mobile'),
      _buildTextField(controller: _locationController, label: 'Location (e.g. Pune, India)'),
      _buildTextField(controller: _githubController, label: 'GitHub Profile URL'),
      _buildTextField(controller: _linkedinController, label: 'LinkedIn Profile URL'),
      _buildTextField(controller: _portfolioController, label: 'LeetCode / Portfolio URL'),
    ];
  }

  List<Widget> _buildSummaryChildren() {
    return [
      _buildTextField(
        controller: _summaryController,
        label: 'Executive Summary',
        maxLines: 5,
      ),
    ];
  }

  List<Widget> _buildSkillGroupsChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _skillGroups.length,
        itemBuilder: (context, sIdx) {
          final group = _skillGroups[sIdx];
          final categoryController = TextEditingController(text: group.category);
          final skillsController = TextEditingController(text: group.skills.join(', '));

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category #${sIdx + 1}',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFCBE349),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _skillGroups.removeAt(sIdx));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: categoryController,
                  label: 'Category Name (e.g. Languages)',
                  onChanged: (val) {
                    _skillGroups[sIdx] = _skillGroups[sIdx].copyWith(category: val.trim());
                  },
                ),
                _buildTextField(
                  controller: skillsController,
                  label: 'Skills (separated by commas)',
                  onChanged: (val) {
                    final sks = val.split(',').map((s) => s.trim()).toList();
                    _skillGroups[sIdx] = _skillGroups[sIdx].copyWith(skills: sks);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final cats = categoryController.text.trim();
                      final sks = skillsController.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      setState(() {
                        _skillGroups[sIdx] = ResumeSkillGroup(category: cats, skills: sks);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Skill Category saved!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      'Confirm Changes',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCBE349),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _skillGroups.add(const ResumeSkillGroup(category: 'New Category', skills: []));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFCBE349)),
              const SizedBox(width: 8),
              Text(
                'Add Skill Category',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildExperienceChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _experience.length,
        itemBuilder: (context, eIdx) {
          final exp = _experience[eIdx];
          final companyController = TextEditingController(text: exp.company);
          final roleController = TextEditingController(text: exp.role);
          final durationController = TextEditingController(text: exp.duration);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Experience Position #${eIdx + 1}',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFCBE349),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _experience.removeAt(eIdx));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: companyController,
                  label: 'Company / Organization',
                  onChanged: (val) {
                    _experience[eIdx] = _experience[eIdx].copyWith(company: val.trim());
                  },
                ),
                _buildTextField(
                  controller: roleController,
                  label: 'Role / Designation',
                  onChanged: (val) {
                    _experience[eIdx] = _experience[eIdx].copyWith(role: val.trim());
                  },
                ),
                _buildTextField(
                  controller: durationController,
                  label: 'Duration (e.g. June 2024 - Present)',
                  onChanged: (val) {
                    _experience[eIdx] = _experience[eIdx].copyWith(duration: val.trim());
                  },
                ),

                // Bullets
                const SizedBox(height: 12),
                Text(
                  'Description Bullet Points',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ...List.generate(_experience[eIdx].bullets.length, (bIdx) {
                  final bulletController =
                      TextEditingController(text: _experience[eIdx].bullets[bIdx]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bulletController,
                            onChanged: (value) {
                              final updatedBullets = List<String>.from(_experience[eIdx].bullets);
                              updatedBullets[bIdx] = value;
                              _experience[eIdx] =
                                  _experience[eIdx].copyWith(bullets: updatedBullets);
                            },
                            decoration: InputDecoration(
                              labelText: 'Bullet #${bIdx + 1}',
                              labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                              suffixIcon: GestureDetector(
                                onTap: () async {
                                  await _showAttachLinkDialog(bulletController);
                                  final updatedBullets =
                                      List<String>.from(_experience[eIdx].bullets);
                                  updatedBullets[bIdx] = bulletController.text;
                                  setState(() {
                                    _experience[eIdx] =
                                        _experience[eIdx].copyWith(bullets: updatedBullets);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.link_rounded,
                                      color: Color(0xFFCBE349), size: 14),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.015),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF723FFD)),
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final updatedBullets = List<String>.from(_experience[eIdx].bullets)
                              ..removeAt(bIdx);
                            setState(() {
                              _experience[eIdx] =
                                  _experience[eIdx].copyWith(bullets: updatedBullets);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.remove_circle_outline_rounded,
                                color: Color(0xFFEF4444), size: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final updatedBullets = List<String>.from(_experience[eIdx].bullets)
                          ..add('');
                        setState(() {
                          _experience[eIdx] = _experience[eIdx].copyWith(bullets: updatedBullets);
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF723FFD)),
                      label: Text(
                        'Add Bullet',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF723FFD),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final company = companyController.text.trim();
                        final role = roleController.text.trim();
                        final duration = durationController.text.trim();

                        setState(() {
                          _experience[eIdx] = _experience[eIdx].copyWith(
                            company: company,
                            role: role,
                            duration: duration,
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Experience details saved!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        'Save Details',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFCBE349),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _experience.add(const ResumeExperience(
                company: 'New Company', role: 'Developer', duration: '', bullets: ['']));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFCBE349)),
              const SizedBox(width: 8),
              Text(
                'Add Experience Position',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildProjectsChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _projects.length,
        itemBuilder: (context, pIdx) {
          final proj = _projects[pIdx];
          final titleController = TextEditingController(text: proj.title);
          final techController = TextEditingController(text: proj.technologies.join(', '));
          final githubController = TextEditingController(text: proj.githubUrl);
          final liveController = TextEditingController(text: proj.liveUrl);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Project #${pIdx + 1}',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFCBE349),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _projects.removeAt(pIdx));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: titleController,
                  label: 'Project Name',
                  onChanged: (val) {
                    _projects[pIdx] = _projects[pIdx].copyWith(title: val.trim());
                  },
                ),
                _buildTextField(
                  controller: techController,
                  label: 'Technologies Used (separated by commas)',
                  onChanged: (val) {
                    final tech = val.split(',').map((t) => t.trim()).toList();
                    _projects[pIdx] = _projects[pIdx].copyWith(technologies: tech);
                  },
                ),
                _buildTextField(
                  controller: githubController,
                  label: 'GitHub Repository URL',
                  onChanged: (val) {
                    _projects[pIdx] = _projects[pIdx].copyWith(githubUrl: val.trim());
                  },
                ),
                _buildTextField(
                  controller: liveController,
                  label: 'Live Deploy / Project Link',
                  onChanged: (val) {
                    _projects[pIdx] = _projects[pIdx].copyWith(liveUrl: val.trim());
                  },
                ),

                // Bullets
                const SizedBox(height: 12),
                Text(
                  'Project Highlights Bullets (Max 2 recommended)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ...List.generate(_projects[pIdx].bullets.length, (bIdx) {
                  final bulletController = TextEditingController(text: _projects[pIdx].bullets[bIdx]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bulletController,
                            onChanged: (value) {
                              final updatedBullets = List<String>.from(_projects[pIdx].bullets);
                              updatedBullets[bIdx] = value;
                              _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                            },
                            decoration: InputDecoration(
                              labelText: 'Bullet #${bIdx + 1}',
                              labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                              suffixIcon: GestureDetector(
                                onTap: () async {
                                  await _showAttachLinkDialog(bulletController);
                                  final updatedBullets = List<String>.from(_projects[pIdx].bullets);
                                  updatedBullets[bIdx] = bulletController.text;
                                  setState(() {
                                    _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.link_rounded,
                                      color: Color(0xFFCBE349), size: 14),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.015),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF723FFD)),
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final updatedBullets = List<String>.from(_projects[pIdx].bullets)..removeAt(bIdx);
                            setState(() {
                              _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.remove_circle_outline_rounded,
                                color: Color(0xFFEF4444), size: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final updatedBullets = List<String>.from(_projects[pIdx].bullets)..add('');
                        setState(() {
                          _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF723FFD)),
                      label: Text(
                        'Add Highlight Bullet',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF723FFD),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final tech = techController.text
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        final git = githubController.text.trim();
                        final live = liveController.text.trim();

                        setState(() {
                          _projects[pIdx] = _projects[pIdx].copyWith(
                            title: title,
                            technologies: tech,
                            githubUrl: git,
                            liveUrl: live,
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Project details saved!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        'Save Details',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFCBE349),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _projects.add(const ResumeProject(
                title: 'New Project', technologies: [], bullets: [''], githubUrl: '', liveUrl: ''));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFCBE349)),
              const SizedBox(width: 8),
              Text(
                'Add Project Record',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildResearchChildren(AsyncValue<List<ProjectModel>> projectsAsync) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Show Research Section in Resume',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Switch(
            value: _showResearch,
            activeThumbColor: const Color(0xFFCBE349),
            activeTrackColor: const Color(0xFFCBE349).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white10,
            onChanged: (val) {
              setState(() {
                _showResearch = val;
              });
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_showResearch) ...[
        projectsAsync.when(
          data: (allProjects) {
            final availableResearch = allProjects.where((p) => p.isResearch).toList();
            if (availableResearch.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No research work items found in your profile. Please add them in the Project and Research Work screen.',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Research Work to include:',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableResearch.map((res) {
                    final isSelected = _research.any((r) => r.title == res.title);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (!isSelected) {
                            _research.add(ResumeProject(
                              title: res.title,
                              technologies: const [],
                              bullets: res.bulletPoints.take(3).toList(),
                              githubUrl: res.duration,
                              liveUrl: '',
                            ));
                          } else {
                            _research.removeWhere((r) => r.title == res.title);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF723FFD).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF723FFD)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_rounded,
                                color: Color(0xFFCBE349),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              res.title,
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.white : Colors.white60,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading research items: $err',
              style: GoogleFonts.outfit(color: Colors.redAccent)),
        ),
        const SizedBox(height: 16),
        if (_research.isNotEmpty) ...[
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _research.length,
            itemBuilder: (context, rIdx) {
              final item = _research[rIdx];
              final topicController = TextEditingController(text: item.title);
              final durationController = TextEditingController(text: item.githubUrl);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.015),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Research Item #${rIdx + 1}',
                          style: GoogleFonts.firaCode(
                            color: const Color(0xFFCBE349),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _research.removeAt(rIdx));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: topicController,
                      label: 'Research Topic / Title',
                      onChanged: (val) {
                        _research[rIdx] = _research[rIdx].copyWith(title: val.trim());
                      },
                    ),
                    _buildTextField(
                      controller: durationController,
                      label: 'Duration (e.g. Oct 2025 - Present)',
                      onChanged: (val) {
                        _research[rIdx] = _research[rIdx].copyWith(githubUrl: val.trim());
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Research Description Bullets (Max 3)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(item.bullets.length, (bIdx) {
                      final bulletController = TextEditingController(text: item.bullets[bIdx]);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: bulletController,
                                onChanged: (value) {
                                  final updatedBullets = List<String>.from(item.bullets);
                                  updatedBullets[bIdx] = value;
                                  _research[rIdx] = _research[rIdx].copyWith(bullets: updatedBullets);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Bullet #${bIdx + 1}',
                                  labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.015),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF723FFD)),
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final updatedBullets = List<String>.from(item.bullets)
                                  ..removeAt(bIdx);
                                setState(() {
                                  _research[rIdx] = _research[rIdx].copyWith(bullets: updatedBullets);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.remove_circle_outline_rounded,
                                    color: Color(0xFFEF4444), size: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item.bullets.length < 3)
                          TextButton.icon(
                            onPressed: () {
                              final updatedBullets = List<String>.from(item.bullets)..add('');
                              setState(() {
                                _research[rIdx] = _research[rIdx].copyWith(bullets: updatedBullets);
                              });
                            },
                            icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF723FFD)),
                            label: Text(
                              'Add Bullet',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF723FFD),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        TextButton(
                          onPressed: () {
                            final topic = topicController.text.trim();
                            final dur = durationController.text.trim();
                            setState(() {
                              _research[rIdx] = _research[rIdx].copyWith(
                                title: topic,
                                githubUrl: dur,
                              );
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Research details saved!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Text(
                            'Save Details',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFCBE349),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    ];
  }

  List<Widget> _buildCertificationsChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _certifications.length,
        itemBuilder: (context, certIdx) {
          final cert = _certifications[certIdx];
          final titleController = _certTitleCtrls[certIdx];
          final issuerController = _certIssuerCtrls[certIdx];
          final urlController = _certUrlCtrls[certIdx];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Certification #${certIdx + 1}',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFCBE349),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _certifications.removeAt(certIdx);
                          _syncCertControllers();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: titleController,
                  label: 'Certificate Title',
                  onChanged: (val) {
                    if (certIdx < _certifications.length) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(title: val.trim());
                    }
                  },
                ),
                _buildTextField(
                  controller: issuerController,
                  label: 'Issuing Authority / Issuer',
                  onChanged: (val) {
                    if (certIdx < _certifications.length) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(issuer: val.trim());
                    }
                  },
                ),
                
                const Text(
                  'Date Earned / Expiry',
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final dateMap = _parseCertDate(cert.date);
                    final String currentMonth = dateMap['month']!;
                    final String currentYear = dateMap['year']!;
                    
                    const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final years = List.generate(21, (index) => (2015 + index).toString());
                    
                    final String selectedMonth = shortMonths.contains(currentMonth) ? currentMonth : 'Jan';
                    final String selectedYear = years.contains(currentYear) ? currentYear : '2025';

                    return Row(
                      children: [
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: const Color(0xFF0C0B10),
                            ),
                            child: DropdownButtonFormField<String>(
                              dropdownColor: const Color(0xFF0C0B10),
                              value: selectedMonth,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Month',
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: shortMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) {
                                if (val != null && certIdx < _certifications.length) {
                                  final String yrShort = selectedYear.substring(selectedYear.length - 2);
                                  setState(() {
                                    _certifications[certIdx] = _certifications[certIdx].copyWith(date: "$val'$yrShort");
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: const Color(0xFF0C0B10),
                            ),
                            child: DropdownButtonFormField<String>(
                              dropdownColor: const Color(0xFF0C0B10),
                              value: selectedYear,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Year',
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (val) {
                                if (val != null && certIdx < _certifications.length) {
                                  final String yrShort = val.substring(val.length - 2);
                                  setState(() {
                                    _certifications[certIdx] = _certifications[certIdx].copyWith(date: "$selectedMonth'$yrShort");
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: urlController,
                  label: 'Credential Verification URL',
                  onChanged: (val) {
                    if (certIdx < _certifications.length) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(credentialUrl: val.trim());
                    }
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      if (certIdx >= _certifications.length) return;
                      final tit = titleController.text.trim();
                      final iss = issuerController.text.trim();
                      final dat = _certifications[certIdx].date;
                      final url = urlController.text.trim();

                      setState(() {
                        _certifications[certIdx] = ResumeCertification(
                          title: tit,
                          issuer: iss,
                          date: dat,
                          credentialUrl: url,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Certification details saved!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      'Save Record',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCBE349),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _certifications
                .add(const ResumeCertification(title: 'New Certificate', issuer: '', date: "Jan'26"));
            _syncCertControllers();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFCBE349)),
              const SizedBox(width: 8),
              Text(
                'Add Certification Record',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAchievementsChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _achievements.length,
        itemBuilder: (context, aIdx) {
          final achValue = _achievements[aIdx];
          final achParts = achValue.split('|');
          final datePart = achParts.length > 1 ? achParts[1].trim() : "Jan'25";

          final bulletController = _achBulletCtrls[aIdx];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Achievement #${aIdx + 1}',
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFFCBE349),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _achievements.removeAt(aIdx);
                            _syncAchControllers();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bulletController,
                    onChanged: (value) {
                      if (aIdx < _achievements.length) {
                        final dateMap = _parseCertDate(datePart);
                        final mShort = dateMap['month']!;
                        final yShort = dateMap['year']!.substring(dateMap['year']!.length - 2);
                        _achievements[aIdx] = "${value.trim()}|$mShort'$yShort";
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Achievement Details',
                      labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                      suffixIcon: GestureDetector(
                        onTap: () async {
                          await _showAttachLinkDialog(bulletController);
                          if (aIdx < _achievements.length) {
                            final dateMap = _parseCertDate(datePart);
                            final mShort = dateMap['month']!;
                            final yShort = dateMap['year']!.substring(dateMap['year']!.length - 2);
                            setState(() {
                              _achievements[aIdx] = "${bulletController.text.trim()}|$mShort'$yShort";
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.link_rounded, color: Color(0xFFCBE349), size: 14),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.015),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF723FFD)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Date Earned / Achieved',
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final dateMap = _parseCertDate(datePart);
                      final String currentMonth = dateMap['month']!;
                      final String currentYear = dateMap['year']!;
                      
                      const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      final years = List.generate(21, (index) => (2015 + index).toString());
                      
                      final String selectedMonth = shortMonths.contains(currentMonth) ? currentMonth : 'Jan';
                      final String selectedYear = years.contains(currentYear) ? currentYear : '2025';

                      return Row(
                        children: [
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: const Color(0xFF0C0B10),
                              ),
                              child: DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF0C0B10),
                                value: selectedMonth,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Month',
                                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                  floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.03),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: shortMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (val) {
                                  if (val != null && aIdx < _achievements.length) {
                                    final String yrShort = selectedYear.substring(selectedYear.length - 2);
                                    setState(() {
                                      _achievements[aIdx] = "${bulletController.text.trim()}|$val'$yrShort";
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: const Color(0xFF0C0B10),
                              ),
                              child: DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF0C0B10),
                                value: selectedYear,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Year',
                                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                  floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.03),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                onChanged: (val) {
                                  if (val != null && aIdx < _achievements.length) {
                                    final String yrShort = val.substring(val.length - 2);
                                    setState(() {
                                      _achievements[aIdx] = "${bulletController.text.trim()}|$selectedMonth'$yrShort";
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _achievements.add("New Achievement|Jan'26");
                _syncAchControllers();
              });
            },
            icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF723FFD)),
            label: Text(
              'Add Achievement',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF723FFD),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Achievements saved!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Text(
              'Confirm Saved',
              style: GoogleFonts.outfit(
                color: const Color(0xFFCBE349),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildEducationChildren() {
    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _education.length,
        itemBuilder: (context, eduIdx) {
          final edu = _education[eduIdx];
          final instController = TextEditingController(text: edu.institution);
          final degreeController = TextEditingController(text: edu.degree);
          final fieldController = TextEditingController(text: edu.field);
          final cgpaController = TextEditingController(text: edu.cgpa);
          final durationController = TextEditingController(text: edu.duration);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Education Record #${eduIdx + 1}',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFCBE349),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _education.removeAt(eduIdx));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: instController,
                  label: 'Institution Name',
                  onChanged: (val) {
                    _education[eduIdx] = _education[eduIdx].copyWith(institution: val.trim());
                  },
                ),
                _buildTextField(
                  controller: degreeController,
                  label: 'Degree / Certificate',
                  onChanged: (val) {
                    _education[eduIdx] = _education[eduIdx].copyWith(degree: val.trim());
                  },
                ),
                _buildTextField(
                  controller: fieldController,
                  label: 'Field of Study (e.g. Computer Science)',
                  onChanged: (val) {
                    _education[eduIdx] = _education[eduIdx].copyWith(field: val.trim());
                  },
                ),
                _buildTextField(
                  controller: cgpaController,
                  label: 'CGPA / Percentage Score',
                  onChanged: (val) {
                    _education[eduIdx] = _education[eduIdx].copyWith(cgpa: val.trim());
                  },
                ),
                _buildTextField(
                  controller: durationController,
                  label: 'Duration (e.g. 2020 - 2024)',
                  onChanged: (val) {
                    _education[eduIdx] = _education[eduIdx].copyWith(duration: val.trim());
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final inst = instController.text.trim();
                      final deg = degreeController.text.trim();
                      final fld = fieldController.text.trim();
                      final cgp = cgpaController.text.trim();
                      final dur = durationController.text.trim();

                      setState(() {
                        _education[eduIdx] = ResumeEducation(
                          institution: inst,
                          degree: deg,
                          field: fld,
                          cgpa: cgp,
                          duration: dur,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Education details saved!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      'Save Record',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCBE349),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _education.add(const ResumeEducation(
                institution: 'New University', degree: 'Bachelor of Engineering', duration: ''));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Color(0xFFCBE349)),
              const SizedBox(width: 8),
              Text(
                'Add Education Entry',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        showCursor: true,
        cursorColor: Colors.white,
        cursorHeight: 16,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(suffixIcon, color: const Color(0xFFCBE349), size: 14),
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.015),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF723FFD)),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── SECTION 1: Personal Contact Info ─────────────────────────────
  Widget _buildPersonalInfoSection() {
    return _buildAccordionSection(
      title: 'Contact Details',
      icon: Icons.contact_mail_rounded,
      children: _buildPersonalInfoChildren(),
    );
  }

  // ── SECTION 2: Professional Summary ──────────────────────────────
  Widget _buildSummarySection() {
    return _buildAccordionSection(
      title: 'Professional Summary',
      icon: Icons.description_rounded,
      children: _buildSummaryChildren(),
    );
  }

  // ── SECTION 3: Skill Groups ──────────────────────────────────────
  Widget _buildSkillGroupsSection() {
    return _buildAccordionSection(
      title: 'Skills & Proficiencies',
      icon: Icons.psychology_rounded,
      children: _buildSkillGroupsChildren(),
    );
  }

  // ── SECTION 4: Experience ────────────────────────────────────────
  Widget _buildExperienceSection() {
    return _buildAccordionSection(
      title: 'Work / Training Experience',
      icon: Icons.work_rounded,
      children: _buildExperienceChildren(),
    );
  }

  // ── SECTION 5: Projects ──────────────────────────────────────────
  Widget _buildProjectsSection() {
    return _buildAccordionSection(
      title: 'Projects Portfolio',
      icon: Icons.code_rounded,
      children: _buildProjectsChildren(),
    );
  }

  // ── SECTION 6: Education ─────────────────────────────────────────
  Widget _buildEducationSection() {
    return _buildAccordionSection(
      title: 'Education History',
      icon: Icons.school_rounded,
      children: _buildEducationChildren(),
    );
  }

  Map<String, String> _parseCertDate(String dateStr) {
    dateStr = dateStr.trim();
    String month = 'Jan';
    String year = '2025';
    
    if (dateStr.isEmpty) {
      return {'month': month, 'year': year};
    }

    if (dateStr.contains("'")) {
      final parts = dateStr.split("'");
      if (parts.length == 2) {
        final mPart = parts[0].trim();
        final yPart = parts[1].trim();
        
        const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        for (final m in shortMonths) {
          if (m.toLowerCase() == mPart.toLowerCase()) {
            month = m;
            break;
          }
        }
        
        if (yPart.length == 2) {
          year = '20$yPart';
        } else if (yPart.length == 4) {
          year = yPart;
        }
      }
    } else {
      final parts = dateStr.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final mPart = parts[0].trim();
        final yPart = parts[1].trim();
        
        const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final matchLength = mPart.length >= 3 ? 3 : mPart.length;
        final matchPrefix = mPart.toLowerCase().substring(0, matchLength);
        for (final m in shortMonths) {
          if (m.toLowerCase().startsWith(matchPrefix)) {
            month = m;
            break;
          }
        }
        
        if (yPart.length == 4) {
          year = yPart;
        } else if (yPart.length == 2) {
          year = '20$yPart';
        }
      } else if (parts.length == 1) {
        final val = parts[0];
        if (val.length == 4 && int.tryParse(val) != null) {
          year = val;
        }
      }
    }
    return {'month': month, 'year': year};
  }

  // ── SECTION 7: Certifications ────────────────────────────────────
  Widget _buildCertificationsSection() {
    return _buildAccordionSection(
      title: 'Certifications',
      icon: Icons.verified_user_rounded,
      children: _buildCertificationsChildren(),
    );
  }



  // ── SECTION 8: Achievements & Awards ─────────────────────────────
  Widget _buildAchievementsSection() {
    return _buildAccordionSection(
      title: 'Achievements & Awards',
      icon: Icons.emoji_events_rounded,
      children: _buildAchievementsChildren(),
    );
  }



  Widget _buildResearchSection() {
    final projectsAsync = ref.watch(projectsProvider);

    return _buildAccordionSection(
      title: 'Research Work',
      icon: Icons.science_rounded,
      children: _buildResearchChildren(projectsAsync),
    );
  }
}
