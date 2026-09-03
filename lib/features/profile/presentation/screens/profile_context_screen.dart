import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';

class ProfileContextData {
  final UserModel? user;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> achievements;

  ProfileContextData({
    this.user,
    this.skills = const [],
    this.education = const [],
    this.experience = const [],
    this.certifications = const [],
    this.achievements = const [],
  });
}

class ProfileContextScreen extends ConsumerStatefulWidget {
  const ProfileContextScreen({super.key});

  @override
  ConsumerState<ProfileContextScreen> createState() => _ProfileContextScreenState();
}

class _ProfileContextScreenState extends ConsumerState<ProfileContextScreen> {
  late Future<ProfileContextData> _profileDataFuture;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _profileDataFuture = _loadData();
  }

  Future<ProfileContextData> _loadData() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) throw Exception("User not logged in");
    final repo = ref.read(profileRepositoryProvider);
    final results = await Future.wait([
      repo.getUser(uid),
      repo.watchSkills(uid).first,
      repo.watchEducation(uid).first,
      repo.watchExperience(uid).first,
      repo.watchCertifications(uid).first,
      repo.watchAchievements(uid).first,
    ]);

    return ProfileContextData(
      user: results[0] as UserModel?,
      skills: results[1] as List<Map<String, dynamic>>,
      education: results[2] as List<Map<String, dynamic>>,
      experience: results[3] as List<Map<String, dynamic>>,
      certifications: results[4] as List<Map<String, dynamic>>,
      achievements: results[5] as List<Map<String, dynamic>>,
    );
  }

  Future<void> _handleDownload(ProfileContextData data) async {
    setState(() {
      _downloading = true;
    });

    try {
      final pdfBytes = await _generateBriefDetailPdf(data);
      
      String? outputPath;
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          outputPath = '${dir.path}/brief_detail.pdf';
        }
      }
      
      if (outputPath == null) {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          outputPath = '${dir.path}/brief_detail.pdf';
        }
      }

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(pdfBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully downloaded to: $outputPath'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        return;
      }
      
      throw Exception('Could not access Downloads directory');
    } catch (e) {
      // Fallback to sharing the PDF which lets the user save it anywhere they choose
      final pdfBytes = await _generateBriefDetailPdf(data);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'brief_detail.pdf',
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<Uint8List> _generateBriefDetailPdf(ProfileContextData data) async {
    final pdf = pw.Document();
    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final italicFont = pw.Font.helveticaOblique();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Brief Detail',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 26,
                  color: PdfColor.fromHex('#FF0000'), // Red
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Name: ${data.user?.name ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('Email id: ${data.user?.email ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('Phone no: ${data.user?.phone ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('Location: ${data.user?.location ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('Github: ${data.user?.githubUrl ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('Linkedin: ${data.user?.linkedinUrl ?? ""}', style: pw.TextStyle(font: regularFont, fontSize: 11)),
            pw.SizedBox(height: 20),

            pw.Text('Skills:', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColor.fromHex('#2563EB'))),
            pw.SizedBox(height: 6),
            _buildPdfSkillCategory('Language:', data.skills, 'Languages', regularFont, italicFont),
            _buildPdfSkillCategory('Tools/platform:', data.skills, 'Tools/Platforms', regularFont, italicFont),
            _buildPdfSkillCategory('DevOps & Cloud:', data.skills, 'DevOps & Cloud', regularFont, italicFont),
            _buildPdfSkillCategory('Soft skills:', data.skills, 'Soft Skills', regularFont, italicFont),
            pw.SizedBox(height: 20),

            pw.Text('Education:', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColor.fromHex('#2563EB'))),
            pw.SizedBox(height: 6),
            if (data.education.isEmpty)
              pw.Text('No education details added.', style: pw.TextStyle(font: italicFont, fontSize: 11, color: PdfColors.grey))
            else
              ...data.education.map((e) {
                final degree = e['degree'] as String? ?? 'Higher Education';
                final isSchool = degree == '10th Standard' || degree == '12th Standard';
                final inst = e['institution'] as String? ?? '';
                final endYr = e['endYear'] as String? ?? '';
                final startYr = e['startYear'] as String? ?? '';
                final city = e['city'] as String? ?? '';
                final state = e['state'] as String? ?? '';
                
                if (isSchool) {
                  final board = e['board'] as String? ?? '';
                  final pct = e['percentage'] as String? ?? '';
                  final stream = e['stream'] as String? ?? '';
                  final streamStr = stream.isNotEmpty ? ' ($stream)' : '';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6, left: 10),
                    child: pw.Text(
                      '• $degree$streamStr - $inst (Board: $board, Passing Year: $endYr), $city, $state - $pct',
                      style: pw.TextStyle(font: regularFont, fontSize: 11),
                    ),
                  );
                } else {
                  final spec = e['specialisation'] as String? ?? '';
                  final cgpa = e['cgpa'] as String? ?? '';
                  final specStr = spec.isNotEmpty ? ' in $spec' : '';
                  final cgpaStr = cgpa.isNotEmpty ? ' - CGPA/Pct: $cgpa' : '';
                  final duration = (startYr.isNotEmpty && endYr.isNotEmpty) ? ' ($startYr - $endYr)' : '';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6, left: 10),
                    child: pw.Text(
                      '• $degree$specStr - $inst$duration, $city, $state$cgpaStr',
                      style: pw.TextStyle(font: regularFont, fontSize: 11),
                    ),
                  );
                }
              }),
            pw.SizedBox(height: 20),

            pw.Text('Experience:', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColor.fromHex('#2563EB'))),
            pw.SizedBox(height: 6),
            if (data.experience.isEmpty)
              pw.Text('No experience details added.', style: pw.TextStyle(font: italicFont, fontSize: 11, color: PdfColors.grey))
            else
              ...data.experience.map((e) {
                final role = e['role'] as String? ?? '';
                final comp = e['company'] as String? ?? '';
                final duration = e['duration'] as String? ?? '';
                final bullets = e['bullets'] as List? ?? [];
                
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10, left: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• $role at $comp ($duration)', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                      if (bullets.isNotEmpty)
                        ...bullets.map((b) => pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 15, top: 2),
                              child: pw.Text('- $b', style: pw.TextStyle(font: regularFont, fontSize: 10)),
                            )),
                    ],
                  ),
                );
              }),
            pw.SizedBox(height: 20),

            pw.Text('Certificates:', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColor.fromHex('#2563EB'))),
            pw.SizedBox(height: 6),
            if (data.certifications.isEmpty)
              pw.Text('No certificates added.', style: pw.TextStyle(font: italicFont, fontSize: 11, color: PdfColors.grey))
            else
              ...data.certifications.map((e) {
                final title = e['title'] as String? ?? '';
                final issuer = e['issuer'] as String? ?? '';
                final date = e['date'] as String? ?? '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6, left: 10),
                  child: pw.Text('• $title by $issuer ($date)', style: pw.TextStyle(font: regularFont, fontSize: 11)),
                );
              }),
            pw.SizedBox(height: 20),

            pw.Text('Achievements:', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColor.fromHex('#2563EB'))),
            pw.SizedBox(height: 6),
            if (data.achievements.isEmpty)
              pw.Text('No achievements added.', style: pw.TextStyle(font: italicFont, fontSize: 11, color: PdfColors.grey))
            else
              ...data.achievements.map((e) {
                final title = e['title'] as String? ?? '';
                final parts = title.split('|');
                final desc = parts[0];
                final date = parts.length > 1 ? ' (${parts[1]})' : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6, left: 10),
                  child: pw.Text('• $desc$date', style: pw.TextStyle(font: regularFont, fontSize: 11)),
                );
              }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSkillCategory(
    String label,
    List<Map<String, dynamic>> allSkills,
    String categoryName,
    pw.Font regularFont,
    pw.Font italicFont,
  ) {
    final catSkills = allSkills
        .where((s) => (s['category'] as String? ?? '') == categoryName)
        .map((s) => s['name'] as String)
        .join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 15, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(font: italicFont, fontSize: 11),
          ),
          pw.Expanded(
            child: pw.Text(
              catSkills.isNotEmpty ? catSkills : 'None',
              style: pw.TextStyle(font: regularFont, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching settings
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Profile Context',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<ProfileContextData>(
        future: _profileDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading profile details: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brief Detail Title
                          Center(
                            child: Text(
                              'Brief Detail',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Personal Details
                          _buildFieldRow('Name:', data.user?.name ?? ""),
                          _buildFieldRow('Email id:', data.user?.email ?? ""),
                          _buildFieldRow('Phone no:', data.user?.phone ?? ""),
                          _buildFieldRow('Location:', data.user?.location ?? ""),
                          _buildFieldRow('Github:', data.user?.githubUrl ?? ""),
                          _buildFieldRow('Linkedin:', data.user?.linkedinUrl ?? ""),
                          const SizedBox(height: 24),

                          // Skills
                          _buildSectionHeader('Skills:'),
                          _buildSkillCategoryRow('Language:', data.skills, 'Languages'),
                          _buildSkillCategoryRow('Tools/platform:', data.skills, 'Tools/Platforms'),
                          _buildSkillCategoryRow('DevOps & Cloud:', data.skills, 'DevOps & Cloud'),
                          _buildSkillCategoryRow('Soft skills:', data.skills, 'Soft Skills'),
                          const SizedBox(height: 24),

                          // Education
                          _buildSectionHeader('Education:'),
                          if (data.education.isEmpty)
                            _buildEmptyPlaceholder()
                          else
                            ...data.education.map((e) {
                              final degree = e['degree'] as String? ?? 'Higher Education';
                              final isSchool = degree == '10th Standard' || degree == '12th Standard';
                              final inst = e['institution'] as String? ?? '';
                              final endYr = e['endYear'] as String? ?? '';
                              final startYr = e['startYear'] as String? ?? '';
                              final city = e['city'] as String? ?? '';
                              final state = e['state'] as String? ?? '';

                              if (isSchool) {
                                final board = e['board'] as String? ?? '';
                                final pct = e['percentage'] as String? ?? '';
                                final stream = e['stream'] as String? ?? '';
                                final streamStr = stream.isNotEmpty ? ' ($stream)' : '';
                                return _buildBulletItem(
                                  '$degree$streamStr - $inst (Board: $board, Passing Year: $endYr), $city, $state - $pct',
                                );
                              } else {
                                final spec = e['specialisation'] as String? ?? '';
                                final cgpa = e['cgpa'] as String? ?? '';
                                final specStr = spec.isNotEmpty ? ' in $spec' : '';
                                final cgpaStr = cgpa.isNotEmpty ? ' - CGPA/Pct: $cgpa' : '';
                                final duration = (startYr.isNotEmpty && endYr.isNotEmpty) ? ' ($startYr - $endYr)' : '';
                                return _buildBulletItem(
                                  '$degree$specStr - $inst$duration, $city, $state$cgpaStr',
                                );
                              }
                            }),
                          const SizedBox(height: 24),

                          // Experience
                          _buildSectionHeader('Experience:'),
                          if (data.experience.isEmpty)
                            _buildEmptyPlaceholder()
                          else
                            ...data.experience.map((e) {
                              final role = e['role'] as String? ?? '';
                              final comp = e['company'] as String? ?? '';
                              final duration = e['duration'] as String? ?? '';
                              final bullets = e['bullets'] as List? ?? [];

                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• $role at $comp ($duration)',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (bullets.isNotEmpty)
                                      ...bullets.map((b) => Padding(
                                            padding: const EdgeInsets.only(left: 20, top: 4),
                                            child: Text(
                                              '- $b',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 13,
                                              ),
                                            ),
                                          )),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 24),

                          // Certificates
                          _buildSectionHeader('Certificates:'),
                          if (data.certifications.isEmpty)
                            _buildEmptyPlaceholder()
                          else
                            ...data.certifications.map((e) {
                              final title = e['title'] as String? ?? '';
                              final issuer = e['issuer'] as String? ?? '';
                              final date = e['date'] as String? ?? '';
                              return _buildBulletItem('$title by $issuer ($date)');
                            }),
                          const SizedBox(height: 24),

                          // Achievements
                          _buildSectionHeader('Achievements:'),
                          if (data.achievements.isEmpty)
                            _buildEmptyPlaceholder()
                          else
                            ...data.achievements.map((e) {
                              final title = e['title'] as String? ?? '';
                              final parts = title.split('|');
                              final desc = parts[0];
                              final date = parts.length > 1 ? ' (${parts[1]})' : '';
                              return _buildBulletItem('$desc$date');
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0E17),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5B5C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _downloading ? null : () => _handleDownload(data),
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _downloading ? 'Downloading...' : 'Download PDF',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildSkillCategoryRow(String label, List<Map<String, dynamic>> allSkills, String categoryName) {
    final catSkills = allSkills
        .where((s) => (s['category'] as String? ?? '') == categoryName)
        .map((s) => s['name'] as String)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              catSkills.isNotEmpty ? catSkills : 'None',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return const Padding(
      padding: EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        'None added yet.',
        style: TextStyle(color: Colors.black45, fontSize: 13, fontStyle: FontStyle.italic),
      ),
    );
  }
}
