import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String targetType; // 'broadcast' or 'user'
  final String? targetUid;
  final String type; // 'announcement', 'direct', 'system', 'points'
  final bool isRead;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetType = 'broadcast',
    this.targetUid,
    this.type = 'announcement',
    this.isRead = false,
  });

  bool get isDirect => targetType == 'user' || type == 'direct';

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    String? targetType,
    String? targetUid,
    String? type,
    bool? isRead,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      targetType: targetType ?? this.targetType,
      targetUid: targetUid ?? this.targetUid,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isRead = false,
  }) {
    final data = doc.data() ?? {};
    DateTime parsedDate = DateTime.now();

    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    }

    return AppNotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      createdAt: parsedDate,
      targetType: data['targetType'] as String? ?? (data['targetUid'] != null ? 'user' : 'broadcast'),
      targetUid: data['targetUid'] as String?,
      type: data['type'] as String? ?? (data['targetType'] == 'user' ? 'direct' : 'announcement'),
      isRead: isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetType': targetType,
      'targetUid': targetUid,
      'type': type,
    };
  }
}
