import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiResumeCraftingOverlay extends StatefulWidget {
  final String candidateName;
  final String jobRole;
  final List<String> keywords;
  final List<String> projectNames;
  final String templateName;
  final bool isGenerating;
  final bool isGenerationFinished;
  final VoidCallback? onComplete;

  const AiResumeCraftingOverlay({
    super.key,
    required this.candidateName,
    required this.jobRole,
    required this.keywords,
    required this.projectNames,
    required this.templateName,
    required this.isGenerating,
    required this.isGenerationFinished,
    this.onComplete,
  });

  @override
  State<AiResumeCraftingOverlay> createState() => _AiResumeCraftingOverlayState();
}

class _AiResumeCraftingOverlayState extends State<AiResumeCraftingOverlay> {
  double _progress = 0.0;
  Timer? _progressTimer;
  String _activeStatus = 'Initializing...';
  
  // Entrance animation states
  double _canvasScale = 0.9;
  double _canvasOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Entrance animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _canvasScale = 1.0;
          _canvasOpacity = 1.0;
        });
      }
    });

    // Smooth progress simulation running every 50ms (for 60fps feel)
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        final isFinished = widget.isGenerationFinished;

        if (isFinished) {
          // Accelerate progress smoothly to 100% when generation completes
          _progress += 2.5;
          _activeStatus = _progress < 98 ? 'Finalizing PDF Layout...' : 'Ready!';
        } else {
          // Continuous, smooth non-linear progression that never gets stuck
          if (_progress < 18) {
            _progress += 0.45;
            _activeStatus = 'Writing Resume Header...';
          } else if (_progress < 38) {
            _progress += 0.35;
            _activeStatus = 'Drafting Professional Summary...';
          } else if (_progress < 60) {
            _progress += 0.25;
            _activeStatus = 'Structuring Work Experience...';
          } else if (_progress < 75) {
            _progress += 0.20;
            _activeStatus = 'Formatting Education & Degrees...';
          } else if (_progress < 86) {
            _progress += 0.16;
            _activeStatus = 'Writing STAR Project Bullets...';
          } else if (_progress < 93) {
            _progress += 0.10;
            _activeStatus = 'Injecting ATS Keywords & Skills...';
          } else if (_progress < 98.5) {
            // Smooth non-stopping decay: continuously moves forward without getting stuck
            final remaining = 99.0 - _progress;
            _progress += (remaining * 0.02).clamp(0.015, 0.06);
            if (_progress < 96) {
              _activeStatus = 'Optimizing Document Hierarchy & Spacing...';
            } else {
              _activeStatus = 'Compiling ATS-Compliant Layout...';
            }
          }
          if (_progress > 98.5) _progress = 98.5;
        }

        if (_progress >= 100.0) {
          _progress = 100.0;
          _progressTimer?.cancel();
          // Delay briefly for visual satisfaction before triggering redirect
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              widget.onComplete?.call();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  // Smooth Y-coordinate tracking for the laser line
  double _getLaserY() {
    if (_progress < 15) {
      return 20 + (_progress / 15) * 45;
    } else if (_progress < 35) {
      final pct = (_progress - 15) / 20;
      return 75 + pct * 50;
    } else if (_progress < 60) {
      final pct = (_progress - 35) / 25;
      return 140 + pct * 90;
    } else if (_progress < 75) {
      final pct = (_progress - 60) / 15;
      return 245 + pct * 50;
    } else if (_progress < 88) {
      final pct = (_progress - 75) / 13;
      return 310 + pct * 70;
    } else {
      final pct = (_progress - 88) / 12;
      return 395 + pct.clamp(0.0, 1.0) * 30;
    }
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        height: 0.5,
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildMiniTextLine({double widthFactor = 1.0, double height = 3.5}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3.5),
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(1.5),
      ),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Resolve name & role
    final name = widget.candidateName.isNotEmpty ? widget.candidateName : 'John Doe';
    final role = widget.jobRole.isNotEmpty ? widget.jobRole : 'Software Engineer';

    // Resolve project list
    final projects = widget.projectNames.isNotEmpty 
        ? widget.projectNames.take(2).toList() 
        : ['Smart Portfolio Hub', 'Cloud Storage Platform'];

    return Stack(
      children: [
        // Premium Dark Blur overlay background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: const Color(0xFF07060F).withValues(alpha: 0.92),
            ),
          ),
        ),

        // Floating ambient neon blobs with gentle pulsing
        RepaintBoundary(
          child: Stack(
            children: [
              Positioned(
                top: screenHeight * 0.15,
                left: -60,
                width: 320,
                height: 320,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF723FFD).withValues(alpha: 0.14),
                  ),
                ),
              ),
              Positioned(
                bottom: screenHeight * 0.15,
                right: -60,
                width: 320,
                height: 320,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEC53B0).withValues(alpha: 0.09),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Center UI
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and dynamic status description
                Text(
                  _activeStatus,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Progress percent badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF723FFD).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF723FFD).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'AI GENERATION IN PROGRESS • ${_progress.toInt()}%',
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFFCBE349),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // ── The A4 White Paper Canvas ───────────────────────────
                AnimatedScale(
                  scale: _canvasScale,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _canvasOpacity,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      width: 310,
                      height: 440,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Trailing Glow scanner highlight (Aura effect that trails behind the laser)
                          if (_progress < 99)
                            Positioned(
                              top: 15,
                              left: 15,
                              right: 15,
                              height: (_getLaserY() - 10).clamp(0.0, 410.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF723FFD).withValues(alpha: 0.015),
                                      const Color(0xFF723FFD).withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Paper background fine lines (representing margin structure)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Header (0% - 15%)
                                AnimatedSlide(
                                  offset: _progress >= 2 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 2 ? 1.0 : 0.05,
                                    duration: const Duration(milliseconds: 300),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF111111),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          role,
                                          style: GoogleFonts.outfit(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF723FFD),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Contacts skeleton line
                                        _buildMiniTextLine(widthFactor: 0.8, height: 3.0),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSectionDivider(),

                                // 2. Summary (15% - 35%)
                                AnimatedSlide(
                                  offset: _progress >= 15 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 15 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 400),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PROFESSIONAL SUMMARY',
                                          style: GoogleFonts.outfit(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1A1A1A),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildMiniTextLine(widthFactor: 1.0),
                                        _buildMiniTextLine(widthFactor: 0.95),
                                        _buildMiniTextLine(widthFactor: 0.7),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSectionDivider(),

                                // 3. Work Experience (35% - 60%)
                                AnimatedSlide(
                                  offset: _progress >= 35 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 35 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 450),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'WORK EXPERIENCE',
                                          style: GoogleFonts.outfit(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1A1A1A),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        // Job 1
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Senior Software Engineer',
                                              style: GoogleFonts.outfit(
                                                fontSize: 6,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF222222),
                                              ),
                                            ),
                                            Text(
                                              '2024 - Present',
                                              style: GoogleFonts.outfit(
                                                fontSize: 5.5,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        _buildMiniTextLine(widthFactor: 0.98),
                                        _buildMiniTextLine(widthFactor: 0.92),
                                        const SizedBox(height: 6),
                                        // Job 2
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Software Developer',
                                              style: GoogleFonts.outfit(
                                                fontSize: 6,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF222222),
                                              ),
                                            ),
                                            Text(
                                              '2022 - 2024',
                                              style: GoogleFonts.outfit(
                                                fontSize: 5.5,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        _buildMiniTextLine(widthFactor: 0.95),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSectionDivider(),

                                // 4. Education (60% - 75%)
                                AnimatedSlide(
                                  offset: _progress >= 60 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 60 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 450),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'EDUCATION',
                                          style: GoogleFonts.outfit(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1A1A1A),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Bachelor of Science in Computer Science',
                                              style: GoogleFonts.outfit(
                                                fontSize: 6,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF222222),
                                              ),
                                            ),
                                            Text(
                                              'GPA: 3.8/4.0',
                                              style: GoogleFonts.outfit(
                                                fontSize: 5.5,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        _buildMiniTextLine(widthFactor: 0.4, height: 3.0),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSectionDivider(),

                                // 5. Projects (75% - 90%)
                                AnimatedSlide(
                                  offset: _progress >= 75 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 75 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 450),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SELECTED PROJECTS',
                                          style: GoogleFonts.outfit(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1A1A1A),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: List.generate(projects.length, (idx) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    projects[idx],
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 6.0,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF222222),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  _buildMiniTextLine(widthFactor: 0.95),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildSectionDivider(),

                                // 6. Skills (90% - 98%)
                                AnimatedSlide(
                                  offset: _progress >= 90 ? Offset.zero : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: _progress >= 90 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 450),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TECHNICAL SKILLS',
                                          style: GoogleFonts.outfit(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1A1A1A),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: List.generate(
                                            widget.keywords.isNotEmpty 
                                                ? widget.keywords.take(6).length 
                                                : 5, 
                                            (idx) {
                                              final label = widget.keywords.isNotEmpty 
                                                  ? widget.keywords[idx] 
                                                  : ['Flutter', 'Dart', 'Firebase', 'APIs', 'Docker'][idx];
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  label,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 5.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF4F46E5),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Glowing Laser Scanline (Repaint isolated for high performance)
                          if (_progress < 99.8)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 50),
                              curve: Curves.easeInOut,
                              top: _getLaserY(),
                              left: 8,
                              right: 8,
                              child: RepaintBoundary(
                                child: Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    // Main glowing beam bar
                                    Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF723FFD),
                                            Color(0xFFEC53B0),
                                            Color(0xFFCBE349),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF723FFD).withValues(alpha: 0.95),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Bright scan cursor dot
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFCBE349),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFFCBE349),
                                            blurRadius: 12,
                                            spreadRadius: 4,
                                          ),
                                        ],
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
                ),
                const SizedBox(height: 44),

                // Footer layout progress tracker
                Container(
                  width: 310,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFCBE349),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _progress < 96 
                              ? ' Structuring & optimizing resume...'
                              : 'Compiling premium resume...',
                              
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
      ],
    );
  }
}
