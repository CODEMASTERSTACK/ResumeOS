import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/notification_model.dart';

// ── Read Notification IDs StateNotifier ─────────────────────

class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  ReadNotificationsNotifier() : super(<String>{}) {
    _loadReadIds();
  }

  static const _prefKey = 'career_os_read_notifications_v1';

  Future<void> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      state = list.toSet();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    if (state.contains(id)) return;
    final updated = {...state, id};
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, updated.toList());
    } catch (_) {}
  }

  Future<void> markAllAsRead(List<String> ids) async {
    final updated = {...state, ...ids};
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, updated.toList());
    } catch (_) {}
  }
}

final readNotificationsProvider =
    StateNotifierProvider<ReadNotificationsNotifier, Set<String>>((ref) {
  return ReadNotificationsNotifier();
});

// ── Combined 10-Day Notifications Stream ────────────────────

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final currentUid = user?.uid;
  final readIds = ref.watch(readNotificationsProvider);

  // Filter window: Last 10 days
  final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
  final timestampThreshold = Timestamp.fromDate(tenDaysAgo);

  final controller = StreamController<List<AppNotificationModel>>.broadcast();

  final Map<String, AppNotificationModel> globalNotifications = {};
  final Map<String, AppNotificationModel> userNotifications = {};

  void emitMerged() {
    if (controller.isClosed) return;

    final allMap = <String, AppNotificationModel>{};

    // Add global notifications that match criteria
    for (final entry in globalNotifications.entries) {
      final notif = entry.value;
      if (notif.createdAt.isAfter(tenDaysAgo)) {
        if (notif.targetType == 'broadcast' ||
            notif.targetUid == null ||
            notif.targetUid == currentUid) {
          allMap[entry.key] = notif.copyWith(isRead: readIds.contains(notif.id));
        }
      }
    }

    // Add direct user-specific notifications
    for (final entry in userNotifications.entries) {
      final notif = entry.value;
      if (notif.createdAt.isAfter(tenDaysAgo)) {
        allMap[entry.key] = notif.copyWith(isRead: readIds.contains(notif.id));
      }
    }

    final sorted = allMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    controller.add(sorted);
  }

  StreamSubscription? globalSub;
  StreamSubscription? userSub;

  // 1. Listen to global /notifications collection
  try {
    globalSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('createdAt', isGreaterThanOrEqualTo: timestampThreshold)
        .snapshots()
        .listen(
      (snapshot) {
        globalNotifications.clear();
        for (final doc in snapshot.docs) {
          try {
            final notif = AppNotificationModel.fromFirestore(doc);
            globalNotifications[notif.id] = notif;
          } catch (_) {}
        }
        emitMerged();
      },
      onError: (err) {
        if (kDebugMode) {
          print('Global notifications stream error: $err');
        }
        emitMerged();
      },
    );
  } catch (e) {
    if (kDebugMode) {
      print('Failed to setup global notifications stream: $e');
    }
  }

  // 2. Listen to user's private /users/{uid}/notifications subcollection
  if (currentUid != null) {
    try {
      userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .where('createdAt', isGreaterThanOrEqualTo: timestampThreshold)
          .snapshots()
          .listen(
        (snapshot) {
          userNotifications.clear();
          for (final doc in snapshot.docs) {
            try {
              final notif = AppNotificationModel.fromFirestore(
                doc,
                isRead: readIds.contains(doc.id),
              );
              userNotifications[notif.id] = notif;
            } catch (_) {}
          }
          emitMerged();
        },
        onError: (err) {
          if (kDebugMode) {
            print('User-specific notifications stream error: $err');
          }
          emitMerged();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to setup user notifications stream: $e');
      }
    }
  }

  ref.onDispose(() {
    globalSub?.cancel();
    userSub?.cancel();
    controller.close();
  });

  return controller.stream;
});

// ── Unread Count Provider ───────────────────────────────────

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
  return notifs.where((n) => !n.isRead).length;
});
