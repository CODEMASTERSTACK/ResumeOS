import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────
// Resume Guide Screen
// Opens as a full page when the user taps a "Know the Resume"
// category card on the dashboard.
// ─────────────────────────────────────────────────────────────

class ResumeGuideScreen extends StatefulWidget {
  /// 'technical' or 'non_technical'
  final String type;

  const ResumeGuideScreen({super.key, required this.type});

  @override
  State<ResumeGuideScreen> createState() => _ResumeGuideScreenState();
}

class _ResumeGuideScreenState extends State<ResumeGuideScreen> {
  int _selectedTabIndex = 0;

  bool get _isTechnical => widget.type == 'technical';

  List<_GuideSection> _getFilteredSections(int tabIndex, _GuideData guide) {
    if (_isTechnical) {
      switch (tabIndex) {
        case 0: // ATS & Keywords
          return [guide.sections[0], guide.sections[1]];
        case 1: // Structure
          return [guide.sections[2], guide.sections[4]];
        case 2: // Metrics & Format
          return [guide.sections[3], guide.sections[5]];
        case 3: // Mistakes
          return [guide.sections[6]];
        default:
          return [];
      }
    } else {
      switch (tabIndex) {
        case 0: // ATS & Keywords
          return [guide.sections[0], guide.sections[1]];
        case 1: // Structure & Pitch
          return [guide.sections[2], guide.sections[4], guide.sections[5]];
        case 2: // Metrics & Format
          return [guide.sections[3], guide.sections[6]];
        case 3: // Mistakes
          return [guide.sections[7]];
        default:
          return [];
      }
    }
  }

  List<String> get _tabTitles => [
        'ATS & Keywords',
        'Structure',
        'Metrics',
        'Mistakes',
      ];

  List<IconData> get _tabIcons => [
        Icons.psychology_alt_rounded,
        Icons.layers_rounded,
        Icons.insights_rounded,
        Icons.warning_amber_rounded,
      ];

  @override
  Widget build(BuildContext context) {
    final guide = _isTechnical ? _technicalGuide : _nonTechnicalGuide;
    final filteredSections = _getFilteredSections(_selectedTabIndex, guide);

    return Scaffold(
      backgroundColor: const Color(0xFF06050A),
      body: Stack(
        children: [
          // ── Cyber Grid Background ──
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(gridColor: guide.accentColor),
            ),
          ),

          // ── Ambient glows ──
          Positioned(
            top: -120,
            left: -120,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    guide.accentColor.withValues(alpha: 0.15),
                    guide.accentColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            right: -100,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF723FFD).withValues(alpha: 0.10),
                    const Color(0xFF723FFD).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    guide.accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                _AppBar(guide: guide),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _HeroBanner(guide: guide),
                      _CategoryTabs(
                        selectedIndex: _selectedTabIndex,
                        tabTitles: _tabTitles,
                        tabIcons: _tabIcons,
                        accentColor: guide.accentColor,
                        onTabSelected: (idx) {
                          setState(() {
                            _selectedTabIndex = idx;
                          });
                        },
                      ),
                      // Animated Switcher for smooth tab transitions
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Column(
                          key: ValueKey<int>(_selectedTabIndex),
                          children: filteredSections
                              .map((s) => _SectionCard(section: s, accent: guide.accentColor))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _GenerateCTA(accentColor: guide.accentColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-Widgets
// ─────────────────────────────────────────────────────────────

class _CyberGridPainter extends CustomPainter {
  final Color gridColor;

  _CyberGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Gradient that fades out vertically
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gridColor.withValues(alpha: 0.08),
        gridColor.withValues(alpha: 0.03),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    const spacing = 35.0;
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppBar extends StatelessWidget {
  final _GuideData guide;
  const _AppBar({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              guide.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: guide.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: guide.accentColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              guide.badge,
              style: TextStyle(
                color: guide.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final _GuideData guide;
  const _HeroBanner({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            guide.accentColor.withValues(alpha: 0.12),
            guide.accentColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: guide.accentColor.withValues(alpha: 0.20)),
      ),
      child: Stack(
        children: [
          // Graphic abstract light
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.05,
              child: Icon(
                guide.heroIcon,
                size: 130,
                color: guide.accentColor,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: guide.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: guide.accentColor.withValues(alpha: 0.3), width: 1.0),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: guide.accentColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI INSIGHT MATRIX',
                      style: TextStyle(
                        color: guide.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.heroTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      guide.heroSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.5,
                      ),
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
}

class _CategoryTabs extends StatelessWidget {
  final int selectedIndex;
  final List<String> tabTitles;
  final List<IconData> tabIcons;
  final Color accentColor;
  final ValueChanged<int> onTabSelected;

  const _CategoryTabs({
    required this.selectedIndex,
    required this.tabTitles,
    required this.tabIcons,
    required this.accentColor,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C).withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: List.generate(tabTitles.length, (idx) {
          final isSelected = selectedIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.25)
                        : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabIcons[idx],
                        color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.45),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabTitles[idx].split(' ').first, // Just show first word on small width
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.50),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _GuideSection section;
  final Color accent;

  const _SectionCard({required this.section, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF13111C).withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Glowing Left Bar indicator
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: accent, width: 3.5),
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1.0),
                      ),
                      child: Icon(section.icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.intro != null) ...[
                      Text(
                        section.intro!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Points list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: section.points.length,
                      itemBuilder: (context, idx) {
                        return _BulletPoint(
                          point: section.points[idx],
                          accent: accent,
                          index: idx,
                        );
                      },
                    ),

                    if (section.proTip != null) ...[
                      const SizedBox(height: 8),
                      _ProTip(tip: section.proTip!, accent: accent),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final _GuidePoint point;
  final Color accent;
  final int index;

  const _BulletPoint({
    required this.point,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final String cleanBody;
    final String? statusIcon; // 'check', 'cross', or null
    
    final bodyTrimmed = point.body.trim();
    if (bodyTrimmed.startsWith('✅')) {
      statusIcon = 'check';
      cleanBody = bodyTrimmed.substring(1).trim();
    } else if (bodyTrimmed.startsWith('❌')) {
      statusIcon = 'cross';
      cleanBody = bodyTrimmed.substring(1).trim();
    } else {
      statusIcon = null;
      cleanBody = point.body;
    }

    Widget indicator;
    if (statusIcon == 'check') {
      indicator = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Center(
          child: Icon(
            Icons.check_rounded,
            color: Color(0xFF10B981),
            size: 11,
          ),
        ),
      );
    } else if (statusIcon == 'cross') {
      indicator = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Center(
          child: Icon(
            Icons.close_rounded,
            color: Color(0xFFEF4444),
            size: 11,
          ),
        ),
      );
    } else {
      // High-tech Index Number: "01", "02"
      final indexStr = (index + 1).toString().padLeft(2, '0');
      indicator = Text(
        indexStr,
        style: TextStyle(
          color: accent.withValues(alpha: 0.8),
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: SizedBox(
              width: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: indicator,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (point.label != null) ...[
                  Text(
                    point.label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  cleanBody,
                  style: TextStyle(
                    color: statusIcon == 'check'
                        ? const Color(0xFFD1FAE5)
                        : statusIcon == 'cross'
                            ? const Color(0xFFFEE2E2)
                            : Colors.white.withValues(alpha: 0.70),
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: (statusIcon != null) ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProTip extends StatelessWidget {
  final String tip;
  final Color accent;

  const _ProTip({required this.tip, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'AI INSIGHT',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tip,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateCTA extends StatelessWidget {
  final Color accentColor;
  const _GenerateCTA({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.16),
            accentColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.0),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready to Compile?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deploy the guidance model to our AI generator and render an ATS-compliant PDF resume in seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => context.go('/generate'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'INITIATE GENERATOR',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.black.withValues(alpha: 0.8), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────

class _GuideData {
  final String title;
  final String badge;
  final Color accentColor;
  final IconData heroIcon;
  final String heroTitle;
  final String heroSubtitle;
  final List<_GuideSection> sections;

  const _GuideData({
    required this.title,
    required this.badge,
    required this.accentColor,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.sections,
  });
}

class _GuideSection {
  final String title;
  final IconData icon;
  final String? intro;
  final List<_GuidePoint> points;
  final String? proTip;

  const _GuideSection({
    required this.title,
    required this.icon,
    this.intro,
    required this.points,
    this.proTip,
  });
}

class _GuidePoint {
  final String? label;
  final String body;

  const _GuidePoint({this.label, required this.body});
}

// ─────────────────────────────────────────────────────────────
// Guide Content
// ─────────────────────────────────────────────────────────────

const _technicalGuide = _GuideData(
  title: 'Technical Resume Guide',
  badge: '⚙️ Tech',
  accentColor: const Color(0xFFCBE349),
  heroIcon: Icons.code_rounded,
  heroTitle: 'MASTER YOUR TECHNICAL RESUME',
  heroSubtitle:
      'Engineers, developers, and data professionals need a resume that speaks the language of recruiters AND machines (ATS). This guide covers everything.',

  sections: [
    _GuideSection(
      title: 'ATS — How Machines Read Your Resume',
      icon: Icons.computer_rounded,
      intro:
          'Over 90% of large companies use Applicant Tracking Systems (ATS) to filter resumes before a human ever reads them. Failing the ATS means automatic rejection — regardless of your skills.',
      points: [
        _GuidePoint(label: 'Use a single-column or two-column layout',
            body: 'Avoid complex tables, text boxes, headers/footers, and graphics — ATS parsers skip them entirely.'),
        _GuidePoint(label: 'Stick to standard section headings',
            body: '"Work Experience", "Education", "Skills" — not creative alternatives like "My Journey" or "Expertise Hub".'),
        _GuidePoint(label: 'Save as .docx or ATS-safe PDF',
            body: 'Use standard fonts (Arial, Calibri, Times New Roman). Avoid fancy PDFs with embedded objects.'),
        _GuidePoint(label: 'No images or icons',
            body: 'ATS cannot read embedded photos, profile pictures, or icon-based skill bars.'),
      ],
      proTip:
          'Always paste your resume into a plain text editor (Notepad). If it reads cleanly with no garbled text, your ATS compatibility is strong.',
    ),

    _GuideSection(
      title: 'Keywords — The Secret to Getting Found',
      icon: Icons.search_rounded,
      intro:
          'ATS systems rank candidates by keyword density. Your resume must reflect the exact language in the job description.',
      points: [
        _GuidePoint(label: 'Mirror the job description',
            body: 'If the JD says "REST API development", use those exact words — not "API integration" or "web services".'),
        _GuidePoint(label: 'Include both acronyms and full forms',
            body: 'Write "Machine Learning (ML)" and "Natural Language Processing (NLP)" at least once each.'),
        _GuidePoint(label: 'List specific technologies',
            body: 'React.js, Node.js, PostgreSQL, Docker, Kubernetes, AWS Lambda — name them explicitly in your skills section.'),
        _GuidePoint(label: 'Use action verbs',
            body: '"Architected", "Implemented", "Optimized", "Automated", "Deployed" — not generic verbs like "did" or "worked on".'),
      ],
      proTip:
          'Use a tool like Jobscan or Word Cloud to compare your resume keywords against the job description before applying.',
    ),

    _GuideSection(
      title: 'Structure & Sections',
      icon: Icons.view_agenda_rounded,
      points: [
        _GuidePoint(label: '1. Header',
            body: 'Full name, professional email, phone, LinkedIn URL, GitHub URL, and portfolio/personal site link.'),
        _GuidePoint(label: '2. Professional Summary (3–4 lines)',
            body: 'A tight paragraph: your role, years of experience, core tech stack, and biggest achievement. Tailor it to every application.'),
        _GuidePoint(label: '3. Technical Skills',
            body: 'Categorised list — Languages, Frameworks, Databases, Cloud Platforms, DevOps Tools, Version Control. Keep it scannable.'),
        _GuidePoint(label: '4. Work Experience',
            body: 'Reverse chronological. Each role: Company, Title, Duration, then 3–5 bullet points with metrics.'),
        _GuidePoint(label: '5. Projects',
            body: 'Include 2–4 standout projects with: name, tech stack used, your role, and measurable outcome (traffic, performance gain, users).'),
        _GuidePoint(label: '6. Education',
            body: 'Degree, Institution, Year of graduation, relevant coursework or GPA if strong. Keep it brief after 2+ years of work experience.'),
        _GuidePoint(label: '7. Certifications (Optional)',
            body: 'AWS, GCP, Azure, CKA, Cisco, Google Data Analytics — only include current, relevant ones.'),
      ],
    ),

    _GuideSection(
      title: 'Quantify Everything — Metrics Matter',
      icon: Icons.bar_chart_rounded,
      intro:
          'Vague bullets get skipped. Specific numbers get remembered. Every achievement should answer "how much?" or "how many?".',
      points: [
        _GuidePoint(body: '❌  "Improved application performance."'),
        _GuidePoint(body: '✅  "Reduced API response time by 68% by migrating to Redis caching, improving p95 latency from 850ms to 270ms."'),
        _GuidePoint(body: '❌  "Built a microservices system."'),
        _GuidePoint(body: '✅  "Architected a 12-microservice backend on Kubernetes serving 2M+ daily active users with 99.95% uptime."'),
        _GuidePoint(label: 'Metrics to use',
            body: 'Response time %, cost savings (₹ or \$), users served, test coverage %, deployment frequency, lines of code refactored, team size led.'),
      ],
      proTip:
          'If you don\'t have exact numbers, estimate conservatively and note the metric type — "reduced load time by ~40%" is still far better than no metric.',
    ),

    _GuideSection(
      title: 'GitHub & Portfolio',
      icon: Icons.code_off_rounded,
      points: [
        _GuidePoint(label: 'Link it prominently',
            body: 'Put your GitHub URL in the header. Ensure your profile photo, bio, and pinned repositories are up to date.'),
        _GuidePoint(label: 'Write clear README files',
            body: 'Every pinned project should have: project description, tech stack, live demo link, and setup instructions.'),
        _GuidePoint(label: 'Show consistent activity',
            body: 'A green contributions graph signals active coding. Even personal learning repos count.'),
        _GuidePoint(label: 'Portfolio site',
            body: 'A simple, fast personal site with project demos, a downloadable resume link, and contact info greatly boosts credibility.'),
      ],
      proTip:
          'Recruiters at top tech firms spend ~10 seconds on a resume. Your GitHub link with a live project demo can make you stand out instantly.',
    ),

    _GuideSection(
      title: 'Length, Fonts & Formatting',
      icon: Icons.text_fields_rounded,
      points: [
        _GuidePoint(label: 'Length',
            body: '0–5 years: 1 page. 5–10 years: 1–2 pages. 10+ years: maximum 2 pages. Never exceed 2 pages.'),
        _GuidePoint(label: 'Font',
            body: 'Calibri, Arial, or Lato at 10.5–11pt for body. 14–16pt bold for name. Consistent throughout.'),
        _GuidePoint(label: 'Margins',
            body: '0.5–0.75 inch on all sides. Never go below 0.5 inch — it looks cramped.'),
        _GuidePoint(label: 'White space',
            body: 'Adequate spacing between sections makes the resume breathe. Dense text walls are skipped by tired recruiters.'),
        _GuidePoint(label: 'Colours',
            body: 'Subtle use of one accent colour (e.g. section headers) is fine. Avoid rainbow resumes for backend/data roles.'),
      ],
    ),

    _GuideSection(
      title: 'Common Mistakes to Avoid',
      icon: Icons.cancel_rounded,
      points: [
        _GuidePoint(body: 'Generic summaries — "Passionate developer seeking opportunities." (No metrics, no role focus.)'),
        _GuidePoint(body: 'Skill bars (★★★☆☆) — ATS can\'t read them; humans find them subjective.'),
        _GuidePoint(body: 'Listing outdated tech — Remove Flash, jQuery only, or Java 5 if you\'re applying for modern roles.'),
        _GuidePoint(body: 'Missing links — A GitHub with no public repos is worse than no link at all.'),
        _GuidePoint(body: 'Typos & inconsistent tense — Use past tense for previous roles, present for current.'),
        _GuidePoint(body: 'Lying about skills — "Expert in Kubernetes" when you\'ve only run a tutorial. Interviewers will catch it.'),
      ],
      proTip:
          'Ask a colleague or mentor to review your resume for 30 seconds and tell you what role they think you\'re applying for. If they can\'t say — rewrite your summary.',
    ),
  ],
);

// ─────────────────────────────────────────────────────────────

const _nonTechnicalGuide = _GuideData(
  title: 'Non-Technical Resume Guide',
  badge: '💼 Business',
  accentColor: const Color(0xFFBE97E8),
  heroIcon: Icons.business_center_rounded,
  heroTitle: 'MASTER YOUR NON-TECHNICAL RESUME',
  heroSubtitle:
      'For business, management, marketing, HR, finance, and operations professionals — your resume must demonstrate impact, leadership, and results, not code.',

  sections: [
    _GuideSection(
      title: 'ATS for Non-Technical Roles',
      icon: Icons.computer_rounded,
      intro:
          'Non-technical roles use ATS too — especially at mid-to-large organisations. HR, consulting, marketing, and finance positions all go through automated screening.',
      points: [
        _GuidePoint(label: 'Use clean, simple layouts',
            body: 'Avoid two-column templates with text boxes, tables, or graphics. A single clean column parses best.'),
        _GuidePoint(label: 'Stick to standard headings',
            body: '"Work Experience", "Education", "Skills", "Certifications" — use these exact labels.'),
        _GuidePoint(label: 'Plain file format',
            body: 'Submit as .docx or a non-scanned, text-selectable PDF. Scanned PDFs are completely unreadable by ATS.'),
        _GuidePoint(label: 'No infographics or charts',
            body: 'Pie charts showing skill proficiency, timeline graphics, or word clouds are invisible to ATS.'),
      ],
      proTip:
          'Copy-paste your resume into Notepad. If everything reads clearly in order without garbled text or jumbled columns, your ATS score is strong.',
    ),

    _GuideSection(
      title: 'Keywords for Non-Technical Roles',
      icon: Icons.search_rounded,
      intro:
          'Your keywords come from the job description and industry vocabulary — not tech tools. They describe leadership style, business functions, and domain expertise.',
      points: [
        _GuidePoint(label: 'Function keywords',
            body: '"P&L Management", "Revenue Growth", "Stakeholder Engagement", "Cross-functional Collaboration", "Budget Forecasting", "Client Relationship Management".'),
        _GuidePoint(label: 'Industry keywords',
            body: 'For HR: "Talent Acquisition", "Employee Engagement", "HRIS". For Marketing: "Campaign ROI", "Brand Strategy", "SEO/SEM", "Demand Generation".'),
        _GuidePoint(label: 'Soft skill keywords',
            body: '"Leadership", "Strategic Thinking", "Conflict Resolution", "Executive Communication" — use naturally in your bullet points, not as a standalone list.'),
        _GuidePoint(label: 'Mirror the JD exactly',
            body: 'If the role says "Account Management" don\'t write "Client Services" — use the exact phrase from the description.'),
      ],
      proTip:
          'Tailor your resume for every application. A marketing manager resume sent to a sales manager role without edits will often fail ATS keyword screening.',
    ),

    _GuideSection(
      title: 'Structure & Sections',
      icon: Icons.view_agenda_rounded,
      points: [
        _GuidePoint(label: '1. Header',
            body: 'Full name, professional email, phone number, LinkedIn URL, city & country (not full address). Keep it clean.'),
        _GuidePoint(label: '2. Professional Summary (3–5 lines)',
            body: 'Lead with your role title, years of experience, industry focus, and top achievement. Example: "Marketing Manager with 7 years in FMCG, driving 35% YoY revenue growth through data-led brand campaigns."'),
        _GuidePoint(label: '3. Core Competencies / Key Skills',
            body: 'A concise block of 9–15 competency keywords relevant to the role. Makes ATS scanning easy and gives recruiters a fast snapshot.'),
        _GuidePoint(label: '4. Work Experience',
            body: 'Reverse chronological. Each role: Company, Title, Location, Dates — then 3–5 achievement bullets with metrics.'),
        _GuidePoint(label: '5. Education',
            body: 'Degree, institution, year. Add relevant executive courses or certifications here (PMP, SHRM, CFA, etc.)'),
        _GuidePoint(label: '6. Certifications / Training',
            body: 'Especially important in HR, Finance, and Project Management — PMP, Six Sigma, CFA, SHRM-CP, Google Analytics.'),
        _GuidePoint(label: '7. Languages (If applicable)',
            body: 'Bilingual ability is a strong differentiator for client-facing, sales, or global operations roles.'),
      ],
    ),

    _GuideSection(
      title: 'Quantifying Impact — Business Metrics',
      icon: Icons.bar_chart_rounded,
      intro:
          'Non-technical resumes often lack numbers — and this is the biggest missed opportunity. Business achievements are highly measurable.',
      points: [
        _GuidePoint(body: '❌  "Managed marketing campaigns."'),
        _GuidePoint(body: '✅  "Led 12 digital campaigns across Q1–Q4, generating ₹4.2Cr in attributed revenue and achieving 3.8x ROAS."'),
        _GuidePoint(body: '❌  "Handled recruitment."'),
        _GuidePoint(body: '✅  "Reduced time-to-hire by 22% and achieved 94% offer acceptance rate by redesigning the structured interview process."'),
        _GuidePoint(label: 'Business metrics to use',
            body: 'Revenue growth (%), cost savings (₹/\$), team size managed, projects delivered on time (%), client retention rate, NPS score, employee attrition reduction.'),
      ],
      proTip:
          'Even if you worked in support roles, estimate your impact: "Managed 120 client accounts representing ₹2Cr in annual recurring revenue." Always be conservative and honest.',
    ),

    _GuideSection(
      title: 'Professional Summary — Your Elevator Pitch',
      icon: Icons.record_voice_over_rounded,
      intro:
          'The summary is the most-read part of your resume. Recruiters spend 6–10 seconds on this before deciding to read further.',
      points: [
        _GuidePoint(label: 'Lead with a title and years of experience',
            body: '"Senior HR Business Partner with 9 years across technology and manufacturing sectors…"'),
        _GuidePoint(label: 'State your biggest achievement',
            body: '"…having led an organisational restructuring that reduced attrition by 31% in 18 months."'),
        _GuidePoint(label: 'Define your value proposition',
            body: '"Known for bridging strategic workforce planning with on-ground execution in high-growth environments."'),
        _GuidePoint(label: 'Tailor to every application',
            body: 'Change 2–3 sentences per job. Reflect the specific function and industry of the target role.'),
      ],
      proTip:
          'Write the summary last — after you\'ve listed all your achievements. The best summaries are distillations of your actual bullet points.',
    ),

    _GuideSection(
      title: 'LinkedIn & Professional Presence',
      icon: Icons.link_rounded,
      points: [
        _GuidePoint(label: 'Sync your resume and LinkedIn',
            body: 'Recruiters cross-check. Dates, titles, and company names must match exactly.'),
        _GuidePoint(label: 'LinkedIn headline',
            body: 'Go beyond "Open to Work". Use: "Senior Operations Manager | Supply Chain | P&L Ownership | Ex-Amazon". Keywords matter here too.'),
        _GuidePoint(label: 'Recommendations',
            body: '3–5 strong LinkedIn recommendations from managers or peers dramatically increase credibility for non-technical roles.'),
        _GuidePoint(label: 'Portfolio of work',
            body: 'Marketing: campaigns. Consulting: case studies. HR: policy documents. Add samples to your LinkedIn featured section.'),
      ],
      proTip:
          'Update your LinkedIn "About" section to mirror your resume summary. Recruiters often search LinkedIn first and reach out before you apply.',
    ),

    _GuideSection(
      title: 'Formatting & Length',
      icon: Icons.text_fields_rounded,
      points: [
        _GuidePoint(label: 'Length',
            body: '0–8 years: 1 page. 8–15 years: 1–2 pages. 15+ years: maximum 2 pages. Senior executives may go to 3 pages only for comprehensive CVs.'),
        _GuidePoint(label: 'Font',
            body: 'Calibri, Georgia, or Garamond 10.5–11pt. These convey professionalism and readability.'),
        _GuidePoint(label: 'Tone',
            body: 'Confident and specific. Avoid passive language: "was responsible for" → "led", "was involved in" → "delivered".'),
        _GuidePoint(label: 'No photos (India exception)',
            body: 'In most global markets, photos are discouraged. In India, it\'s optional — only include a professional headshot if the JD asks or it\'s a client-facing role.'),
      ],
    ),

    _GuideSection(
      title: 'Common Mistakes to Avoid',
      icon: Icons.cancel_rounded,
      points: [
        _GuidePoint(body: 'Vague summaries — "Hardworking and passionate team player." (No role, no achievement, no value.)'),
        _GuidePoint(body: 'Responsibilities without outcomes — "Managed a team of 10." → Add: "…delivering projects 15% under budget."'),
        _GuidePoint(body: 'Using a creative resume template from Canva for ATS applications — it almost always fails parsing.'),
        _GuidePoint(body: 'Listing personal hobbies in detail — "Cricket, cooking, yoga" wastes valuable space unless directly relevant.'),
        _GuidePoint(body: 'Age or marital status — Not required in modern resumes and can introduce unconscious bias.'),
        _GuidePoint(body: 'Inconsistent formatting — Different font sizes, random bold usage, misaligned dates are red flags for attention to detail.'),
      ],
      proTip:
          'Read your resume out loud. Every sentence should sound confident and specific. If you hesitate or feel it\'s vague — rewrite it with a metric or concrete outcome.',
    ),
  ],
);
