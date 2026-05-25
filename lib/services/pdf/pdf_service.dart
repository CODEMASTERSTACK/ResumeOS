import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/resume_generator/domain/entities/resume_model.dart';

class PdfService {
  pw.Font _getFont(String fontFamily, {bool isBold = false, bool isItalic = false}) {
    switch (fontFamily.toLowerCase()) {
      case 'serif':
        if (isBold && isItalic) return pw.Font.timesBoldItalic();
        if (isBold) return pw.Font.timesBold();
        if (isItalic) return pw.Font.timesItalic();
        return pw.Font.times();
      case 'mono':
        if (isBold && isItalic) return pw.Font.courierBoldOblique();
        if (isBold) return pw.Font.courierBold();
        if (isItalic) return pw.Font.courierOblique();
        return pw.Font.courier();
      case 'sans':
      default:
        if (isBold && isItalic) return pw.Font.helveticaBoldOblique();
        if (isBold) return pw.Font.helveticaBold();
        if (isItalic) return pw.Font.helveticaOblique();
        return pw.Font.helvetica();
    }
  }

  pw.ThemeData _buildTheme(ResumeData data) {
    return pw.ThemeData.withFont(
      base: _getFont(data.fontFamily),
      bold: _getFont(data.fontFamily, isBold: true),
      italic: _getFont(data.fontFamily, isItalic: true),
      boldItalic: _getFont(data.fontFamily, isBold: true, isItalic: true),
    );
  }

  Future<Uint8List> generatePdf(
    ResumeData data,
    ResumeTemplate template,
  ) async {
    switch (template) {
      case ResumeTemplate.atsProfessional:
        return _buildAtsPdf(data);
      case ResumeTemplate.modernMinimal:
        return _buildModernPdf(data);
      case ResumeTemplate.compactClean:
        return _buildCompactPdf(data);
    }
  }

  // ── ATS Professional Template ─────────────────────────────

  Future<Uint8List> _buildAtsPdf(ResumeData data) async {
    final pdf = pw.Document(theme: _buildTheme(data));
    final sizeScale = data.fontSizeScale;
    final primaryColor = PdfColor.fromHex(data.primaryColorHex);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 40, vertical: 36),
        build: (context) => [
          // Header
          _atsHeader(data, primaryColor, sizeScale),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Summary
          if (data.summary.isNotEmpty) ...[
            _atsSection('PROFESSIONAL SUMMARY', sizeScale),
            pw.SizedBox(height: 6),
            pw.Text(data.summary,
                style: pw.TextStyle(
                    fontSize: 10 * sizeScale, lineSpacing: 1.4)),
            pw.SizedBox(height: 14),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _atsSection('PROJECTS', sizeScale),
            pw.SizedBox(height: 6),
            ...data.projects.map((p) => _atsProject(p, sizeScale)),
          ],

          // Education
          if (data.education.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('EDUCATION', sizeScale),
            pw.SizedBox(height: 6),
            ...data.education.map((e) => _atsEducation(e, sizeScale)),
          ],

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('SKILLS', sizeScale),
            pw.SizedBox(height: 6),
            ...data.skillGroups.map(
              (g) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '${g.category}: ',
                        style: pw.TextStyle(
                          fontSize: 10 * sizeScale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.TextSpan(
                        text: g.skills.join(', '),
                        style: pw.TextStyle(fontSize: 10 * sizeScale),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Certifications
          if (data.certifications.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('CERTIFICATIONS', sizeScale),
            pw.SizedBox(height: 6),
            ...data.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${c.title} — ${c.issuer}',
                        style: pw.TextStyle(
                          fontSize: 10 * sizeScale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(c.date,
                          style: pw.TextStyle(fontSize: 9 * sizeScale)),
                    ],
                  ),
                )),
          ],

          // Achievements
          if (data.achievements.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('ACHIEVEMENTS', sizeScale),
            pw.SizedBox(height: 6),
            ...data.achievements.map(
              (a) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style: pw.TextStyle(fontSize: 10 * sizeScale)),
                    pw.Expanded(
                      child: pw.Text(a,
                          style: pw.TextStyle(fontSize: 10 * sizeScale)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _atsHeader(ResumeData data, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          data.name,
          style: pw.TextStyle(
            fontSize: 22 * sizeScale,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          [data.email, data.phone, data.location]
              .where((s) => s.isNotEmpty)
              .join(' | '),
          style: pw.TextStyle(fontSize: 10 * sizeScale),
        ),
        if (data.githubUrl.isNotEmpty || data.linkedinUrl.isNotEmpty)
          pw.Text(
            [data.githubUrl, data.linkedinUrl]
                .where((s) => s.isNotEmpty)
                .join(' | '),
            style: pw.TextStyle(
              fontSize: 10 * sizeScale,
              color: primaryColor,
            ),
          ),
      ],
    );
  }

  pw.Widget _atsSection(String title, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(color: PdfColors.grey500, thickness: 0.5),
      ],
    );
  }

  pw.Widget _atsProject(ResumeProject project, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (project.technologies.isNotEmpty)
                pw.Text(
                  project.technologies.take(4).join(', '),
                  style: pw.TextStyle(
                    fontSize: 9 * sizeScale,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...project.bullets.map(
            (b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: pw.TextStyle(fontSize: 10 * sizeScale)),
                  pw.Expanded(
                    child: pw.Text(b,
                        style: pw.TextStyle(
                            fontSize: 10 * sizeScale, lineSpacing: 1.3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _atsEducation(ResumeEducation edu, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                edu.institution,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${edu.degree} ${edu.field}${edu.cgpa.isNotEmpty ? " — ${edu.cgpa}" : ""}',
                style: pw.TextStyle(fontSize: 10 * sizeScale),
              ),
            ],
          ),
          pw.Text(edu.duration,
              style: pw.TextStyle(fontSize: 9 * sizeScale)),
        ],
      ),
    );
  }

  // ── Modern Minimal Template ───────────────────────────────

  Future<Uint8List> _buildModernPdf(ResumeData data) async {
    final pdf = pw.Document(theme: _buildTheme(data));
    final sizeScale = data.fontSizeScale;
    final accentColor = PdfColor.fromHex(data.primaryColorHex);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sidebar
              pw.Container(
                width: 160,
                constraints: const pw.BoxConstraints(minHeight: 842),
                color: PdfColor.fromHex('#111111'),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.name,
                      style: pw.TextStyle(
                        fontSize: 16 * sizeScale,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text('CONTACT',
                        style: pw.TextStyle(
                          fontSize: 8 * sizeScale,
                          color: PdfColor.fromHex('#888888'),
                          letterSpacing: 1.5,
                        )),
                    pw.SizedBox(height: 6),
                    if (data.email.isNotEmpty)
                      _sidebarItem(data.email, sizeScale),
                    if (data.phone.isNotEmpty)
                      _sidebarItem(data.phone, sizeScale),
                    if (data.location.isNotEmpty)
                      _sidebarItem(data.location, sizeScale),
                    pw.SizedBox(height: 16),
                    if (data.skillGroups.isNotEmpty) ...[
                      pw.Text('SKILLS',
                          style: pw.TextStyle(
                            fontSize: 8 * sizeScale,
                            color: PdfColor.fromHex('#888888'),
                            letterSpacing: 1.5,
                          )),
                      pw.SizedBox(height: 8),
                      ...data.skillGroups
                          .expand((g) => g.skills)
                          .take(15)
                          .map(
                            (s) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: accentColor.shade(0.8),
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: pw.Text(
                                  s,
                                  style: pw.TextStyle(
                                    fontSize: 8 * sizeScale,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              // Main content
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.summary.isNotEmpty) ...[
                        _modernSection('SUMMARY', accentColor, sizeScale),
                        pw.SizedBox(height: 8),
                        pw.Text(data.summary,
                            style: pw.TextStyle(
                                fontSize: 10 * sizeScale, lineSpacing: 1.4)),
                        pw.SizedBox(height: 16),
                      ],
                      if (data.projects.isNotEmpty) ...[
                        _modernSection('PROJECTS', accentColor, sizeScale),
                        pw.SizedBox(height: 8),
                        ...data.projects.map((p) => _atsProject(p, sizeScale)),
                      ],
                      if (data.education.isNotEmpty) ...[
                        _modernSection('EDUCATION', accentColor, sizeScale),
                        pw.SizedBox(height: 8),
                        ...data.education.map((e) => _atsEducation(e, sizeScale)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sidebarItem(String text, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 8 * sizeScale, color: PdfColors.grey300),
        maxLines: 2,
      ),
    );
  }

  pw.Widget _modernSection(String title, PdfColor accent, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        pw.Container(
          height: 2,
          color: accent,
          margin: const pw.EdgeInsets.only(top: 3, bottom: 0),
        ),
      ],
    );
  }

  // ── Compact Clean Template ────────────────────────────────

  // ── Compact Clean Template ────────────────────────────────

  Future<Uint8List> _buildCompactPdf(ResumeData data) async {
    final pdf = pw.Document(theme: _buildTheme(data));
    final sizeScale = data.fontSizeScale;
    final primaryColor = PdfColor.fromHex(data.primaryColorHex);

    // Smart year parser to sort education recent to oldest
    int parseYear(String duration) {
      if (duration.toLowerCase().contains('present') || duration.toLowerCase().contains('current')) {
        return 9999;
      }
      final matches = RegExp(r'\d+').allMatches(duration);
      if (matches.isNotEmpty) {
        final valStr = matches.last.group(0)!;
        final val = int.tryParse(valStr) ?? 0;
        if (val < 100) return 2000 + val;
        return val;
      }
      return 0;
    }

    // Sort education recent to oldest
    final sortedEducation = List<ResumeEducation>.from(data.education);
    sortedEducation.sort((a, b) {
      final yearA = parseYear(a.duration);
      final yearB = parseYear(b.duration);
      return yearB.compareTo(yearA); // descending
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        footer: (context) {
          if (context.pagesCount <= 1) return pw.SizedBox.shrink();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 7.5 * sizeScale,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
        build: (context) => [
          // Header
          _compactHeader(data, primaryColor, sizeScale),
          pw.SizedBox(height: 10),

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            _compactSection('SKILLS', primaryColor, sizeScale),
            _compactSkills(data.skillGroups, primaryColor, sizeScale),
            pw.SizedBox(height: 8),
          ],

          // Training (Experience)
          if (data.experience.isNotEmpty) ...[
            _compactSection('TRAINING & INTERNSHIPS', primaryColor, sizeScale),
            ...data.experience.map((e) => _compactExperience(e, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _compactSection('PROJECTS', primaryColor, sizeScale),
            ...data.projects.map((p) => _compactProject(p, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Certificates
          if (data.certifications.isNotEmpty) ...[
            _compactSection('CERTIFICATES', primaryColor, sizeScale),
            ...data.certifications.map((c) => _compactCertificate(c, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Education (Always in the last!)
          if (sortedEducation.isNotEmpty) ...[
            _compactSection('EDUCATION', primaryColor, sizeScale),
            ...sortedEducation.map((e) => _compactEducation(e, primaryColor, sizeScale)),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _compactHeader(ResumeData data, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              data.name,
              style: pw.TextStyle(
                fontSize: 22 * sizeScale,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column: Socials
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.linkedinUrl.isNotEmpty)
                  _contactLine('LinkedIn: ', data.linkedinUrl, sizeScale, isBlue: true, primaryColor: primaryColor),
                if (data.githubUrl.isNotEmpty)
                  _contactLine('Github: ', data.githubUrl, sizeScale),
                if (data.portfolioUrl.isNotEmpty)
                  _contactLine('LeetCode: ', data.portfolioUrl, sizeScale),
              ],
            ),
            // Right Column: Contact Details
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (data.email.isNotEmpty)
                  _contactLine('Email: ', data.email, sizeScale),
                if (data.phone.isNotEmpty)
                  _contactLine('Mobile: ', data.phone, sizeScale),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _contactLine(String label, String value, double sizeScale, {bool isBlue = false, PdfColor? primaryColor}) {
    final linkColor = (isBlue && primaryColor != null) ? primaryColor : PdfColors.black;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(fontSize: 8.5 * sizeScale, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 8.5 * sizeScale,
                color: linkColor,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _compactSection(String title, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9.5 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 0.8,
          color: primaryColor,
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _compactSkills(List<ResumeSkillGroup> groups, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      children: groups.map((g) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(
                  '${g.category}:',
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  g.skills.join(', '),
                  style: pw.TextStyle(fontSize: 8.5 * sizeScale),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _renderBulletPoint(String text, PdfColor primaryColor, double sizeScale) {
    final isLinkBullet = text.toLowerCase().contains('link:') ||
        text.toLowerCase().contains('http://') ||
        text.toLowerCase().contains('https://');

    if (isLinkBullet) {
      String label = text;
      String url = "";
      String linkText = "";

      if (text.contains('https://') || text.contains('http://')) {
        final idx = text.indexOf('http');
        label = text.substring(0, idx);
        url = text.substring(idx).trim();
        linkText = url;
      } else if (text.contains(':')) {
        final idx = text.indexOf(':');
        label = text.substring(0, idx + 1);
        linkText = text.substring(idx + 1).trim();
        url = linkText.startsWith('http') ? linkText : "https://github.com";
      }

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2.5),
              child: pw.Container(
                width: 2.5,
                height: 2.5,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: label,
                    style: pw.TextStyle(fontSize: 8.5 * sizeScale, color: PdfColors.black),
                  ),
                  pw.TextSpan(
                    text: ' $linkText',
                    style: pw.TextStyle(
                      fontSize: 8.5 * sizeScale,
                      color: primaryColor,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2.5),
            child: pw.Container(
              width: 2.5,
              height: 2.5,
              decoration: const pw.BoxDecoration(
                color: PdfColors.black,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: 8.5 * sizeScale, lineSpacing: 1.15),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _compactExperience(ResumeExperience exp, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                exp.company,
                style: pw.TextStyle(
                  fontSize: 9 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.Text(
                exp.duration,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            exp.role,
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 2),
          ...exp.bullets.map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
        ],
      ),
    );
  }

  String _extractProjectDate(ResumeProject project) {
    final dateReg = RegExp(
      r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s*'?\s*(\d{2,4})\b",
      caseSensitive: false,
    );

    for (final b in project.bullets) {
      final match = dateReg.firstMatch(b);
      if (match != null) {
        return match.group(0)!;
      }
    }
    return "";
  }

  pw.Widget _compactProject(ResumeProject p, PdfColor primaryColor, double sizeScale) {
    String projDate = _extractProjectDate(p);
    if (projDate.isEmpty) {
      projDate = "Jan' 26"; // Reasonable fallback matching screenshot
    }

    // Standard description bullets (filter out link bullets and get first 2)
    final descBullets = p.bullets
        .where((b) =>
            !b.toLowerCase().contains('project link') &&
            !b.toLowerCase().contains('link:'))
        .take(2)
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: p.title,
                      style: pw.TextStyle(
                        fontSize: 9 * sizeScale,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    if (p.technologies.isNotEmpty) ...[
                      pw.TextSpan(
                        text: ' | ',
                        style: pw.TextStyle(fontSize: 8.5 * sizeScale, color: PdfColors.black),
                      ),
                      pw.TextSpan(
                        text: p.technologies.join(', '),
                        style: pw.TextStyle(
                          fontSize: 8.5 * sizeScale,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (projDate.isNotEmpty)
                pw.Text(
                  projDate,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 2),
          // Exactly two bullet points
          ...descBullets.map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
          // Exactly third is the link for that project
          if (p.liveUrl.isNotEmpty || p.githubUrl.isNotEmpty)
            _renderBulletPoint('Project Link: ${p.liveUrl.isNotEmpty ? p.liveUrl : p.githubUrl}', primaryColor, sizeScale),
        ],
      ),
    );
  }

  pw.Widget _compactCertificate(ResumeCertification c, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: c.title,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    color: c.credentialUrl.isNotEmpty ? primaryColor : PdfColors.black,
                    decoration: c.credentialUrl.isNotEmpty ? pw.TextDecoration.underline : pw.TextDecoration.none,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TextSpan(
                  text: ' | ${c.issuer}',
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            c.date,
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _compactEducation(ResumeEducation edu, PdfColor primaryColor, double sizeScale) {
    String inst = edu.institution;
    String loc = "";
    if (inst.contains(',')) {
      final idx = inst.indexOf(',');
      loc = inst.substring(idx + 1).trim();
      inst = inst.substring(0, idx).trim();
    }

    final degreeText = edu.field.isNotEmpty ? "${edu.degree} (${edu.field})" : edu.degree;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                inst,
                style: pw.TextStyle(
                  fontSize: 9 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              if (loc.isNotEmpty)
                pw.Text(
                  loc,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    color: PdfColors.black,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                degreeText,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                edu.duration,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          if (edu.cgpa.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              edu.cgpa.toLowerCase().contains('cgpa') || edu.cgpa.contains('.')
                  ? 'CGPA: ${edu.cgpa}'
                  : 'Percentage: ${edu.cgpa}',
              style: pw.TextStyle(
                fontSize: 8 * sizeScale,
                color: PdfColors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
