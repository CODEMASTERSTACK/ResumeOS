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
    // Force Times Serif typography theme to match the image exactly
    final timesTheme = pw.ThemeData.withFont(
      base: pw.Font.times(),
      bold: pw.Font.timesBold(),
      italic: pw.Font.timesItalic(),
      boldItalic: pw.Font.timesBoldItalic(),
    );
    final pdf = pw.Document(theme: timesTheme);
    final sizeScale = data.fontSizeScale;
    final primaryColor = PdfColor.fromHex(data.primaryColorHex);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 40, vertical: 36),
        build: (context) => [
          // Header (Left-aligned design like the image)
          _atsHeader(data, primaryColor, sizeScale),
          pw.SizedBox(height: 6), // Space after header, no divider line!

          // Summary
          if (data.summary.isNotEmpty) ...[
            _atsSection('PROFESSIONAL SUMMARY', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            pw.Text(data.summary,
                style: pw.TextStyle(
                    fontSize: 10 * sizeScale, lineSpacing: 1.4)),
            pw.SizedBox(height: 10),
          ],

          // Experience
          if (data.experience.isNotEmpty) ...[
            _atsSection('EXPERIENCE', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.experience,
              (e) => _atsExperience(e, data.location, sizeScale),
              itemSpacing: 6,
            ),
            pw.SizedBox(height: 10),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _atsSection('PROJECTS', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.projects,
              (p) => _atsProject(p, sizeScale),
              itemSpacing: 6,
            ),
            pw.SizedBox(height: 10),
          ],

          // Research Work
          if (data.showResearch && data.research.isNotEmpty) ...[
            _atsSection('RESEARCH WORK', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.research,
              (r) => _atsResearch(r, sizeScale),
              itemSpacing: 6,
            ),
            pw.SizedBox(height: 10),
          ],

          // Certifications
          if (data.showCertifications && data.certifications.isNotEmpty) ...[
            _atsSection('CERTIFICATIONS', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.certifications,
              (c) => _atsCertificationItem(c, sizeScale),
              itemSpacing: 4,
            ),
            pw.SizedBox(height: 10),
          ],

          // Achievements
          if (data.showAchievements && data.achievements.isNotEmpty) ...[
            _atsSection('ACHIEVEMENTS', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.achievements,
              (a) => _atsAchievementItem(a, sizeScale),
              itemSpacing: 4,
            ),
            pw.SizedBox(height: 10),
          ],

          // Education
          if (data.education.isNotEmpty) ...[
            _atsSection('EDUCATION', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              List<ResumeEducation>.from(data.education)
                ..sort((a, b) {
                  final rankA = _getEducationRank(a);
                  final rankB = _getEducationRank(b);
                  if (rankA != rankB) {
                    return rankA.compareTo(rankB);
                  }
                  final yearA = _extractEndYear(a.duration);
                  final yearB = _extractEndYear(b.duration);
                  return yearB.compareTo(yearA);
                }),
              (e) => _atsEducation(e, data.location, sizeScale),
              itemSpacing: 6,
            ),
            pw.SizedBox(height: 10),
          ],

          // Additional Information (Skills)
          if (data.skillGroups.isNotEmpty) ...[
            _atsSection('ADDITIONAL INFORMATION', primaryColor, sizeScale),
            pw.SizedBox(height: 2),
            ..._buildSectionItems(
              data.skillGroups,
              (g) => _atsSkillGroupItem(g, sizeScale),
              itemSpacing: 4,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _atsHeader(ResumeData data, PdfColor primaryColor, double sizeScale) {
    final List<pw.Widget> contactWidgets = [];

    // Custom SVG drawing helper
    pw.Widget svgIcon(String svgContent) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(right: 3, top: 1),
        child: pw.SvgImage(
          svg: svgContent,
          width: 8.5 * sizeScale,
          height: 8.5 * sizeScale,
        ),
      );
    }

    String extractUsername(String url) {
      url = url.trim();
      if (url.isEmpty) return '';
      if (!url.contains('/')) return url;
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      final parts = url.split('/');
      return parts.isNotEmpty ? parts.last : url;
    }

    // 1. Phone number
    if (data.phone.isNotEmpty) {
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(phoneSvg),
            pw.Text(data.phone, style: pw.TextStyle(fontSize: 9.5 * sizeScale)),
          ],
        ),
      );
    }

    // 2. Email
    if (data.email.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(pw.Text(' | ', style: pw.TextStyle(fontSize: 9.5 * sizeScale)));
      }
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(emailSvg),
            pw.Text(data.email, style: pw.TextStyle(fontSize: 9.5 * sizeScale)),
          ],
        ),
      );
    }

    // 3. LinkedIn
    if (data.linkedinUrl.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(pw.Text(' | ', style: pw.TextStyle(fontSize: 9.5 * sizeScale)));
      }
      final username = extractUsername(data.linkedinUrl);
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(linkedinSvg),
            pw.UrlLink(
              destination: data.linkedinUrl.startsWith('http') ? data.linkedinUrl : 'https://${data.linkedinUrl}',
              child: pw.Text(
                username,
                style: pw.TextStyle(
                  fontSize: 9.5 * sizeScale,
                  color: PdfColors.black,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. GitHub
    if (data.githubUrl.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(pw.Text(' | ', style: pw.TextStyle(fontSize: 9.5 * sizeScale)));
      }
      final username = extractUsername(data.githubUrl);
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(githubSvg),
            pw.UrlLink(
              destination: data.githubUrl.startsWith('http') ? data.githubUrl : 'https://${data.githubUrl}',
              child: pw.Text(
                username,
                style: pw.TextStyle(
                  fontSize: 9.5 * sizeScale,
                  color: PdfColors.black,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 5. Location
    if (data.location.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(pw.Text(' | ', style: pw.TextStyle(fontSize: 9.5 * sizeScale)));
      }
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(locationSvg),
            pw.Text(data.location, style: pw.TextStyle(fontSize: 9.5 * sizeScale)),
          ],
        ),
      );
    }

    // 6. Portfolio
    if (data.portfolioUrl.isNotEmpty) {
      if (contactWidgets.isNotEmpty) {
        contactWidgets.add(pw.Text(' | ', style: pw.TextStyle(fontSize: 9.5 * sizeScale)));
      }
      final displayPort = extractUsername(data.portfolioUrl);
      contactWidgets.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            svgIcon(portfolioSvg),
            pw.UrlLink(
              destination: data.portfolioUrl.startsWith('http') ? data.portfolioUrl : 'https://${data.portfolioUrl}',
              child: pw.Text(
                displayPort,
                style: pw.TextStyle(
                  fontSize: 9.5 * sizeScale,
                  color: PdfColors.black,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
        pw.Wrap(
          spacing: 2,
          runSpacing: 4,
          crossAxisAlignment: pw.WrapCrossAlignment.center,
          children: contactWidgets,
        ),
      ],
    );
  }

  List<pw.Widget> _buildSectionItems<T>(
    List<T> items,
    pw.Widget Function(T item) builder, {
    double itemSpacing = 6,
  }) {
    final List<pw.Widget> widgets = [];
    for (int i = 0; i < items.length; i++) {
      widgets.add(builder(items[i]));
      if (i < items.length - 1) {
        widgets.add(pw.SizedBox(height: itemSpacing));
      }
    }
    return widgets;
  }

  int _getEducationRank(ResumeEducation edu) {
    final deg = edu.degree.toLowerCase();
    final field = edu.field.toLowerCase();
    final inst = edu.institution.toLowerCase();

    if (deg.contains('10') ||
        deg.contains('ssc') ||
        deg.contains('matric') ||
        deg.contains('high school') ||
        deg.contains('highschool') ||
        field.contains('10') ||
        field.contains('ssc') ||
        field.contains('matric') ||
        field.contains('high school') ||
        field.contains('highschool') ||
        inst.contains('10') ||
        inst.contains('ssc') ||
        inst.contains('matric') ||
        inst.contains('high school') ||
        inst.contains('highschool')) {
      return 3;
    }
    if (deg.contains('12') ||
        deg.contains('hsc') ||
        deg.contains('intermediate') ||
        deg.contains('senior secondary') ||
        field.contains('12') ||
        field.contains('hsc') ||
        field.contains('intermediate') ||
        field.contains('senior secondary') ||
        inst.contains('12') ||
        inst.contains('hsc') ||
        inst.contains('intermediate') ||
        inst.contains('senior secondary')) {
      return 2;
    }
    return 1;
  }

  int _extractEndYear(String duration) {
    final RegExp yearRegex = RegExp(r'\b(20\d{2}|19\d{2})\b');
    final matches = yearRegex.allMatches(duration).toList();
    if (matches.isNotEmpty) {
      final lastMatch = matches.last.group(0);
      if (lastMatch != null) {
        return int.tryParse(lastMatch) ?? 0;
      }
    }
    return 0;
  }

  pw.Widget _atsExperience(ResumeExperience exp, String userLocation, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                exp.company,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _formatAtsDate(exp.duration),
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                exp.role,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...exp.bullets.map((b) => _renderAtsBullet(b, sizeScale)),
        ],
      ),
    );
  }

  pw.Widget _atsSection(String title, PdfColor primaryColor, double sizeScale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10 * sizeScale,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(
          color: PdfColors.black,
          thickness: 0.75,
          height: 1, // Removes the large default height margin of Divider
        ),
      ],
    );
  }

  pw.Widget _atsProject(ResumeProject project, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0),
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
                      text: project.title,
                      style: pw.TextStyle(
                        fontSize: 10 * sizeScale,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (project.technologies.isNotEmpty)
                      pw.TextSpan(
                        text: ' | ${project.technologies.take(5).join(", ")}',
                        style: pw.TextStyle(
                          fontSize: 9.5 * sizeScale,
                          color: PdfColors.black,
                        ),
                      ),
                  ],
                ),
              ),
              if (project.duration.isNotEmpty)
                pw.Text(
                  _formatAtsDate(project.duration),
                  style: pw.TextStyle(
                    fontSize: 10 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
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
                  pw.Container(
                    width: 3 * sizeScale,
                    height: 3 * sizeScale,
                    margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.black,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
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

  pw.Widget _atsResearch(ResumeProject research, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0),
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
                      text: research.title,
                      style: pw.TextStyle(
                        fontSize: 10 * sizeScale,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (research.technologies.isNotEmpty)
                      pw.TextSpan(
                        text: ' | ${research.technologies.take(5).join(", ")}',
                        style: pw.TextStyle(
                          fontSize: 9.5 * sizeScale,
                          color: PdfColors.black,
                        ),
                      ),
                  ],
                ),
              ),
              if (research.duration.isNotEmpty)
                pw.Text(
                  _formatAtsDate(research.duration),
                  style: pw.TextStyle(
                    fontSize: 10 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...research.bullets.take(3).map(
            (b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 3 * sizeScale,
                    height: 3 * sizeScale,
                    margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.black,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
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

  pw.Widget _atsEducation(ResumeEducation edu, String userLocation, double sizeScale) {
    final String degreeLower = edu.degree.toLowerCase();
    final String fieldLower = edu.field.toLowerCase();
    final bool isSchool = degreeLower.contains('10') ||
        degreeLower.contains('12') ||
        degreeLower.contains('matric') ||
        degreeLower.contains('intermediate') ||
        degreeLower.contains('school') ||
        degreeLower.contains('ssc') ||
        degreeLower.contains('hsc') ||
        fieldLower.contains('10') ||
        fieldLower.contains('12') ||
        fieldLower.contains('matric') ||
        fieldLower.contains('intermediate') ||
        fieldLower.contains('school') ||
        fieldLower.contains('ssc') ||
        fieldLower.contains('hsc');

    final String gradeLabel = isSchool ? 'Percentage' : 'CGPA';
    final String degreeText = edu.degree;
    final String fieldText = edu.field.isNotEmpty ? ' ${edu.field}' : '';
    final String gradeValue = isSchool
        ? (edu.cgpa.endsWith('%') ? edu.cgpa : '${edu.cgpa}%')
        : edu.cgpa;
    final String gradeText = edu.cgpa.isNotEmpty ? ' ($gradeLabel: $gradeValue)' : '';
    final String combined = '$degreeText$fieldText$gradeText';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                edu.institution,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _formatAtsDate(edu.duration),
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                combined,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _atsCertificationItem(ResumeCertification c, double sizeScale) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            if (c.credentialUrl.isNotEmpty)
              pw.UrlLink(
                destination: c.credentialUrl,
                child: pw.Text(
                  c.title,
                  style: pw.TextStyle(
                    fontSize: 10 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0000EE'),
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              )
            else
              pw.Text(
                c.title,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            pw.Text(
              ' | ${c.issuer}',
              style: pw.TextStyle(
                fontSize: 10 * sizeScale,
              ),
            ),
          ],
        ),
        pw.Text(
          c.date,
          style: pw.TextStyle(
            fontSize: 10 * sizeScale,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _atsAchievementItem(String a, double sizeScale) {
    final parts = a.split('|');
    final desc = parts[0].trim();
    final date = parts.length > 1 ? parts[1].trim() : '';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 3 * sizeScale,
                  height: 3 * sizeScale,
                  margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    desc,
                    style: pw.TextStyle(fontSize: 10 * sizeScale),
                  ),
                ),
              ],
            ),
          ),
          if (date.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.Text(
                date,
                style: pw.TextStyle(
                  fontSize: 10 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _atsSkillGroupItem(ResumeSkillGroup g, double sizeScale) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3 * sizeScale,
          height: 3 * sizeScale,
          margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColors.black,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
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
      ],
    );
  }

  // ── Modern Minimal Template ───────────────────────────────

  // ── Modern Minimal Template ───────────────────────────────

  List<pw.Widget> _buildCenteredContactList(ResumeData data, PdfColor primaryColor, double sizeScale) {
    final List<pw.Widget> items = [];

    // Phone (tel)
    if (data.phone.isNotEmpty) {
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
              'tel',
              style: pw.TextStyle(fontSize: 5.5 * sizeScale, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 3.5),
          pw.Text(data.phone, style: pw.TextStyle(fontSize: 8.5 * sizeScale, fontWeight: pw.FontWeight.bold)),
        ],
      ));
    }

    // Email (mail)
    if (data.email.isNotEmpty) {
      if (items.isNotEmpty) items.add(_dividerWidget(sizeScale));
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
              'mail',
              style: pw.TextStyle(fontSize: 5.5 * sizeScale, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 3.5),
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
            _formatModernLocation(data.location),
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
                _formatAtsDate(exp.duration),
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

  pw.Widget _modernResearch(ResumeProject r, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                r.title,
                style: pw.TextStyle(
                  fontSize: 9 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (r.githubUrl.isNotEmpty)
                pw.Text(
                  r.githubUrl,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...r.bullets.take(3).map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
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

          // Research Work
          if (data.showResearch && data.research.isNotEmpty) ...[
            _modernSectionTitle('RESEARCH WORK', primaryColor, sizeScale),
            ...data.research.map((r) => _modernResearch(r, primaryColor, sizeScale)),
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

          // Research Work
          if (data.showResearch && data.research.isNotEmpty) ...[
            _compactSection('RESEARCH WORK', primaryColor, sizeScale),
            ...data.research.map((r) => _compactResearch(r, primaryColor, sizeScale)),
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
                  _contactLine('LinkedIn: ', data.linkedinUrl, sizeScale),
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
                  color: PdfColors.black,
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
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 7.5 * sizeScale),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  exp.role,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                ...exp.bullets.map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
              ],
            ),
          ),
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

  pw.Widget _compactResearch(ResumeProject r, PdfColor primaryColor, double sizeScale) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                r.title,
                style: pw.TextStyle(
                  fontSize: 9 * sizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              if (r.githubUrl.isNotEmpty)
                pw.Text(
                  r.githubUrl,
                  style: pw.TextStyle(
                    fontSize: 8.5 * sizeScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...r.bullets.take(3).map((b) => _renderBulletPoint(b, primaryColor, sizeScale)),
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

  pw.Widget _renderAtsBullet(String text, double sizeScale) {
    final isLinkBullet = text.toLowerCase().contains('http://') ||
        text.toLowerCase().contains('https://') ||
        text.toLowerCase().contains('link:');

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
            pw.Container(
              width: 3 * sizeScale,
              height: 3 * sizeScale,
              margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.black,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(
              child: pw.UrlLink(
                destination: url,
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: label,
                        style: pw.TextStyle(fontSize: 10 * sizeScale, color: PdfColors.black),
                      ),
                      pw.TextSpan(
                        text: ' $linkText',
                        style: pw.TextStyle(
                          fontSize: 10 * sizeScale,
                          color: PdfColors.black,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
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
          pw.Container(
            width: 3 * sizeScale,
            height: 3 * sizeScale,
            margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: 10 * sizeScale, lineSpacing: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAtsDate(String dateStr) {
    dateStr = dateStr.trim();
    if (dateStr.isEmpty) return '';

    final separators = ['-', 'to', '–', '—'];
    String separatorUsed = '';
    List<String> parts = [];
    for (final sep in separators) {
      if (dateStr.contains(sep)) {
        separatorUsed = sep;
        parts = dateStr.split(sep);
        break;
      }
    }

    if (parts.isNotEmpty) {
      final formattedParts = parts.map((p) => _formatSingleDate(p.trim())).toList();
      return formattedParts.join(' $separatorUsed ');
    }

    return _formatSingleDate(dateStr);
  }

  String _formatSingleDate(String singleDate) {
    final lower = singleDate.toLowerCase();
    if (lower.contains('present') || lower.contains('current')) {
      return 'Present';
    }

    final monthMap = {
      'january': "Jan", 'jan': "Jan",
      'february': "Feb", 'feb': "Feb",
      'march': "Mar", 'mar': "Mar",
      'april': "Apr", 'apr': "Apr",
      'may': "May",
      'june': "Jun", 'jun': "Jun",
      'july': "Jul", 'jul': "Jul",
      'august': "Aug", 'aug': "Aug",
      'september': "Sep", 'sep': "Sep",
      'october': "Oct", 'oct': "Oct",
      'november': "Nov", 'nov': "Nov",
      'december': "Dec", 'dec': "Dec",
    };

    final monthRegex = RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b',
      caseSensitive: false,
    );
    final yearRegex = RegExp(r'\b(20)?(\d{2})\b');

    final monthMatch = monthRegex.firstMatch(lower);
    
    final year4Match = RegExp(r'\b\d{4}\b').firstMatch(singleDate);
    String yearAbbr = '';
    if (year4Match != null) {
      final yearStr = year4Match.group(0)!;
      yearAbbr = yearStr.substring(yearStr.length - 2);
    } else {
      final yearMatch = yearRegex.firstMatch(singleDate);
      if (yearMatch != null) {
        yearAbbr = yearMatch.group(2)!;
      }
    }

    if (monthMatch != null) {
      final matchedMonth = monthMatch.group(0)!;
      final monthAbbr = monthMap[matchedMonth] ?? matchedMonth;
      if (yearAbbr.isNotEmpty) {
        return "$monthAbbr'$yearAbbr";
      }
      return monthAbbr;
    }

    return singleDate;
  }

  String _formatModernLocation(String locationStr) {
    locationStr = locationStr.trim();
    if (locationStr.isEmpty) return '';
    final parts = locationStr.split(',').map((s) => s.trim()).toList();
    if (parts.isEmpty) return '';

    String city = parts[0];
    String state = parts.length > 1 ? parts[1] : '';
    String pincode = parts.length > 2 ? parts[2] : '';

    if (city.isNotEmpty) {
      city = city[0].toUpperCase() + city.substring(1);
    }
    if (state.isNotEmpty) {
      state = state[0].toUpperCase() + state.substring(1);
    }

    final List<String> formatted = [];
    if (city.isNotEmpty) formatted.add(city);
    if (state.isNotEmpty) formatted.add(state);
    if (pincode.isNotEmpty) formatted.add(pincode);

    return formatted.join(', ');
  }
}

const String phoneSvg = '<svg viewBox="0 0 24 24"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z" fill="#000000"/></svg>';

const String emailSvg = '<svg viewBox="0 0 24 24"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" fill="#000000"/></svg>';

const String linkedinSvg = '<svg viewBox="0 0 24 24"><path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.779-1.75-1.75s.784-1.75 1.75-1.75 1.75.779 1.75 1.75-.784 1.75-1.75 1.75zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z" fill="#000000"/></svg>';

const String githubSvg = '<svg viewBox="0 0 24 24"><path d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.9 1.52 2.34 1.07 2.91.83.1-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2z" fill="#000000"/></svg>';

const String locationSvg = '<svg viewBox="0 0 24 24"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" fill="#000000"/></svg>';

const String portfolioSvg = '<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.53c-.26-.81-1-1.4-1.9-1.4h-1v-3c0-.55-.45-1-1-1h-6v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" fill="#000000"/></svg>';
