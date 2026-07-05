import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/resume_generator/domain/entities/resume_model.dart';
import '../../../../services/pdf/pdf_service.dart';
import '../../../../shared/providers/firebase_providers.dart';

class ResumePreviewScreen extends ConsumerStatefulWidget {
  final String resumeId;

  const ResumePreviewScreen({super.key, required this.resumeId});

  @override
  ConsumerState<ResumePreviewScreen> createState() =>
      _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends ConsumerState<ResumePreviewScreen> {
  bool _isDownloading = false;
  ResumeModel? _resume;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResume();
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
        setState(() {
          _resume = ResumeModel.fromFirestore(doc);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_resume?.generatedResumeData == null) return;
    setState(() => _isDownloading = true);

    try {
      final pdfService = PdfService();
      final pdfBytes = await pdfService.generatePdf(
        _resume!.generatedResumeData!,
        _resume!.templateUsed,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.pdfError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _navigateToEditScreen() async {
    if (_resume == null) return;
    final result = await context.push('/generate/edit/${widget.resumeId}');
    if (result == true && mounted) {
      setState(() => _loading = true);
      await _loadResume();
    }
  }

  void _showFullScreenResume() {
    if (_resume?.generatedResumeData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF07060F),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
            title: Text(
              '${_resume!.generatedResumeData!.name}\'s Resume',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
          ),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) => PdfService().generatePdf(
                _resume!.generatedResumeData!,
                _resume!.templateUsed,
              ),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              loadingWidget: const Center(
                child: CircularProgressIndicator(color: Color(0xFFCBE349)),
              ),
              pdfFileName:
                  '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Resolve template file name label
    String templateFileLabel = 'ats_professional.tpl';
    if (_resume != null) {
      templateFileLabel = '${_resume!.templateUsed.name.replaceAll(RegExp(r'(?=[A-Z])'), '_').toLowerCase()}.tpl';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          'Preview & Audit',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_resume != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                templateFileLabel,
                style: GoogleFonts.firaCode(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]
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

          // ── Content Area ──
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCBE349)))
              : _resume == null
                  ? Center(
                      child: Text(
                        'Resume not found',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ATS Audit / Insight Section
                                if (_resume!.atsScore > 0) ...[
                                  _AtsInsightSection(resume: _resume!),
                                  const SizedBox(height: 24),
                                ],

                                // Monospace Canvas Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.space_dashboard_outlined,
                                          color: Colors.white.withValues(alpha: 0.35),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'CANVAS PREVIEW',
                                          style: GoogleFonts.firaCode(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _showFullScreenResume,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.06),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.fullscreen_rounded,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Expand',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Figma/Framer style Document Canvas
                                Container(
                                  height: 540,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0C0B12), // Darker slate workspace background
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 28,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: PdfPreview(
                                      build: (format) => PdfService().generatePdf(
                                        _resume!.generatedResumeData!,
                                        _resume!.templateUsed,
                                      ),
                                      allowPrinting: false,
                                      allowSharing: false,
                                      canChangePageFormat: false,
                                      canChangeOrientation: false,
                                      canDebug: false,
                                      loadingWidget: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFCBE349),
                                        ),
                                      ),
                                      pdfFileName:
                                          '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Floating Glass Action Bar
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                20, 16, 20,
                                MediaQuery.of(context).padding.bottom + 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF07060F).withValues(alpha: 0.75),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Regenerate (Outlined dark button)
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.restart_alt_rounded,
                                                  color: Colors.white70,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Regenerate',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Download (frosted green pill)
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: _isDownloading ? null : _downloadPdf,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _isDownloading
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.file_download_outlined,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Download',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Edit Resume (Premium Lime CTA)
                                  Expanded(
                                    flex: 4,
                                    child: GestureDetector(
                                      onTap: _navigateToEditScreen,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCBE349),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFCBE349)
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.edit_note_rounded,
                                                  color: Color(0xFF07060F),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Edit Content',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF07060F),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
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
                            ),
                          ),
                        ),

                      ],
                    ),
        ],
      ),
    );
  }
}

// ── ATS Insight Section ────────────────────────────────────

class _AtsInsightSection extends StatelessWidget {
  final ResumeModel resume;

  const _AtsInsightSection({required this.resume});

  Color get _scoreColor {
    if (resume.atsScore >= 80) return const Color(0xFF10B981);
    if (resume.atsScore >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _ratingLabel {
    if (resume.atsScore >= 80) return 'Optimized';
    if (resume.atsScore >= 60) return 'Average Match';
    return 'Weak Match';
  }

  String get _ratingDesc {
    if (resume.atsScore >= 80) {
      return 'Excellent keyword match. Highly parseable and optimized for corporate ATS screening filters.';
    }
    if (resume.atsScore >= 60) {
      return 'Contains core qualifications, but lacks several highly relevant target role keywords.';
    }
    return 'Low compatibility. Add suggested industry keywords to prevent automatic ATS rejection.';
  }

  @override
  Widget build(BuildContext context) {
    final missing = resume.missingKeywords;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 580;

    final headerRow = Row(
      children: [
        Icon(
          Icons.analytics_outlined,
          color: Colors.white.withValues(alpha: 0.35),
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(
          'ATS AUDIT REPORT',
          style: GoogleFonts.firaCode(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    final scoreDisplay = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Radial gauge
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: CircularProgressIndicator(
                    value: resume.atsScore / 100.0,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    color: _scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${resume.atsScore}%',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _scoreColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _ratingLabel.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: _scoreColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _ratingDesc,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final keywordsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Missing Suggested Keywords',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 13,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (missing.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: missing.map((kw) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Color(0xFFF87171),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      kw,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFCA5A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Text(
            '✓ Perfect keyword matching. No critical missing terms detected.',
            style: GoogleFonts.outfit(
              color: const Color(0xFF10B981),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: scoreDisplay),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      width: 1,
                      height: 110,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    Expanded(flex: 10, child: keywordsSection),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scoreDisplay,
                    const SizedBox(height: 18),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 16),
                    keywordsSection,
                  ],
                ),
        ),
      ],
    );
  }
}
