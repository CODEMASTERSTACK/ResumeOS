import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../shared/providers/firebase_providers.dart';

const List<String> _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class ProfileSectionEditScreen extends ConsumerStatefulWidget {
  final String section;
  final Map<String, dynamic>? editItem;

  const ProfileSectionEditScreen({
    super.key,
    required this.section,
    this.editItem,
  });

  @override
  ConsumerState<ProfileSectionEditScreen> createState() => _ProfileSectionEditScreenState();
}

class _ProfileSectionEditScreenState extends ConsumerState<ProfileSectionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Common/Universal Controllers
  late TextEditingController _instCtrl;     // Institution, Company, Issuer
  late TextEditingController _titleCtrl;    // Degree, Role, Certificate Name, Achievement Title
  late TextEditingController _boardCtrl;    // Board
  late TextEditingController _streamCtrl;   // Stream / Specialisation
  late TextEditingController _pctCtrl;      // Percentage or CGPA
  late TextEditingController _startYearCtrl;// Start Year
  late TextEditingController _endYearCtrl;  // End Year
  late TextEditingController _cityCtrl;     // City
  late TextEditingController _stateCtrl;    // State
  late TextEditingController _linkCtrl;     // Certificate Link
  late TextEditingController _bulletsCtrl;  // Experience Description (Bullets)

  // Personal Info Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _headlineCtrl;
  late TextEditingController _githubCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _summaryCtrl;

  bool _enhancingSummary = false;

  // Experience / Certification Dropdowns
  String? _startMonth;
  String? _endMonth;
  bool _isCurrent = false;

  // Real-time bullets tracking
  List<String> _bulletValidationErrors = [];

  @override
  void initState() {
    super.initState();
    final item = widget.editItem ?? {};

    // Determine type values
    _instCtrl = TextEditingController(text: item['institution'] as String? ?? item['company'] as String? ?? item['issuer'] as String? ?? '');
    _titleCtrl = TextEditingController(text: item['degree'] as String? ?? item['role'] as String? ?? item['title'] as String? ?? '');
    _boardCtrl = TextEditingController(text: item['board'] as String? ?? '');
    _streamCtrl = TextEditingController(text: item['stream'] as String? ?? item['specialisation'] as String? ?? item['field'] as String? ?? '');
    _pctCtrl = TextEditingController(text: item['percentage'] as String? ?? item['cgpa'] as String? ?? '');
    _cityCtrl = TextEditingController(text: item['city'] as String? ?? '');
    _stateCtrl = TextEditingController(text: item['state'] as String? ?? '');
    _linkCtrl = TextEditingController(text: item['certificateLink'] as String? ?? '');

    // Personal Info Fields
    _nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: item['email'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: item['phone'] as String? ?? '');
    _locationCtrl = TextEditingController(text: item['location'] as String? ?? '');
    _headlineCtrl = TextEditingController(text: item['currentRole'] as String? ?? '');
    _githubCtrl = TextEditingController(text: item['githubUrl'] as String? ?? '');
    _linkedinCtrl = TextEditingController(text: item['linkedinUrl'] as String? ?? '');
    _summaryCtrl = TextEditingController(text: item['summary'] as String? ?? '');

    // Bullets parsing (experience points)
    final bulletsList = item['bullets'] as List?;
    final initialBullets = bulletsList != null ? bulletsList.join('\n') : (item['description'] as String? ?? '');
    _bulletsCtrl = TextEditingController(text: initialBullets);
    _bulletsCtrl.addListener(_onBulletsChanged);

    // Month / Year Parsing
    _startYearCtrl = TextEditingController(text: item['startYear'] as String? ?? '');
    _endYearCtrl = TextEditingController(text: item['endYear'] as String? ?? '');

    // Parse start month/year if experience or certification
    _startMonth = item['startMonth'] as String?;
    _endMonth = item['endMonth'] as String?;
    _isCurrent = item['isCurrent'] as bool? ?? (item['endDate'] == 'Present' || item['endYear'] == 'Present');

    // Backward compatibility check for duration fields like "2024 - Present" or "Jan 2024 - May 2025"
    final duration = item['duration'] as String? ?? '';
    if (duration.isNotEmpty) {
      final parts = duration.split('-');
      if (parts.length == 2) {
        final startPart = parts[0].trim();
        final endPart = parts[1].trim();

        if (endPart.toLowerCase() == 'present') {
          _isCurrent = true;
        }

        // Try extracting Month and Year
        final startWords = startPart.split(' ');
        if (startWords.length == 2) {
          _startMonth = _findMonthMatch(startWords[0]);
          _startYearCtrl.text = startWords[1];
        } else if (startWords.length == 1) {
          _startYearCtrl.text = startWords[0];
        }

        if (!_isCurrent) {
          final endWords = endPart.split(' ');
          if (endWords.length == 2) {
            _endMonth = _findMonthMatch(endWords[0]);
            _endYearCtrl.text = endWords[1];
          } else if (endWords.length == 1) {
            _endYearCtrl.text = endWords[0];
          }
        }
      }
    }
  }

  String? _findMonthMatch(String value) {
    final lower = value.toLowerCase();
    for (final m in _kMonths) {
      if (m.toLowerCase().startsWith(lower)) return m;
    }
    return null;
  }

  @override
  void dispose() {
    _bulletsCtrl.removeListener(_onBulletsChanged);
    _instCtrl.dispose();
    _titleCtrl.dispose();
    _boardCtrl.dispose();
    _streamCtrl.dispose();
    _pctCtrl.dispose();
    _startYearCtrl.dispose();
    _endYearCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _linkCtrl.dispose();
    _bulletsCtrl.dispose();

    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _headlineCtrl.dispose();
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    _summaryCtrl.dispose();

    super.dispose();
  }

  void _onBulletsChanged() {
    final text = _bulletsCtrl.text;
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final errors = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cleaned = line.replaceFirst(RegExp(r'^[\s\-*•\d\.\)]+'), '').trim();
      final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length > 30) {
        errors.add('Point ${i + 1} exceeds 30 words (${words.length} words limit). Please shorten.');
      }
    }

    if (errors.join('\n') != _bulletValidationErrors.join('\n')) {
      setState(() {
        _bulletValidationErrors = errors;
      });
    }
  }

  String get _screenTitle {
    final isEdit = widget.editItem != null && widget.editItem!['id'] != null;
    switch (widget.section) {
      case 'personal_info':
        return 'Edit Personal Information';
      case 'education':
        final d = widget.editItem?['degree'] as String? ?? 'Education';
        return isEdit ? 'Edit $d Details' : 'Add $d Details';
      case 'experience':
        return isEdit ? 'Edit Experience' : 'Add Experience';
      case 'certifications':
        return isEdit ? 'Edit Certification' : 'Add Certification';
      case 'achievements':
        return isEdit ? 'Edit Achievement' : 'Add Achievement';
      default:
        return 'Edit Profile';
    }
  }

  Future<void> _save() async {
    // Bullets limit validation check
    if (widget.section == 'experience' && _bulletValidationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix bullet points word-limit issues before saving!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    final isEdit = widget.editItem != null && widget.editItem!['id'] != null;
    final itemId = isEdit ? widget.editItem!['id'] as String : '';

    try {
      switch (widget.section) {
        case 'personal_info':
          final data = {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'location': _locationCtrl.text.trim(),
            'currentRole': _headlineCtrl.text.trim(),
            'githubUrl': _githubCtrl.text.trim(),
            'linkedinUrl': _linkedinCtrl.text.trim(),
            'summary': _summaryCtrl.text.trim(),
          };
          await repo.updateUser(uid, data);
          break;

        case 'education':
          final degree = widget.editItem?['degree'] as String? ?? 'Higher Education';
          final isSchool = degree == '10th Standard' || degree == '12th Standard';

          final data = {
            'degree': degree,
            'institution': _instCtrl.text.trim(),
            if (isSchool) 'board': _boardCtrl.text.trim(),
            if (isSchool) 'stream': _streamCtrl.text.trim(),
            if (isSchool) 'percentage': _pctCtrl.text.trim(),
            if (!isSchool) 'specialisation': _streamCtrl.text.trim(),
            if (!isSchool) 'field': _streamCtrl.text.trim(),
            if (!isSchool) 'cgpa': _pctCtrl.text.trim(),
            'startYear': isSchool ? '' : _startYearCtrl.text.trim(),
            'endYear': _endYearCtrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'state': _stateCtrl.text.trim(),
          };

          if (isEdit) {
            await repo.updateEducation(uid, itemId, data);
          } else {
            await repo.addEducation(uid, data);
          }
          break;

        case 'experience':
          final bulletsList = _bulletsCtrl.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          // Build dynamic human readable duration (e.g. "January 2024 - Present")
          final startStr = '${_startMonth ?? 'Jan'} ${_startYearCtrl.text.trim()}';
          final endStr = _isCurrent ? 'Present' : '${_endMonth ?? 'Dec'} ${_endYearCtrl.text.trim()}';
          final durationStr = '$startStr - $endStr';

          final data = {
            'role': _titleCtrl.text.trim(),
            'company': _instCtrl.text.trim(),
            'startMonth': _startMonth ?? '',
            'startYear': _startYearCtrl.text.trim(),
            'endMonth': _isCurrent ? '' : (_endMonth ?? ''),
            'endYear': _isCurrent ? 'Present' : _endYearCtrl.text.trim(),
            'isCurrent': _isCurrent,
            'duration': durationStr,
            'certificateLink': _linkCtrl.text.trim(),
            'bullets': bulletsList,
          };

          if (isEdit) {
            await repo.updateExperience(uid, itemId, data);
          } else {
            await repo.addExperience(uid, data);
          }
          break;

        case 'certifications':
          final startStr = '${_startMonth ?? 'Jan'} ${_startYearCtrl.text.trim()}';
          final endStr = '${_endMonth ?? 'Dec'} ${_endYearCtrl.text.trim()}';
          final durationStr = '$startStr - $endStr';

          final data = {
            'title': _titleCtrl.text.trim(),
            'issuer': _instCtrl.text.trim(),
            'startMonth': _startMonth ?? '',
            'startYear': _startYearCtrl.text.trim(),
            'endMonth': _endMonth ?? '',
            'endYear': _endYearCtrl.text.trim(),
            'date': durationStr,
          };

          if (isEdit) {
            await repo.updateCertification(uid, itemId, data);
          } else {
            await repo.addCertification(uid, data);
          }
          break;

        case 'achievements':
          final data = {
            'title': _titleCtrl.text.trim(),
          };

          if (isEdit) {
            await repo.updateAchievement(uid, itemId, data);
          } else {
            await repo.addAchievement(uid, data);
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_screenTitle.replaceFirst('Edit ', '').replaceFirst('Add ', '')} saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    required bool isCompulsory,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? customValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.error, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: customValidator ?? (isCompulsory
            ? (val) => val == null || val.trim().isEmpty ? 'Compulsory' : null
            : null),
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_nameCtrl, 'Full Name', isCompulsory: true),
        _buildTextField(
          _emailCtrl,
          'Email Address',
          isCompulsory: true,
          type: TextInputType.emailAddress,
          customValidator: (val) {
            if (val == null || val.trim().isEmpty) return 'Compulsory';
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(val.trim())) return 'Enter a valid email address';
            return null;
          },
        ),
        _buildTextField(_phoneCtrl, 'Phone Number', isCompulsory: false, type: TextInputType.phone),
        _buildTextField(_locationCtrl, 'Location', isCompulsory: false),
        _buildTextField(_headlineCtrl, 'Headline / Current Role', isCompulsory: false),
        _buildTextField(_githubCtrl, 'GitHub URL', isCompulsory: false, type: TextInputType.url),
        _buildTextField(_linkedinCtrl, 'LinkedIn URL', isCompulsory: false, type: TextInputType.url),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Professional Summary',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            if (_enhancingSummary)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            else
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () async {
                  final uid = ref.read(currentUserProvider)?.uid;
                  if (uid == null) return;
                  final repo = ref.read(profileRepositoryProvider);

                  setState(() => _enhancingSummary = true);

                  try {
                    final education = await repo.watchEducation(uid).first;
                    final skills = await repo.watchSkills(uid).first;
                    final experience = await repo.watchExperience(uid).first;

                    if (education.isEmpty || skills.isEmpty || experience.isEmpty) {
                      setState(() => _enhancingSummary = false);
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                              SizedBox(width: 10),
                              Text('Enhance with AI'),
                            ],
                          ),
                          content: const SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To generate a tailored, authentic career summary, please complete your Education, Skills, and Experience sections on the main profile screen first.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final certifications = await repo.watchCertifications(uid).first;
                    final achievements = await repo.watchAchievements(uid).first;

                    final projectsSnap = await ref
                        .read(firestoreProvider)
                        .collection('users')
                        .doc(uid)
                        .collection('projects')
                        .get();
                    final projects = projectsSnap.docs.map((d) => d.data()).toList();

                    final skillsList = skills.map((s) => s['name'] as String).toList();

                    final newSummary = await ref
                        .read(geminiServiceImplProvider)
                        .generateAuthenticSummary(
                          name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (widget.editItem?['name'] as String? ?? 'Your Name'),
                          currentRole: _headlineCtrl.text.trim().isNotEmpty ? _headlineCtrl.text.trim() : 'Software Professional',
                          skills: skillsList,
                          experience: experience,
                          education: education,
                          projects: projects,
                          certifications: certifications,
                          achievements: achievements,
                          currentSummary: _summaryCtrl.text.trim(),
                        );

                    if (newSummary.isNotEmpty) {
                      setState(() {
                        _summaryCtrl.text = newSummary;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI professional summary generated! Feel free to review, edit, and click Save.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('AI Enhance failed: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _enhancingSummary = false);
                    }
                  }
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accent),
                label: const Text('AI Enhance', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(_summaryCtrl, '', isCompulsory: false, maxLines: 4, hint: 'Write a professional summary or click AI Enhance to generate one automatically.'),
      ],
    );
  }

  Widget _buildEducationForm() {
    final degree = widget.editItem?['degree'] as String? ?? 'Higher Education';
    final is10th = degree == '10th Standard';
    final isSchool = is10th || degree == '12th Standard';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_instCtrl, isSchool ? 'School Name' : 'Institution / College', isCompulsory: true),
        if (isSchool) ...[
          _buildTextField(_boardCtrl, 'Board, e.g. CBSE', isCompulsory: true),
          const SizedBox(height: 4),
          Text(
            'Stream',
            style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextField(_streamCtrl, '', isCompulsory: true, hint: 'e.g. Humanities, Science, Commerce'),
          if (is10th) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  const Text('Suggestion: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _streamCtrl.text = 'Humanities';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentContainer,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'Humanities',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildTextField(_pctCtrl, 'Percentage (e.g. 88%)', isCompulsory: true),
          _buildTextField(_endYearCtrl, 'Passing Year', isCompulsory: true, type: TextInputType.number),
        ] else ...[
          _buildTextField(_titleCtrl, 'Degree, e.g. B.Tech', isCompulsory: true),
          _buildTextField(_streamCtrl, 'Specialisation, e.g. Computer Science', isCompulsory: true),
          _buildTextField(_pctCtrl, 'CGPA or Percentage, e.g. 9.1 or 88%', isCompulsory: true),
          Row(
            children: [
              Expanded(child: _buildTextField(_startYearCtrl, 'Start Year', isCompulsory: true, type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_endYearCtrl, 'End Year', isCompulsory: true, type: TextInputType.number)),
            ],
          ),
        ],
        Row(
          children: [
            Expanded(child: _buildTextField(_cityCtrl, 'City', isCompulsory: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_stateCtrl, 'State', isCompulsory: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildExperienceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_titleCtrl, 'Role / Job Title', isCompulsory: true),
        _buildTextField(_instCtrl, 'Company Name', isCompulsory: true),
        
        // Month + Year Selector for Start Date
        const Text('Start Date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _startMonth,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Month',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(10)),
                ),
                items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _startMonth = val),
                validator: (val) => val == null ? 'Select Month' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(_startYearCtrl, 'Year', isCompulsory: true, type: TextInputType.number),
            ),
          ],
        ),

        // "Currently Work Here" checkbox
        Row(
          children: [
            Checkbox(
              value: _isCurrent,
              activeColor: AppColors.accent,
              onChanged: (val) => setState(() {
                _isCurrent = val ?? false;
                if (_isCurrent) {
                  _endMonth = null;
                  _endYearCtrl.clear();
                }
              }),
            ),
            const Text('I am currently working in this role', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),

        // End Date fields (shown if not currently working here)
        if (!_isCurrent) ...[
          const Text('End Date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _endMonth,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Month',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _endMonth = val),
                  validator: (val) => val == null ? 'Select Month' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(_endYearCtrl, 'Year', isCompulsory: true, type: TextInputType.number),
              ),
            ],
          ),
        ],

        _buildTextField(_linkCtrl, 'Certificate Link (Optional)', isCompulsory: false, type: TextInputType.url),

        // Job description / Bullet points text area
        const Text(
          'Work Description / Bullet Points',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          _bulletsCtrl,
          '',
          isCompulsory: true,
          maxLines: 6,
          hint: 'Enter each bullet point detail on a new line.\n• Every line must not exceed 30 words.',
        ),

        // Dynamic bullet word-limit validation feedback area
        if (_bulletValidationErrors.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      'Word Limit Violation (Max 30 words per bullet)',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._bulletValidationErrors.map((err) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '• $err',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.error, height: 1.4),
                      ),
                    )),
              ],
            ),
          ),
        ] else if (_bulletsCtrl.text.trim().isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'All bullet points are within the 30-word limit!',
                  style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCertificationsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_titleCtrl, 'Certification Name', isCompulsory: true),
        _buildTextField(_instCtrl, 'Issuer', isCompulsory: true),
        
        // Start Month / Year picker row
        const Text('Start Date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _startMonth,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Month',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(10)),
                ),
                items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _startMonth = val),
                validator: (val) => val == null ? 'Select Month' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(_startYearCtrl, 'Year', isCompulsory: true, type: TextInputType.number),
            ),
          ],
        ),

        // End Month / Year picker row
        const Text('End Date (or Expiry)', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _endMonth,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Month',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(10)),
                ),
                items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _endMonth = val),
                validator: (val) => val == null ? 'Select Month' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(_endYearCtrl, 'Year', isCompulsory: true, type: TextInputType.number),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementsForm() {
    return Column(
      children: [
        _buildTextField(
          _titleCtrl,
          'Achievement Details',
          isCompulsory: true,
          maxLines: 4,
          hint: 'e.g. Secured 1st place in National Hackathon against 100+ competing engineering teams.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget formBody;
    switch (widget.section) {
      case 'personal_info':
        formBody = _buildPersonalInfoForm();
        break;
      case 'education':
        formBody = _buildEducationForm();
        break;
      case 'experience':
        formBody = _buildExperienceForm();
        break;
      case 'certifications':
        formBody = _buildCertificationsForm();
        break;
      case 'achievements':
        formBody = _buildAchievementsForm();
        break;
      default:
        formBody = const Center(child: Text('Invalid Profile Section'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _screenTitle,
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: AppTypography.labelLarge.copyWith(
                  color: (widget.section == 'experience' && _bulletValidationErrors.isNotEmpty)
                      ? AppColors.textDisabled
                      : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: formBody,
          ),
        ),
      ),
    );
  }
}
