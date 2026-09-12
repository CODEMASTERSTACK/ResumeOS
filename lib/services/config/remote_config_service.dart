import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../core/config/app_config.dart';

/// App status states determined by Remote Config
enum AppConfigStatus {
  normal,
  maintenance,
  forceUpdate,
  softUpdate,
}

class AppConfigState {
  final AppConfigStatus status;
  final String currentVersion;
  final String minVersion;
  final String latestVersion;
  final String maintenanceMessage;
  final String storeUrl;

  const AppConfigState({
    required this.status,
    required this.currentVersion,
    required this.minVersion,
    required this.latestVersion,
    required this.maintenanceMessage,
    required this.storeUrl,
  });

  static const AppConfigState fallback = AppConfigState(
    status: AppConfigStatus.normal,
    currentVersion: '1.0.0',
    minVersion: '1.0.0',
    latestVersion: '1.0.0',
    maintenanceMessage: '',
    storeUrl: 'https://play.google.com/store/apps/details?id=com.aicareer.ai_career_os',
  );
}

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  AppConfigState? _cachedState;
  AppConfigState? get cachedState => _cachedState;

  /// Fetches and evaluates the app configuration with 100% fail-safe fallback
  Future<AppConfigState> evaluateAppConfig() async {
    // In local debug development, never block the developer with force-update or maintenance
    if (kDebugMode) {
      _cachedState = AppConfigState.fallback;
      return AppConfigState.fallback;
    }

    String currentVersion = '1.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        currentVersion = packageInfo.version;
      }
    } catch (e) {
      debugPrint('[RemoteConfigService] PackageInfo fetch note: $e');
    }

    // Default configuration
    String minVersion = '1.0.0';
    String latestVersion = '1.0.0';
    bool forceUpdate = false;
    bool maintenanceMode = false;
    String maintenanceMessage = 'ResumeOS is currently undergoing scheduled system upgrades. We will be back online shortly.';
    String storeUrl = 'https://play.google.com/store/apps/details?id=com.aicareer.ai_career_os';

    bool fetchedFromBackend = false;

    // 1. Try fetching from Cloudflare/Firestore backend (Real-Time Admin Dashboard sync)
    try {
      final res = await http.get(
        Uri.parse(AppConfig.appConfigUrl),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        minVersion = data['minVersion'] as String? ?? minVersion;
        latestVersion = data['latestVersion'] as String? ?? latestVersion;
        forceUpdate = data['forceUpdate'] as bool? ?? forceUpdate;
        maintenanceMode = data['maintenanceMode'] as bool? ?? maintenanceMode;
        maintenanceMessage = data['maintenanceMessage'] as String? ?? maintenanceMessage;
        storeUrl = data['storeUrl'] as String? ?? storeUrl;
        fetchedFromBackend = true;
      }
    } catch (e) {
      debugPrint('[RemoteConfigService] Backend fetch note: $e');
    }

    // 2. Fallback to Firebase Remote Config if backend was unreachable
    if (!fetchedFromBackend) {
      try {
        final remoteConfig = FirebaseRemoteConfig.instance;
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(hours: 1),
        ));
        await remoteConfig.setDefaults({
          'min_required_version': minVersion,
          'latest_version': latestVersion,
          'force_update': forceUpdate,
          'maintenance_mode': maintenanceMode,
          'maintenance_message': maintenanceMessage,
          'store_url': storeUrl,
        });
        await remoteConfig.fetchAndActivate();

        minVersion = remoteConfig.getString('min_required_version');
        latestVersion = remoteConfig.getString('latest_version');
        forceUpdate = remoteConfig.getBool('force_update');
        maintenanceMode = remoteConfig.getBool('maintenance_mode');
        maintenanceMessage = remoteConfig.getString('maintenance_message');
        storeUrl = remoteConfig.getString('store_url');
      } catch (e) {
        debugPrint('[RemoteConfigService] Firebase Remote Config note: $e');
      }
    }

    // 3. Evaluate state hierarchy
    AppConfigStatus status = AppConfigStatus.normal;

    if (maintenanceMode) {
      status = AppConfigStatus.maintenance;
    } else if (forceUpdate || _compareVersions(currentVersion, minVersion) < 0) {
      status = AppConfigStatus.forceUpdate;
    } else if (_compareVersions(currentVersion, latestVersion) < 0) {
      status = AppConfigStatus.softUpdate;
    }

    final result = AppConfigState(
      status: status,
      currentVersion: currentVersion,
      minVersion: minVersion,
      latestVersion: latestVersion,
      maintenanceMessage: maintenanceMessage,
      storeUrl: storeUrl,
    );

    _cachedState = result;
    return result;
  }

  /// Compares semantic versions (e.g., "1.0.2" vs "1.1.0")
  int _compareVersions(String v1, String v2) {
    try {
      if (v1.isEmpty || v2.isEmpty) return 0;
      final cleanV1 = v1.split('+').first.split('-').first.trim();
      final cleanV2 = v2.split('+').first.split('-').first.trim();
      if (cleanV1.isEmpty || cleanV2.isEmpty) return 0;

      final parts1 = cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final parts2 = cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 != p2) {
          return p1.compareTo(p2);
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
