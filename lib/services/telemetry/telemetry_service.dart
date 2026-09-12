import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/config/app_config.dart';

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  String _currentUid = 'anonymous';
  String _currentEmail = '';
  String _appVersion = '1.0.0';

  Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {}

    // Only collect Crashlytics in non-debug mode (or per environment)
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  void setUser({required String uid, String? email}) {
    _currentUid = uid;
    _currentEmail = email ?? '';
    FirebaseCrashlytics.instance.setUserIdentifier(uid);
    if (email != null && email.isNotEmpty) {
      FirebaseCrashlytics.instance.setCustomKey('email', email);
    }
  }

  void clearUser() {
    _currentUid = 'anonymous';
    _currentEmail = '';
    FirebaseCrashlytics.instance.setUserIdentifier('');
  }

  /// Records an error both to Firebase Crashlytics and the Admin Dashboard telemetry stream
  Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    // 1. Firebase Crashlytics
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('[Telemetry] Crashlytics record failed: $e');
    }

    // 2. Dispatch to Admin Dashboard telemetry endpoint asynchronously
    try {
      final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'desktop'));
      final payload = {
        'error': error.toString(),
        'stack': stack?.toString() ?? '',
        'fatal': fatal,
        'uid': _currentUid,
        'email': _currentEmail,
        'appVersion': _appVersion,
        'platform': platform,
      };

      // Non-blocking fire-and-forget HTTP post
      http.post(
        Uri.parse(AppConfig.reportErrorUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).catchError((err) {
        debugPrint('[Telemetry] Admin telemetry report failed: $err');
        return http.Response('', 500);
      });
    } catch (e) {
      debugPrint('[Telemetry] Failed to dispatch admin error report: $e');
    }
  }
}
