import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../shared/providers/firebase_providers.dart';

const List<String> _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

Map<String, String> _parseCertDate(String dateStr) {
  dateStr = dateStr.trim();
  String month = 'Jan';
  String year = '2025';
  
  if (dateStr.isEmpty) {
    return {'month': month, 'year': year};
  }

  if (dateStr.contains("'")) {
    final parts = dateStr.split("'");
    if (parts.length == 2) {
      final mPart = parts[0].trim();
      final yPart = parts[1].trim();
      
      const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (final m in shortMonths) {
        if (m.toLowerCase() == mPart.toLowerCase()) {
          month = m;
          break;
        }
      }
      
      if (yPart.length == 2) {
        year = '20$yPart';
      } else if (yPart.length == 4) {
        year = yPart;
      }
    }
  } else {
    final parts = dateStr.split(RegExp(r'\s+'));
    if (parts.length == 2) {
      final mPart = parts[0].trim();
      final yPart = parts[1].trim();
      
      const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final matchLength = mPart.length >= 3 ? 3 : mPart.length;
      final matchPrefix = mPart.toLowerCase().substring(0, matchLength);
      for (final m in shortMonths) {
        if (m.toLowerCase().startsWith(matchPrefix)) {
          month = m;
          break;
        }
      }
      
      if (yPart.length == 4) {
        year = yPart;
      } else if (yPart.length == 2) {
        year = '20$yPart';
      }
    } else if (parts.length == 1) {
      final val = parts[0];
      if (val.length == 4 && int.tryParse(val) != null) {
        year = val;
      }
    }
  }
  return {'month': month, 'year': year};
}

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
  late TextEditingController _bullet1Ctrl;  // Experience Bullet Point 1
  late TextEditingController _bullet2Ctrl;  // Experience Bullet Point 2
  late TextEditingController _bullet3Ctrl;  // Experience Bullet Point 3

  // Personal Info Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _headlineCtrl;
  late TextEditingController _githubCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _summaryCtrl;

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

    if (widget.section == 'personal_info') {
      final locParts = _parseLocationParts(item['location'] as String? ?? '');
      _cityCtrl = TextEditingController(text: locParts['city']);
      _stateCtrl = TextEditingController(text: locParts['state']);
      _pincodeCtrl = TextEditingController(text: locParts['pincode']);
    } else {
      _cityCtrl = TextEditingController(text: item['city'] as String? ?? '');
      _stateCtrl = TextEditingController(text: item['state'] as String? ?? '');
      _pincodeCtrl = TextEditingController();
    }

    // Bullets parsing (experience points) — split into 3 individual fields
    final bulletsList = item['bullets'] as List?;
    final rawBullets = bulletsList != null
        ? bulletsList.cast<String>()
        : (item['description'] as String? ?? '').split('\n').where((s) => s.trim().isNotEmpty).toList();
    _bullet1Ctrl = TextEditingController(text: rawBullets.length > 0 ? rawBullets[0] : '');
    _bullet2Ctrl = TextEditingController(text: rawBullets.length > 1 ? rawBullets[1] : '');
    _bullet3Ctrl = TextEditingController(text: rawBullets.length > 2 ? rawBullets[2] : '');
    _bullet1Ctrl.addListener(_onBulletsChanged);
    _bullet2Ctrl.addListener(_onBulletsChanged);
    _bullet3Ctrl.addListener(_onBulletsChanged);

    // Month / Year Parsing
    _startYearCtrl = TextEditingController(text: item['startYear'] as String? ?? '');
    _endYearCtrl = TextEditingController(text: item['endYear'] as String? ?? '');

    // Parse start month/year if experience or certification
    _startMonth = item['startMonth'] as String?;
    _endMonth = item['endMonth'] as String?;
    _isCurrent = item['isCurrent'] as bool? ?? (item['endDate'] == 'Present' || item['endYear'] == 'Present');

    if (widget.section == 'certifications') {
      final existingDate = item['date'] as String? ?? '';
      final parsed = _parseCertDate(existingDate);
      _startMonth = parsed['month'];
      _startYearCtrl.text = parsed['year']!;
    }

    if (widget.section == 'achievements') {
      final existingTitle = item['title'] as String? ?? '';
      final parts = existingTitle.split('|');
      final descPart = parts[0].trim();
      final datePart = parts.length > 1 ? parts[1].trim() : '';

      _titleCtrl.text = descPart;

      final parsed = _parseCertDate(datePart);
      _startMonth = parsed['month'];
      _startYearCtrl.text = parsed['year']!;
    }

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
    _bullet1Ctrl.removeListener(_onBulletsChanged);
    _bullet2Ctrl.removeListener(_onBulletsChanged);
    _bullet3Ctrl.removeListener(_onBulletsChanged);
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
    _bullet1Ctrl.dispose();
    _bullet2Ctrl.dispose();
    _bullet3Ctrl.dispose();

    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _pincodeCtrl.dispose();
    _headlineCtrl.dispose();
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    _summaryCtrl.dispose();

    super.dispose();
  }

  void _onBulletsChanged() {
    final ctrls = [_bullet1Ctrl, _bullet2Ctrl, _bullet3Ctrl];
    final errors = <String>[];

    for (int i = 0; i < ctrls.length; i++) {
      final text = ctrls[i].text.trim();
      if (text.isEmpty) continue;
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length > 30) {
        errors.add('Bullet ${i + 1} exceeds 30 words (${words.length} words). Please shorten.');
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
          final city = _cityCtrl.text.trim();
          final state = _stateCtrl.text.trim();
          final pincode = _pincodeCtrl.text.trim();
          final capCity = city.isNotEmpty ? city[0].toUpperCase() + city.substring(1) : '';
          final capState = state.isNotEmpty ? state[0].toUpperCase() + state.substring(1) : '';
          final locationStr = city.isEmpty ? '' : '$capCity, $capState, $pincode';

          final data = {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'location': locationStr,
            'currentRole': _headlineCtrl.text.trim(),
            'githubUrl': _githubCtrl.text.trim(),
            'linkedinUrl': _linkedinCtrl.text.trim(),
            'summary': _summaryCtrl.text.trim(),
          };
          await repo.updateUser(uid, data);
          break;

        case 'education':
          final origDegree = widget.editItem?['degree'] as String? ?? 'Higher Education';
          final isSchool = origDegree == '10th Standard' || origDegree == '12th Standard';
          final degree = isSchool ? origDegree : _titleCtrl.text.trim();

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
          final bulletsList = [_bullet1Ctrl, _bullet2Ctrl, _bullet3Ctrl]
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          // Build dynamic human readable duration (e.g. "January 2024 - Present")
          final startStr = '${_startMonth ?? 'Jan'} ${_startYearCtrl.text.trim()}';
          final endStr = _isCurrent ? 'Present' : '${_endMonth ?? 'Dec'} ${_endYearCtrl.text.trim()}';
          final durationStr = '$startStr - $endStr';

          // Construct startDate string for database consistency (YYYY-MM)
          final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthIndex = monthNames.indexOf(_startMonth ?? 'Jan') + 1;
          final monthStr = monthIndex.toString().padLeft(2, '0');
          final startYearStr = _startYearCtrl.text.trim();
          final startDateStr = '$startYearStr-$monthStr';

          final data = {
            'role': _titleCtrl.text.trim(),
            'company': _instCtrl.text.trim(),
            'startMonth': _startMonth ?? '',
            'startYear': startYearStr,
            'endMonth': _isCurrent ? '' : (_endMonth ?? ''),
            'endYear': _isCurrent ? 'Present' : _endYearCtrl.text.trim(),
            'isCurrent': _isCurrent,
            'duration': durationStr,
            'certificateLink': _linkCtrl.text.trim(),
            'bullets': bulletsList,
            'startDate': startDateStr,
          };

          if (isEdit) {
            await repo.updateExperience(uid, itemId, data);
          } else {
            await repo.addExperience(uid, data);
          }
          break;

        case 'certifications':
          final month = _startMonth ?? 'Jan';
          final year = _startYearCtrl.text.trim().isEmpty ? '2025' : _startYearCtrl.text.trim();
          final yrShort = year.substring(year.length - 2);
          final durationStr = "$month'$yrShort";

          final data = {
            'title': _titleCtrl.text.trim(),
            'issuer': _instCtrl.text.trim(),
            'startMonth': month,
            'startYear': year,
            'endMonth': '',
            'endYear': '',
            'date': durationStr,
          };

          if (isEdit) {
            await repo.updateCertification(uid, itemId, data);
          } else {
            await repo.addCertification(uid, data);
          }
          break;

        case 'achievements':
          final month = _startMonth ?? 'Jan';
          final year = _startYearCtrl.text.trim().isEmpty ? '2025' : _startYearCtrl.text.trim();
          final yrShort = year.substring(year.length - 2);
          final titleWithDate = "${_titleCtrl.text.trim()}|$month'$yrShort";

          final data = {
            'title': titleWithDate,
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
        CustomToast.show(
          context,
          message: 'Error saving details: $e',
          type: ToastType.error,
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
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFFF5B5C), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFFF5B5C), width: 2),
            borderRadius: BorderRadius.circular(12),
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
        _buildTextField(_cityCtrl, 'City', isCompulsory: false),
        _buildTextField(_stateCtrl, 'State', isCompulsory: false),
        _buildTextField(_pincodeCtrl, 'Pincode', isCompulsory: false),
        _buildTextField(_headlineCtrl, 'Headline / Current Role', isCompulsory: false),
        _buildTextField(_githubCtrl, 'GitHub URL', isCompulsory: false, type: TextInputType.url),
        _buildTextField(_linkedinCtrl, 'LinkedIn URL', isCompulsory: false, type: TextInputType.url),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Professional Summary',
              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () async {
                await context.push('/profile/summary-enhance');
                final uid = ref.read(currentUserProvider)?.uid;
                if (uid != null) {
                  final userProfile = await ref.read(profileRepositoryProvider).getUser(uid);
                  if (userProfile != null && userProfile.summary.isNotEmpty) {
                    _summaryCtrl.text = userProfile.summary;
                  }
                }
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFFD26EAB)),
              label: const Text('AI Enhance', style: TextStyle(color: Color(0xFFD26EAB), fontSize: 13, fontWeight: FontWeight.bold)),
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
          const Text(
            'Stream',
            style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextField(_streamCtrl, '', isCompulsory: true, hint: 'e.g. Humanities, Science, Commerce'),
          if (is10th) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  const Text('Suggestion: ', style: TextStyle(fontSize: 12, color: Colors.white38)),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _streamCtrl.text = 'Humanities';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFCBE349).withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'Humanities',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCBE349),
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
        const Text('Start Date', style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF0C0B10), // Themed dropdown list background
                ),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0C0B10),
                  value: _startMonth,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Month',
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _startMonth = val),
                  validator: (val) => val == null ? 'Select Month' : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(_startYearCtrl, 'Year', isCompulsory: true, type: TextInputType.number),
            ),
          ],
        ),

        // "Currently Work Here" Checkbox
        Row(
          children: [
            Theme(
              data: ThemeData(unselectedWidgetColor: Colors.white30),
              child: Checkbox(
                value: _isCurrent,
                checkColor: Colors.black,
                activeColor: const Color(0xFFCBE349), // Neon Lime Green
                onChanged: (val) => setState(() {
                  _isCurrent = val ?? false;
                  if (_isCurrent) {
                    _endMonth = null;
                    _endYearCtrl.clear();
                  }
                }),
              ),
            ),
            const Text('I am currently working in this role', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),

        // End Date fields (shown if not currently working here)
        if (!_isCurrent) ...[
          const Text('End Date', style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF0C0B10),
                  ),
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0C0B10),
                    value: _endMonth,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Month',
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.03),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _kMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setState(() => _endMonth = val),
                    validator: (val) => val == null ? 'Select Month' : null,
                  ),
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

        // Job description / Bullet Points — 3 individual input rows
        const Text(
          'Work Description / Bullet Points',
          style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter up to 3 bullet points (max 30 words each)',
          style: TextStyle(fontSize: 11, color: Colors.white30),
        ),
        const SizedBox(height: 12),
        _buildBulletInputRow(_bullet1Ctrl, 1),
        _buildBulletInputRow(_bullet2Ctrl, 2),
        _buildBulletInputRow(_bullet3Ctrl, 3),

        // Dynamic bullet word-limit validation feedback area
        if (_bulletValidationErrors.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5B5C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF5B5C).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFF5B5C)),
                    SizedBox(width: 6),
                    Text(
                      'Word Limit Violation (Max 30 words per bullet)',
                      style: TextStyle(color: Color(0xFFFF5B5C), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._bulletValidationErrors.map((err) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '• $err',
                        style: const TextStyle(color: Color(0xFFFF5B5C), fontSize: 11, height: 1.4),
                      ),
                    )),
              ],
            ),
          ),
        ] else if (_bullet1Ctrl.text.trim().isNotEmpty ||
                   _bullet2Ctrl.text.trim().isNotEmpty ||
                   _bullet3Ctrl.text.trim().isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFFCBE349)),
                SizedBox(width: 6),
                Text(
                  'All bullet points are within the 30-word limit!',
                  style: TextStyle(color: Color(0xFFCBE349), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBulletInputRow(TextEditingController ctrl, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFCBE349).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '•',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFCBE349),
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Bullet point $index (max 30 words)...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationsForm() {
    const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final years = List.generate(21, (index) => (2015 + index).toString());
    
    String? matchedMonth;
    if (_startMonth != null) {
      for (final m in shortMonths) {
        if (m.toLowerCase() == _startMonth!.toLowerCase() || 
            _startMonth!.toLowerCase().startsWith(m.toLowerCase())) {
          matchedMonth = m;
          break;
        }
      }
    }
    matchedMonth ??= 'Jan';
    _startMonth = matchedMonth;

    String currentYear = _startYearCtrl.text.trim();
    if (currentYear.isEmpty || !years.contains(currentYear)) {
      currentYear = '2025';
      _startYearCtrl.text = currentYear;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_titleCtrl, 'Certification Name', isCompulsory: true),
        _buildTextField(_instCtrl, 'Issuer', isCompulsory: true),
        
        const Text('Date Earned / Expiry', style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF0C0B10),
                ),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0C0B10),
                  value: _startMonth,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                     labelText: 'Month',
                     labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                     floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                     filled: true,
                     fillColor: Colors.white.withValues(alpha: 0.03),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                     focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: shortMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _startMonth = val),
                  validator: (val) => val == null ? 'Select Month' : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF0C0B10),
                ),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0C0B10),
                  value: _startYearCtrl.text.trim().isEmpty ? '2025' : _startYearCtrl.text.trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                     labelText: 'Year',
                     labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                     floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                     filled: true,
                     fillColor: Colors.white.withValues(alpha: 0.03),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                     focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) => setState(() {
                    if (val != null) {
                      _startYearCtrl.text = val;
                    }
                  }),
                  validator: (val) => val == null ? 'Select Year' : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementsForm() {
    const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final years = List.generate(21, (index) => (2015 + index).toString());
    
    String? matchedMonth;
    if (_startMonth != null) {
      for (final m in shortMonths) {
        if (m.toLowerCase() == _startMonth!.toLowerCase() || 
            _startMonth!.toLowerCase().startsWith(m.toLowerCase())) {
          matchedMonth = m;
          break;
        }
      }
    }
    matchedMonth ??= 'Jan';
    _startMonth = matchedMonth;

    String currentYear = _startYearCtrl.text.trim();
    if (currentYear.isEmpty || !years.contains(currentYear)) {
      currentYear = '2025';
      _startYearCtrl.text = currentYear;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          _titleCtrl,
          'Achievement Details',
          isCompulsory: true,
          maxLines: 4,
          hint: 'e.g. Secured 1st place in National Hackathon against 100+ competing engineering teams.',
        ),
        
        const Text('Date Earned / Achieved', style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF0C0B10),
                ),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0C0B10),
                  value: _startMonth,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                     labelText: 'Month',
                     labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                     floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                     filled: true,
                     fillColor: Colors.white.withValues(alpha: 0.03),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                     focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: shortMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _startMonth = val),
                  validator: (val) => val == null ? 'Select Month' : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF0C0B10),
                ),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0C0B10),
                  value: _startYearCtrl.text.trim().isEmpty ? '2025' : _startYearCtrl.text.trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                     labelText: 'Year',
                     labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                     floatingLabelStyle: const TextStyle(color: Color(0xFFCBE349), fontSize: 12),
                     filled: true,
                     fillColor: Colors.white.withValues(alpha: 0.03),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(12)),
                     focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBE349), width: 1.5), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) => setState(() {
                    if (val != null) {
                      _startYearCtrl.text = val;
                    }
                  }),
                  validator: (val) => val == null ? 'Select Year' : null,
                ),
              ),
            ),
          ],
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
        formBody = const Center(child: Text('Invalid Profile Section', style: TextStyle(color: Colors.white70)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _screenTitle,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCBE349)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: (widget.section == 'experience' && _bulletValidationErrors.isNotEmpty)
                      ? Colors.white24
                      : const Color(0xFFCBE349), // Neon Lime Green Save Button
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Poppins',
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

  Map<String, String> _parseLocationParts(String locationStr) {
    final parts = locationStr.split(',').map((s) => s.trim()).toList();
    if (parts.length >= 3) {
      return {
        'city': parts[0],
        'state': parts[1],
        'pincode': parts[2],
      };
    } else if (parts.length == 2) {
      return {
        'city': parts[0],
        'state': parts[1],
        'pincode': '',
      };
    } else if (parts.length == 1) {
      return {
        'city': parts[0],
        'state': '',
        'pincode': '',
      };
    }
    return {
      'city': '',
      'state': '',
      'pincode': '',
    };
  }
}

