import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../../core/constants/app_colors.dart';
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

class _ResumePreviewScreenState
    extends ConsumerState<ResumePreviewScreen> {
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
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '${_resume!.generatedResumeData!.name}\'s Resume',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              pdfFileName: '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base matching home screen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        title: const Text(
          'Resume Preview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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

          // 3. Volumetric Diagonal Light Leak / Spotlight beam
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

          // 4. Layered ambient purple glow layer for surrounding bloom
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

          // 5. Secondary soft blue highlight (extends center-right)
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

          // 6. Cinematic Blur overlay to blend layers into an immersive aurora bloom
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30), // Integrated background overlay
              ),
            ),
          ),

          // Main Layout Structure: Expanded scroll area and Sticky action buttons at bottom
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _resume == null
                  ? const Center(child: Text('Resume not found', style: TextStyle(color: Colors.white)))
                  : Column(
                      children: [
                        // Scrollable section for cards
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              children: [
                                // ATS Score + Missing Keywords Insights Card
                                if (_resume!.atsScore > 0) ...[
                                  _AtsInsightCard(resume: _resume!),
                                  const SizedBox(height: 16),
                                ],
                                
                                // Resume Document Card
                                Container(
                                  height: 520, // Fixed height inside scrollview to prevent layout constraints issues
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03), // theme matched card background
                                    borderRadius: BorderRadius.circular(28), // matched with home screen cards
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      // Custom PDF Header Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.description_outlined,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Resume Document',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                                ),
                                                child: const Text(
                                                  '1 / 1',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onSelected: (value) {
                                                  if (value == 'fullscreen') {
                                                    _showFullScreenResume();
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'fullscreen',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.fullscreen_rounded, color: Colors.black, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Full Screen Preview',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Actual PDF Preview Widget
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: InteractiveViewer(
                                            minScale: 1.0,
                                            maxScale: 3.0,
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
                                                child: CircularProgressIndicator(color: AppColors.accent),
                                              ),
                                              pdfFileName: '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Sticky Bottom Action Bar with matching theme buttons
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom: 24,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF07060F).withValues(alpha: 0.85),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: SafeArea(
                                child: Row(
                                  children: [
                                    // Regenerate Button (styled cleanly)
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          backgroundColor: Colors.white.withValues(alpha: 0.04),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30), // matched with home screen buttons
                                          ),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                                              SizedBox(width: 6),
                                              Text(
                                                'Regenerate',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Download Button (styled cleanly)
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isDownloading ? null : _downloadPdf,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          backgroundColor: Colors.green.withValues(alpha: 0.08),
                                          side: BorderSide(color: Colors.green.withValues(alpha: 0.25)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30), // matched with home screen buttons
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _isDownloading
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.green,
                                                      ),
                                                    )
                                                  : const Icon(Icons.file_download_outlined, color: Colors.green, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                _isDownloading ? '...' : 'Download',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Edit Resume Button (primary purple accent styled button)
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _navigateToEditScreen,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent, // vibrant purple color matching home screen
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30), // matched with home screen buttons
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit_rounded, size: 16),
                                              SizedBox(width: 6),
                                              Text(
                                                'Edit Resume',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
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

class _AtsInsightCard extends StatelessWidget {
  final ResumeModel resume;
  const _AtsInsightCard({required this.resume});

  Color get _scoreColor {
    if (resume.atsScore >= 80) return Colors.green.shade600;
    if (resume.atsScore >= 60) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  String get _ratingLabel {
    if (resume.atsScore >= 80) return 'Good';
    if (resume.atsScore >= 60) return 'Average';
    return 'Needs Work';
  }

  String get _ratingDesc {
    if (resume.atsScore >= 80) return 'Your resume is well-optimized but can be further improved.';
    if (resume.atsScore >= 60) return 'Your resume is decent but missing key elements to pass ATS.';
    return 'Your resume needs significant improvements to pass standard ATS filters.';
  }

  @override
  Widget build(BuildContext context) {
    final missing = resume.missingKeywords;
    final screenWidth = MediaQuery.of(context).size.width;
    final useVerticalLayout = screenWidth < 420;

    final leftGauge = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(
                  value: resume.atsScore / 100.0,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  color: _scoreColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${resume.atsScore}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _ratingLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _scoreColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _ratingDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.3,
          ),
        ),
      ],
    );

    final rightKeywords = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Missing Keywords',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 13,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add these keywords to improve your ATS score and visibility.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        if (missing.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: missing.map((kw) {
              return Container(
                constraints: BoxConstraints(maxWidth: screenWidth * 0.45),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20), // rounded pill badge
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      color: Colors.red.shade300,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        kw,
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No missing keywords! Your resume matches perfectly.',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.green.shade400,
              ),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03), // theme matched card background
        borderRadius: BorderRadius.circular(28), // matched with home screen cards
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ATS Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (useVerticalLayout) ...[
            Center(child: leftGauge),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            rightKeywords,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: leftGauge,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 1,
                  height: 130,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  flex: 5,
                  child: rightKeywords,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
