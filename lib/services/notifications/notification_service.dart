import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  // Stream for in-app foreground notification alerts
  final StreamController<RemoteMessage> _foregroundStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onForegroundMessage => _foregroundStreamController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request notification permissions (Android 13+ and iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('FCM User granted permission: ${settings.authorizationStatus}');
    }

    // 2. Set presentation options for iOS/Apple foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Subscribe to the global broadcast topic
    try {
      await _messaging.subscribeToTopic('all_users');
      if (kDebugMode) {
        print('Subscribed to FCM topic: all_users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to subscribe to topic all_users: $e');
      }
    }

    // 4. Listen for Auth State changes so token & telemetry are synced immediately upon sign-in/session restore
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await syncFcmToken();
      }
    });

    // Also attempt sync immediately if user already cached
    await syncFcmToken();

    // 5. Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveProfileTelemetry(newToken);
    });

    // 6. Handle foreground incoming messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Received foreground notification: ${message.notification?.title}');
      }
      _foregroundStreamController.add(message);
    });

    // 7. Handle notification click when app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Notification opened app: ${message.notification?.title}');
      }
    });
  }

  Future<void> syncFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }

    await _saveProfileTelemetry(token);
  }

  Future<void> _saveProfileTelemetry(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String appVersion = '1.0.0+1';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      String platformName = 'unknown';
      try {
        if (kIsWeb) {
          platformName = 'web';
        } else if (Platform.isAndroid) {
          platformName = 'android';
        } else if (Platform.isIOS) {
          platformName = 'ios';
        } else if (Platform.isWindows) {
          platformName = 'windows';
        } else if (Platform.isMacOS) {
          platformName = 'macos';
        } else if (Platform.isLinux) {
          platformName = 'linux';
        }
      } catch (_) {}

      final Map<String, dynamic> dataToSet = {
        'appVersion': appVersion,
        'platform': platformName,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      if (token != null && token.isNotEmpty) {
        dataToSet['fcmToken'] = token;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        dataToSet,
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        print('Profile telemetry synced (token: ${token != null}, version: $appVersion, platform: $platformName) for: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync profile telemetry to Firestore: $e');
      }
    }
  }
}