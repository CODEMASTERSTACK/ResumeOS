import 'package:cloud_firestore/cloud_firestore.dart';

/// Plain Dart UserModel — no freezed/codegen required
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String location;
  final String githubUrl;
  final String linkedinUrl;
  final String portfolioUrl;
  final String profileImageUrl;
  final String summary;
  final String currentRole;
  final bool onboardingComplete;
  final ResumePreferences resumePreferences;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.location = '',
    this.githubUrl = '',
    this.linkedinUrl = '',
    this.portfolioUrl = '',
    this.profileImageUrl = '',
    this.summary = '',
    this.currentRole = '',
    this.onboardingComplete = false,
    this.resumePreferences = const ResumePreferences(),
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        location: json['location'] as String? ?? '',
        githubUrl: json['githubUrl'] as String? ?? '',
        linkedinUrl: json['linkedinUrl'] as String? ?? '',
        portfolioUrl: json['portfolioUrl'] as String? ?? '',
        profileImageUrl: json['profileImageUrl'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        currentRole: json['currentRole'] as String? ?? '',
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
        resumePreferences: json['resumePreferences'] != null
            ? ResumePreferences.fromJson(
                json['resumePreferences'] as Map<String, dynamic>)
            : const ResumePreferences(),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      );

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'githubUrl': githubUrl,
        'linkedinUrl': linkedinUrl,
        'portfolioUrl': portfolioUrl,
        'profileImageUrl': profileImageUrl,
        'summary': summary,
        'currentRole': currentRole,
        'onboardingComplete': onboardingComplete,
        'resumePreferences': resumePreferences.toJson(),
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? location,
    String? githubUrl,
    String? linkedinUrl,
    String? portfolioUrl,
    String? profileImageUrl,
    String? summary,
    String? currentRole,
    bool? onboardingComplete,
    ResumePreferences? resumePreferences,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        githubUrl: githubUrl ?? this.githubUrl,
        linkedinUrl: linkedinUrl ?? this.linkedinUrl,
        portfolioUrl: portfolioUrl ?? this.portfolioUrl,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        summary: summary ?? this.summary,
        currentRole: currentRole ?? this.currentRole,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        resumePreferences: resumePreferences ?? this.resumePreferences,
        createdAt: createdAt,
      );
}

class ResumePreferences {
  final String defaultTemplate;
  final String font;
  final bool showSummary;
  final bool showProjects;
  final bool showCertifications;
  final bool showAchievements;
  final int maxProjects;
  final int maxPages;

  const ResumePreferences({
    this.defaultTemplate = 'ats_professional',
    this.font = 'Inter',
    this.showSummary = true,
    this.showProjects = true,
    this.showCertifications = true,
    this.showAchievements = true,
    this.maxProjects = 3,
    this.maxPages = 1,
  });

  factory ResumePreferences.fromJson(Map<String, dynamic> json) =>
      ResumePreferences(
        defaultTemplate:
            json['defaultTemplate'] as String? ?? 'ats_professional',
        font: json['font'] as String? ?? 'Inter',
        showSummary: json['showSummary'] as bool? ?? true,
        showProjects: json['showProjects'] as bool? ?? true,
        showCertifications: json['showCertifications'] as bool? ?? true,
        showAchievements: json['showAchievements'] as bool? ?? true,
        maxProjects: json['maxProjects'] as int? ?? 3,
        maxPages: json['maxPages'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'defaultTemplate': defaultTemplate,
        'font': font,
        'showSummary': showSummary,
        'showProjects': showProjects,
        'showCertifications': showCertifications,
        'showAchievements': showAchievements,
        'maxProjects': maxProjects,
        'maxPages': maxPages,
      };
}
