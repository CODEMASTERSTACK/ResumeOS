import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../services/pdf/pdf_service.dart';
import '../../domain/entities/resume_model.dart';

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
  List<ResumeCertification> _certifications = [];
  List<String> _achievements = [];

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
    super.dispose();
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
            _certifications = List<ResumeCertification>.from(data.certifications);
            _achievements = List<String>.from(data.achievements);

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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Insert Link Asset',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Link Title (e.g. GitHub, Project Link, Credential)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL Link',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
                // Place cursor at the end of the newly inserted text
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: cursorPosition >= 0 ? cursorPosition + linkStr.length : newText.length),
                );
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Insert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Edit & Format Resume',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveResume,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _resumeData == null
              ? const Center(child: Text('Failed to load resume details', style: TextStyle(color: AppColors.textPrimary)))
              : Column(
                  children: [
                    // Sticky top styling toolkit
                    _buildStyleToolkit(),
                    
                    // Sliding segment switch between Form fields and Live high-fidelity PDF preview!
                    _buildToggleRow(),
                    
                    const Divider(height: 1, color: AppColors.divider),
                    
                    // Main editor content or high-fidelity Live PDF page
                    Expanded(
                      child: _showLivePreview
                          ? _buildLivePdfPreview()
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: Column(
                                children: [
                                  _buildPersonalInfoSection(),
                                  const SizedBox(height: 14),
                                  _buildSummarySection(),
                                  const SizedBox(height: 14),
                                  _buildSkillGroupsSection(),
                                  const SizedBox(height: 14),
                                  _buildExperienceSection(),
                                  const SizedBox(height: 14),
                                  _buildProjectsSection(),
                                  const SizedBox(height: 14),
                                  _buildEducationSection(),
                                  const SizedBox(height: 14),
                                  _buildCertificationsSection(),
                                  const SizedBox(height: 14),
                                  _buildAchievementsSection(),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  // ── Toggle Switch Widget ──────────────────────────────
  Widget _buildToggleRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildToggleButton(
              label: 'Live PDF Preview',
              isActive: _showLivePreview,
              icon: Icons.picture_as_pdf_rounded,
              onTap: () {
                // Dimiss keyboard before toggling to preview
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
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.white : AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.textSecondary,
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
      certifications: _certifications,
      achievements: _achievements,
      primaryColorHex: _selectedColorHex,
      fontFamily: _selectedFontFamily,
      fontSizeScale: _selectedFontSizeScale,
    );

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(8),
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
        loadingWidget: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        pdfFileName: 'Resume_Preview.pdf',
      ),
    );
  }

  // ── Style Customizer Widget Toolkit ──────────────────────────────
  Widget _buildStyleToolkit() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Resume Visual Theme Engine',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Accent Color Choice Row
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
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
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? color : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Font selection dropdown or horizontal list
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Typography Font Style',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableFonts.length,
                        itemBuilder: (context, idx) {
                          final f = _availableFonts[idx];
                          final value = f['value']!;
                          final label = f['label']!;
                          final isSelected = _selectedFontFamily == value;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedFontFamily = value),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
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
              const SizedBox(width: 16),
              // Font size scale selector
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Size Multiplier (${(_selectedFontSizeScale * 100).toInt()}%)',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildSizeOption('90%', 0.9),
                        const SizedBox(width: 6),
                        _buildSizeOption('100%', 1.0),
                        const SizedBox(width: 6),
                        _buildSizeOption('110%', 1.1),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
            color: isSelected ? AppColors.accent : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textSecondary,
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
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.accent, size: 20),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        collapsedIconColor: AppColors.textSecondary,
        iconColor: AppColors.accent,
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          suffixIcon: suffixIcon != null
              ? IconButton(
                  icon: Icon(suffixIcon, color: AppColors.accent, size: 18),
                  onPressed: onSuffixTap,
                )
              : null,
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(
          color: AppColors.textPrimary,
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
      children: [
        _buildTextField(controller: _nameController, label: 'Full Name'),
        _buildTextField(controller: _emailController, label: 'Email Address'),
        _buildTextField(controller: _phoneController, label: 'Phone / Mobile'),
        _buildTextField(controller: _locationController, label: 'Location (e.g. Pune, India)'),
        _buildTextField(controller: _githubController, label: 'GitHub Profile URL'),
        _buildTextField(controller: _linkedinController, label: 'LinkedIn Profile URL'),
        _buildTextField(controller: _portfolioController, label: 'LeetCode / Portfolio URL'),
      ],
    );
  }

  // ── SECTION 2: Professional Summary ──────────────────────────────
  Widget _buildSummarySection() {
    return _buildAccordionSection(
      title: 'Professional Summary',
      icon: Icons.description_rounded,
      children: [
        _buildTextField(
          controller: _summaryController,
          label: 'Executive Summary',
          maxLines: 5,
        ),
      ],
    );
  }

  // ── SECTION 3: Skill Groups ──────────────────────────────────────
  Widget _buildSkillGroupsSection() {
    return _buildAccordionSection(
      title: 'Skills & Proficiencies',
      icon: Icons.psychology_rounded,
      children: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category #${sIdx + 1}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          setState(() => _skillGroups.removeAt(sIdx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                      final sks = val.split(',')
                          .map((s) => s.trim())
                          .toList();
                      _skillGroups[sIdx] = _skillGroups[sIdx].copyWith(skills: sks);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        final cats = categoryController.text.trim();
                        final sks = skillsController.text.split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        setState(() {
                          _skillGroups[sIdx] = ResumeSkillGroup(category: cats, skills: sks);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Skill Category saved!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _skillGroups.add(const ResumeSkillGroup(category: 'New Category', skills: []));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Skill Category'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── SECTION 4: Experience ────────────────────────────────────────
  Widget _buildExperienceSection() {
    return _buildAccordionSection(
      title: 'Work / Training Experience',
      icon: Icons.work_rounded,
      children: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Experience Position #${eIdx + 1}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          setState(() => _experience.removeAt(eIdx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 6),
                  const Text('Description Bullet Points', style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  ...List.generate(_experience[eIdx].bullets.length, (bIdx) {
                    final bulletController = TextEditingController(text: _experience[eIdx].bullets[bIdx]);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: bulletController,
                                onChanged: (value) {
                                  final updatedBullets = List<String>.from(_experience[eIdx].bullets);
                                  updatedBullets[bIdx] = value;
                                  _experience[eIdx] = _experience[eIdx].copyWith(bullets: updatedBullets);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Bullet #${bIdx + 1}',
                                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.link_rounded, color: AppColors.accent, size: 18),
                                    onPressed: () async {
                                      await _showAttachLinkDialog(bulletController);
                                      final updatedBullets = List<String>.from(_experience[eIdx].bullets);
                                      updatedBullets[bIdx] = bulletController.text;
                                      setState(() {
                                        _experience[eIdx] = _experience[eIdx].copyWith(bullets: updatedBullets);
                                      });
                                    },
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.border),
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.accent),
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                            onPressed: () {
                              final updatedBullets = List<String>.from(_experience[eIdx].bullets)..removeAt(bIdx);
                              setState(() {
                                _experience[eIdx] = _experience[eIdx].copyWith(bullets: updatedBullets);
                              });
                            },
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
                          final updatedBullets = List<String>.from(_experience[eIdx].bullets)..add('');
                          setState(() {
                            _experience[eIdx] = _experience[eIdx].copyWith(bullets: updatedBullets);
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add Bullet', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                      TextButton(
                        onPressed: () {
                          // Sync input fields to current list item
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
                            const SnackBar(content: Text('Experience details saved!'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _experience.add(const ResumeExperience(company: 'New Company', role: 'Developer', duration: '', bullets: ['']));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Experience Position'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── SECTION 5: Projects ──────────────────────────────────────────
  Widget _buildProjectsSection() {
    return _buildAccordionSection(
      title: 'Projects Portfolio',
      icon: Icons.code_rounded,
      children: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Project #${pIdx + 1}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          setState(() => _projects.removeAt(pIdx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                      final tech = val.split(',')
                          .map((t) => t.trim())
                          .toList();
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
                  const SizedBox(height: 6),
                  const Text('Project Highlights Bullets (Max 2 recommended, 3rd will be generated as Link)', 
                    style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  ...List.generate(_projects[pIdx].bullets.length, (bIdx) {
                    final bulletController = TextEditingController(text: _projects[pIdx].bullets[bIdx]);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: bulletController,
                              label: 'Bullet #${bIdx + 1}',
                              suffixIcon: Icons.link_rounded,
                              onSuffixTap: () async {
                                await _showAttachLinkDialog(bulletController);
                                final updatedBullets = List<String>.from(_projects[pIdx].bullets);
                                updatedBullets[bIdx] = bulletController.text;
                                setState(() {
                                  _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                                });
                              },
                              onChanged: (value) {
                                final updatedBullets = List<String>.from(_projects[pIdx].bullets);
                                updatedBullets[bIdx] = value;
                                _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                            onPressed: () {
                              final updatedBullets = List<String>.from(_projects[pIdx].bullets)..removeAt(bIdx);
                              setState(() {
                                _projects[pIdx] = _projects[pIdx].copyWith(bullets: updatedBullets);
                              });
                            },
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
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add Highlight Bullet', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                      TextButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final tech = techController.text.split(',')
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
                            const SnackBar(content: Text('Project details saved!'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _projects.add(const ResumeProject(title: 'New Project', technologies: [], bullets: [''], githubUrl: '', liveUrl: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Project Record'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── SECTION 6: Education ─────────────────────────────────────────
  Widget _buildEducationSection() {
    return _buildAccordionSection(
      title: 'Education History',
      icon: Icons.school_rounded,
      children: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Education Record #${eduIdx + 1}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          setState(() => _education.removeAt(eduIdx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                          const SnackBar(content: Text('Education details saved!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _education.add(const ResumeEducation(institution: 'New University', degree: 'Bachelor of Engineering', duration: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Education Entry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── SECTION 7: Certifications ────────────────────────────────────
  Widget _buildCertificationsSection() {
    return _buildAccordionSection(
      title: 'Certifications',
      icon: Icons.verified_user_rounded,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _certifications.length,
          itemBuilder: (context, certIdx) {
            final cert = _certifications[certIdx];
            final titleController = TextEditingController(text: cert.title);
            final issuerController = TextEditingController(text: cert.issuer);
            final dateController = TextEditingController(text: cert.date);
            final urlController = TextEditingController(text: cert.credentialUrl);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Certification #${certIdx + 1}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          setState(() => _certifications.removeAt(certIdx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: titleController,
                    label: 'Certificate Title',
                    onChanged: (val) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(title: val.trim());
                    },
                  ),
                  _buildTextField(
                    controller: issuerController,
                    label: 'Issuing Authority / Issuer',
                    onChanged: (val) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(issuer: val.trim());
                    },
                  ),
                  _buildTextField(
                    controller: dateController,
                    label: 'Date Earned / Expiry',
                    onChanged: (val) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(date: val.trim());
                    },
                  ),
                  _buildTextField(
                    controller: urlController,
                    label: 'Credential Verification URL',
                    onChanged: (val) {
                      _certifications[certIdx] = _certifications[certIdx].copyWith(credentialUrl: val.trim());
                    },
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        final tit = titleController.text.trim();
                        final iss = issuerController.text.trim();
                        final dat = dateController.text.trim();
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
                          const SnackBar(content: Text('Certification details saved!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _certifications.add(const ResumeCertification(title: 'New Certificate', issuer: '', date: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Certification Record'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── SECTION 8: Achievements ──────────────────────────────────────
  Widget _buildAchievementsSection() {
    return _buildAccordionSection(
      title: 'Achievements & Awards',
      icon: Icons.emoji_events_rounded,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _achievements.length,
          itemBuilder: (context, aIdx) {
            final bulletController = TextEditingController(text: _achievements[aIdx]);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: bulletController,
                      label: 'Achievement #${aIdx + 1}',
                      suffixIcon: Icons.link_rounded,
                      onSuffixTap: () async {
                        await _showAttachLinkDialog(bulletController);
                        setState(() {
                          _achievements[aIdx] = bulletController.text;
                        });
                      },
                      onChanged: (value) {
                        _achievements[aIdx] = value;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                    onPressed: () {
                      setState(() => _achievements.removeAt(aIdx));
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _achievements.add(''));
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Achievement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Achievements saved!'), duration: Duration(seconds: 1)),
                );
              },
              child: const Text('Save', style: TextStyle(color: AppColors.success, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
