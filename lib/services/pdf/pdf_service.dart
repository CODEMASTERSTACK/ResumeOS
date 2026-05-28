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
                '${edu.degree} ${edu.field}${edu.cgpa.isNotEmpty ? " - ${edu.cgpa}" : ""}',
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

  // ── Modern Minimal Template ───────────────────────────────

  List<pw.Widget> _buildCenteredContactList(ResumeData data, PdfColor primaryColor, double sizeScale) {
    final List<pw.Widget> items = [];

    // Phone (☎)
    if (data.phone.isNotEmpty) {
      items.add(pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('☎', style: pw.TextStyle(fontSize: 10 * sizeScale)),
          pw.SizedBox(width: 3),
          pw.Text(data.phone, style: pw.TextStyle(fontSize: 8.5 * sizeScale, fontWeight: pw.FontWeight.bold)),
        ],
      ));
    }

    // Email (✉)
    if (data.email.isNotEmpty) {
      if (items.isNotEmpty) items.add(_dividerWidget(sizeScale));
      items.add(pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('✉', style: pw.TextStyle(fontSize: 10 * sizeScale)),
          pw.SizedBox(width: 3),
          pw.Text(
            data.email,
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              color: PdfColors.black,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ],
      ));
    }

    // LinkedIn ([in])
    if (data.linkedinUrl.isNotEmpty) {
      if (items.isNotEmpty) items.add(_dividerWidget(sizeScale));
      String displayLinkedin = data.linkedinUrl;
      if (displayLinkedin.startsWith('https://')) displayLinkedin = displayLinkedin.substring(8);
      if (displayLinkedin.startsWith('www.')) displayLinkedin = displayLinkedin.substring(4);
      if (displayLinkedin.startsWith('linkedin.com/in/')) {
        displayLinkedin = displayLinkedin.substring(16);
      } else if (displayLinkedin.startsWith('linkedin.com/')) {
        displayLinkedin = displayLinkedin.substring(13);
      }

      items.add(pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
            child: pw.Text(
              'in',
              style: pw.TextStyle(fontSize: 6.5 * sizeScale, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(
            'linkedin.com/in/$displayLinkedin',
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              color: primaryColor,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ],
      ));
    }

    // GitHub (git)
    if (data.githubUrl.isNotEmpty) {
      if (items.isNotEmpty) items.add(_dividerWidget(sizeScale));
      String displayGithub = data.githubUrl;
      if (displayGithub.startsWith('https://')) displayGithub = displayGithub.substring(8);
      if (displayGithub.startsWith('www.')) displayGithub = displayGithub.substring(4);
      if (displayGithub.startsWith('github.com/')) {
        displayGithub = displayGithub.substring(11);
      }

      items.add(pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
            child: pw.Text(
              'git',
              style: pw.TextStyle(fontSize: 5.5 * sizeScale, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(
            'github.com/$displayGithub',
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              color: PdfColors.black,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ],
      ));
    }

    // LeetCode/Portfolio (lc)
    if (data.portfolioUrl.isNotEmpty) {
      if (items.isNotEmpty) items.add(_dividerWidget(sizeScale));
      String displayPort = data.portfolioUrl;
      if (displayPort.startsWith('https://')) displayPort = displayPort.substring(8);
      if (displayPort.startsWith('www.')) displayPort = displayPort.substring(4);
      if (displayPort.startsWith('leetcode.com/')) {
        displayPort = displayPort.substring(13);
      }

      items.add(pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
            child: pw.Text(
              'lc',
              style: pw.TextStyle(fontSize: 6 * sizeScale, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(
            'leetcode.com/$displayPort',
            style: pw.TextStyle(
              fontSize: 8.5 * sizeScale,
              color: PdfColors.black,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ],
      ));
    }

    return items;
  }

  pw.Widget _dividerWidget(double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
      child: pw.Text('|', style: pw.TextStyle(fontSize: 8.5 * sizeScale, color: PdfColors.grey600)),
    );
  }

  pw.Widget _modernHeader(ResumeData data, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          data.name,
          style: pw.TextStyle(
            fontSize: 20 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 2),
        if (data.location.isNotEmpty)
          pw.Text(
            data.location,
            style: pw.TextStyle(
              fontSize: 9 * sizeScale,
              color: PdfColors.black,
            ),
          ),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: _buildCenteredContactList(data, primaryColor, sizeScale),
        ),
      ],
    );
  }

  pw.Widget _modernSectionTitle(String title, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9.5 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 0.8,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 5),
      ],
    );
  }

  pw.Widget _modernExperience(ResumeExperience exp, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${exp.role} - ${exp.company}',
                style: pw.TextStyle(
                  fontSize: 9 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                exp.duration,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...exp.bullets.map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
        ],
      ),
    );
  }

  pw.Widget _modernProject(ResumeProject p, PdfColor primaryColor, double sizeScale) {
    String projDate = _extractProjectDate(p);
    if (projDate.isEmpty) {
      projDate = "Jan' 26";
    }

    final descBullets = p.bullets
        .where((b) =>
            !b.toLowerCase().contains('project link') &&
            !b.toLowerCase().contains('link:'))
        .take(2)
        .toList();

    final techList = p.technologies.take(4).toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
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
                        color: PdfColors.black,
                      ),
                    ),
                    if (techList.isNotEmpty) ...[
                      pw.TextSpan(
                        text: ' | ',
                        style: pw.TextStyle(fontSize: 8.5 * sizeScale, color: PdfColors.black),
                      ),
                      pw.TextSpan(
                        text: techList.join(', '),
                        style: pw.TextStyle(
                          fontSize: 8.5 * sizeScale,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Text(
                projDate,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...descBullets.map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
          if (p.liveUrl.isNotEmpty || p.githubUrl.isNotEmpty)
            _renderBulletPoint('Project Link: ${p.liveUrl.isNotEmpty ? p.liveUrl : p.githubUrl}', primaryColor, sizeScale),
        ],
      ),
    );
  }

  pw.Widget _modernCertificate(ResumeCertification c, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: c.credentialUrl.isNotEmpty ? 4.0 : 3.0),
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
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _modernSkills(List<ResumeSkillGroup> groups, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      children: groups.map((g) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(
                  '${g.category}:',
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  g.skills.join(', '),
                  style: pw.TextStyle(fontSize: 8.5 * sizeScale, color: PdfColors.black),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _modernEducation(ResumeEducation edu, PdfColor primaryColor, double sizeScale) {
    String inst = edu.institution;
    String loc = "";
    if (inst.contains(',')) {
      final idx = inst.indexOf(',');
      loc = inst.substring(idx + 1).trim();
      inst = inst.substring(0, idx).trim();
    }

    final isSecondaryOrHighSchool = edu.degree.toLowerCase().contains('10th') || 
                                    edu.degree.toLowerCase().contains('12th') ||
                                    edu.degree.toLowerCase().contains('high school') ||
                                    edu.degree.toLowerCase().contains('matric') ||
                                    edu.degree.toLowerCase().contains('intermediate') ||
                                    edu.field.toLowerCase().contains('10th') ||
                                    edu.field.toLowerCase().contains('12th');

    final gradeLabel = isSecondaryOrHighSchool ? "Percentage" : "CGPA";
    final gradeText = edu.cgpa.isNotEmpty 
        ? " - $gradeLabel: ${edu.cgpa}${isSecondaryOrHighSchool && !edu.cgpa.contains('%') ? '%' : ''}" 
        : "";

    final degreeText = edu.field.isNotEmpty ? "${edu.degree} (${edu.field})$gradeText" : "${edu.degree}$gradeText";

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
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
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                edu.duration,
                style: pw.TextStyle(
                  fontSize: 8.5 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
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
                  color: PdfColors.grey800,
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
        ],
      ),
    );
  }

  Future<Uint8List> _buildModernPdf(ResumeData data) async {
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
          // Header (Centered)
          _modernHeader(data, primaryColor, sizeScale),
          pw.SizedBox(height: 10),

          // Experience
          if (data.experience.isNotEmpty) ...[
            _modernSectionTitle('EXPERIENCE & INTERNSHIP', primaryColor, sizeScale),
            ...data.experience.map((e) => _modernExperience(e, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _modernSectionTitle('PROJECTS', primaryColor, sizeScale),
            ...data.projects.map((p) => _modernProject(p, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Certificates
          if (data.certifications.isNotEmpty) ...[
            _modernSectionTitle('CERTIFICATE & CREDENTIALS', primaryColor, sizeScale),
            ...data.certifications.map((c) => _modernCertificate(c, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Qualifications (Achievements) - Added after Certificate section if user has them
          if (data.achievements.isNotEmpty) ...[
            _modernSectionTitle('QUALIFICATIONS', primaryColor, sizeScale),
            ...data.achievements.map((a) => _renderBulletPoint(a, primaryColor, sizeScale)),
            pw.SizedBox(height: 8),
          ],

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            _modernSectionTitle('SKILLS', primaryColor, sizeScale),
            _modernSkills(data.skillGroups, primaryColor, sizeScale),
            pw.SizedBox(height: 8),
          ],

          // Education (Always last!)
          if (sortedEducation.isNotEmpty) ...[
            _modernSectionTitle('EDUCATION', primaryColor, sizeScale),
            ...sortedEducation.map((e) => _modernEducation(e, primaryColor, sizeScale)),
          ],
        ],
      ),
    );

    return pdf.save();
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
                        text: p.technologies.take(4).join(', '),
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
