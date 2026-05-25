import 'package:cloud_firestore/cloud_firestore.dart';

/// Plain Dart ProjectModel — no freezed required
class ProjectModel {
  final String id;
  final String uid;
  final String title;
  final String description;
  final String githubRepo;
  final String liveUrl;
  final List<String> technologies;
  final List<String> tags;
  final List<String> bulletPoints;
  final String aiSummary;
  final bool isGithubSynced;
  final bool isFeatured;
  final List<String> linkedSkills;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    required this.id,
    required this.uid,
    required this.title,
    this.description = '',
    this.githubRepo = '',
    this.liveUrl = '',
    this.technologies = const [],
    this.tags = const [],
    this.bulletPoints = const [],
    this.aiSummary = '',
    this.isGithubSynced = false,
    this.isFeatured = false,
    this.linkedSkills = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: json['id'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        githubRepo: json['githubRepo'] as String? ?? '',
        liveUrl: json['liveUrl'] as String? ?? '',
        technologies: _toStringList(json['technologies']),
        tags: _toStringList(json['tags']),
        bulletPoints: _toStringList(json['bulletPoints']),
        aiSummary: json['aiSummary'] as String? ?? '',
        isGithubSynced: json['isGithubSynced'] as bool? ?? false,
        isFeatured: json['isFeatured'] as bool? ?? false,
        linkedSkills: _toStringList(json['linkedSkills']),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'title': title,
        'description': description,
        'githubRepo': githubRepo,
        'liveUrl': liveUrl,
        'technologies': technologies,
        'tags': tags,
        'bulletPoints': bulletPoints,
        'aiSummary': aiSummary,
        'isGithubSynced': isGithubSynced,
        'isFeatured': isFeatured,
        'linkedSkills': linkedSkills,
      };

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }

  double scoreAgainst(List<String> keywords) {
    if (keywords.isEmpty) return 0;
    int matches = 0;
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();
    final lowerTech = technologies.map((t) => t.toLowerCase()).toList();
    final lowerSkills = linkedSkills.map((s) => s.toLowerCase()).toList();

    for (final kw in keywords) {
      final lower = kw.toLowerCase();
      if (lowerTitle.contains(lower)) matches += 3;
      if (lowerDesc.contains(lower)) matches += 2;
      if (lowerTech.any((t) => t.contains(lower))) matches += 2;
      if (lowerSkills.any((s) => s.contains(lower))) matches += 2;
    }
    return matches / (keywords.length * 3);
  }
}
