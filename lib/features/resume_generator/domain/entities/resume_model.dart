import 'package:cloud_firestore/cloud_firestore.dart';

enum ResumeTemplate { atsProfessional, modernMinimal, compactClean }

enum ResumeStatus { generating, complete, error }

class ResumeModel {
  final String id;
  final String uid;
  final String jobDescription;
  final String jobRole;
  final String companyName;
  final List<String> detectedKeywords;
  final List<String> requiredSkills;
  final List<String> matchedProjectIds;
  final int matchPercentage;
  final ResumeData? generatedResumeData;
  final ResumeTemplate templateUsed;
  final int atsScore;
  final List<String> missingKeywords;
  final ResumeStatus status;
  final String pdfUrl;
  final DateTime? createdAt;

  const ResumeModel({
    required this.id,
    required this.uid,
    required this.jobDescription,
    this.jobRole = '',
    this.companyName = '',
    this.detectedKeywords = const [],
    this.requiredSkills = const [],
    this.matchedProjectIds = const [],
    this.matchPercentage = 0,
    this.generatedResumeData,
    this.templateUsed = ResumeTemplate.atsProfessional,
    this.atsScore = 0,
    this.missingKeywords = const [],
    this.status = ResumeStatus.generating,
    this.pdfUrl = '',
    this.createdAt,
  });

  factory ResumeModel.fromJson(Map<String, dynamic> json) => ResumeModel(
        id: json['id'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        jobDescription: json['jobDescription'] as String? ?? '',
        jobRole: json['jobRole'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        detectedKeywords: _toStringList(json['detectedKeywords']),
        requiredSkills: _toStringList(json['requiredSkills']),
        matchedProjectIds: _toStringList(json['matchedProjectIds']),
        matchPercentage: json['matchPercentage'] as int? ?? 0,
        generatedResumeData: json['generatedResumeData'] != null
            ? ResumeData.fromJson(
                json['generatedResumeData'] as Map<String, dynamic>)
            : null,
        templateUsed: _parseTemplate(json['templateUsed']),
        atsScore: json['atsScore'] as int? ?? 0,
        missingKeywords: _toStringList(json['missingKeywords']),
        status: _parseStatus(json['status']),
        pdfUrl: json['pdfUrl'] as String? ?? '',
        createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      );

  factory ResumeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResumeModel.fromJson({...data, 'id': doc.id});
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.cast<String>();
    return [];
  }

  static ResumeTemplate _parseTemplate(dynamic v) {
    switch (v as String?) {
      case 'modernMinimal':
        return ResumeTemplate.modernMinimal;
      case 'compactClean':
        return ResumeTemplate.compactClean;
      default:
        return ResumeTemplate.atsProfessional;
    }
  }

  static ResumeStatus _parseStatus(dynamic v) {
    switch (v as String?) {
      case 'complete':
        return ResumeStatus.complete;
      case 'error':
        return ResumeStatus.error;
      default:
        return ResumeStatus.generating;
    }
  }
}

class ResumeData {
  final String name;
  final String email;
  final String phone;
  final String location;
  final String githubUrl;
  final String linkedinUrl;
  final String portfolioUrl;
  final String summary;
  final List<ResumeSkillGroup> skillGroups;
  final List<ResumeEducation> education;
  final List<ResumeExperience> experience;
  final List<ResumeProject> projects;
  final List<ResumeCertification> certifications;
  final List<String> achievements;

  // Custom styling settings
  final String primaryColorHex;
  final String fontFamily;
  final double fontSizeScale;

  const ResumeData({
    required this.name,
    required this.email,
    this.phone = '',
    this.location = '',
    this.githubUrl = '',
    this.linkedinUrl = '',
    this.portfolioUrl = '',
    required this.summary,
    this.skillGroups = const [],
    this.education = const [],
    this.experience = const [],
    this.projects = const [],
    this.certifications = const [],
    this.achievements = const [],
    this.primaryColorHex = '#1E3A8A', // default Navy
    this.fontFamily = 'sans',          // default sans
    this.fontSizeScale = 1.0,         // default standard
  });

  factory ResumeData.fromJson(Map<String, dynamic> json) => ResumeData(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        location: json['location'] as String? ?? '',
        githubUrl: json['githubUrl'] as String? ?? '',
        linkedinUrl: json['linkedinUrl'] as String? ?? '',
        portfolioUrl: json['portfolioUrl'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        skillGroups: (json['skillGroups'] as List<dynamic>?)
                ?.map((e) =>
                    ResumeSkillGroup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        education: (json['education'] as List<dynamic>?)
                ?.map((e) =>
                    ResumeEducation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        experience: (json['experience'] as List<dynamic>?)
                ?.map((e) =>
                    ResumeExperience.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        projects: (json['projects'] as List<dynamic>?)
                ?.map((e) =>
                    ResumeProject.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        certifications: (json['certifications'] as List<dynamic>?)
                ?.map((e) =>
                    ResumeCertification.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        achievements: (json['achievements'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
        primaryColorHex: json['primaryColorHex'] as String? ?? '#1E3A8A',
        fontFamily: json['fontFamily'] as String? ?? 'sans',
        fontSizeScale: (json['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'githubUrl': githubUrl,
        'linkedinUrl': linkedinUrl,
        'portfolioUrl': portfolioUrl,
        'summary': summary,
        'skillGroups': skillGroups.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'experience': experience.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'certifications': certifications.map((e) => e.toJson()).toList(),
        'achievements': achievements,
        'primaryColorHex': primaryColorHex,
        'fontFamily': fontFamily,
        'fontSizeScale': fontSizeScale,
      };

  ResumeData copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? githubUrl,
    String? linkedinUrl,
    String? portfolioUrl,
    String? summary,
    List<ResumeSkillGroup>? skillGroups,
    List<ResumeEducation>? education,
    List<ResumeExperience>? experience,
    List<ResumeProject>? projects,
    List<ResumeCertification>? certifications,
    List<String>? achievements,
    String? primaryColorHex,
    String? fontFamily,
    double? fontSizeScale,
  }) =>
      ResumeData(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        githubUrl: githubUrl ?? this.githubUrl,
        linkedinUrl: linkedinUrl ?? this.linkedinUrl,
        portfolioUrl: portfolioUrl ?? this.portfolioUrl,
        summary: summary ?? this.summary,
        skillGroups: skillGroups ?? this.skillGroups,
        education: education ?? this.education,
        experience: experience ?? this.experience,
        projects: projects ?? this.projects,
        certifications: certifications ?? this.certifications,
        achievements: achievements ?? this.achievements,
        primaryColorHex: primaryColorHex ?? this.primaryColorHex,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      );
}

class ResumeSkillGroup {
  final String category;
  final List<String> skills;

  const ResumeSkillGroup({required this.category, required this.skills});

  factory ResumeSkillGroup.fromJson(Map<String, dynamic> json) =>
      ResumeSkillGroup(
        category: json['category'] as String? ?? '',
        skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {'category': category, 'skills': skills};

  ResumeSkillGroup copyWith({
    String? category,
    List<String>? skills,
  }) =>
      ResumeSkillGroup(
        category: category ?? this.category,
        skills: skills ?? this.skills,
      );
}

class ResumeEducation {
  final String institution;
  final String degree;
  final String field;
  final String cgpa;
  final String duration;

  const ResumeEducation({
    required this.institution,
    required this.degree,
    this.field = '',
    this.cgpa = '',
    required this.duration,
  });

  factory ResumeEducation.fromJson(Map<String, dynamic> json) =>
      ResumeEducation(
        institution: json['institution'] as String? ?? '',
        degree: json['degree'] as String? ?? '',
        field: json['field'] as String? ?? '',
        cgpa: json['cgpa'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'degree': degree,
        'field': field,
        'cgpa': cgpa,
        'duration': duration,
      };

  ResumeEducation copyWith({
    String? institution,
    String? degree,
    String? field,
    String? cgpa,
    String? duration,
  }) =>
      ResumeEducation(
        institution: institution ?? this.institution,
        degree: degree ?? this.degree,
        field: field ?? this.field,
        cgpa: cgpa ?? this.cgpa,
        duration: duration ?? this.duration,
      );
}

class ResumeExperience {
  final String company;
  final String role;
  final String duration;
  final List<String> bullets;

  const ResumeExperience({
    required this.company,
    required this.role,
    required this.duration,
    this.bullets = const [],
  });

  factory ResumeExperience.fromJson(Map<String, dynamic> json) =>
      ResumeExperience(
        company: json['company'] as String? ?? '',
        role: json['role'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        bullets: (json['bullets'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'company': company,
        'role': role,
        'duration': duration,
        'bullets': bullets,
      };

  ResumeExperience copyWith({
    String? company,
    String? role,
    String? duration,
    List<String>? bullets,
  }) =>
      ResumeExperience(
        company: company ?? this.company,
        role: role ?? this.role,
        duration: duration ?? this.duration,
        bullets: bullets ?? this.bullets,
      );
}

class ResumeProject {
  final String title;
  final List<String> technologies;
  final List<String> bullets;
  final String githubUrl;
  final String liveUrl;

  const ResumeProject({
    required this.title,
    this.technologies = const [],
    this.bullets = const [],
    this.githubUrl = '',
    this.liveUrl = '',
  });

  factory ResumeProject.fromJson(Map<String, dynamic> json) => ResumeProject(
        title: json['title'] as String? ?? '',
        technologies:
            (json['technologies'] as List<dynamic>?)?.cast<String>() ?? [],
        bullets:
            (json['bullets'] as List<dynamic>?)?.cast<String>() ?? [],
        githubUrl: json['githubUrl'] as String? ?? '',
        liveUrl: json['liveUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'technologies': technologies,
        'bullets': bullets,
        'githubUrl': githubUrl,
        'liveUrl': liveUrl,
      };

  ResumeProject copyWith({
    String? title,
    List<String>? technologies,
    List<String>? bullets,
    String? githubUrl,
    String? liveUrl,
  }) =>
      ResumeProject(
        title: title ?? this.title,
        technologies: technologies ?? this.technologies,
        bullets: bullets ?? this.bullets,
        githubUrl: githubUrl ?? this.githubUrl,
        liveUrl: liveUrl ?? this.liveUrl,
      );
}

class ResumeCertification {
  final String title;
  final String issuer;
  final String date;
  final String credentialUrl;

  const ResumeCertification({
    required this.title,
    required this.issuer,
    required this.date,
    this.credentialUrl = '',
  });

  factory ResumeCertification.fromJson(Map<String, dynamic> json) =>
      ResumeCertification(
        title: json['title'] as String? ?? '',
        issuer: json['issuer'] as String? ?? '',
        date: json['date'] as String? ?? '',
        credentialUrl: json['credentialUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'issuer': issuer,
        'date': date,
        'credentialUrl': credentialUrl,
      };

  ResumeCertification copyWith({
    String? title,
    String? issuer,
    String? date,
    String? credentialUrl,
  }) =>
      ResumeCertification(
        title: title ?? this.title,
        issuer: issuer ?? this.issuer,
        date: date ?? this.date,
        credentialUrl: credentialUrl ?? this.credentialUrl,
      );
}
