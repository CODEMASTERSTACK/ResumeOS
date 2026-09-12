import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/route_names.dart';

/// Service for persisting the active screen route and user authentication state
/// across cold starts and process restarts.
class ScreenPersistence {
  static const String _keyLastRoute = 'last_active_screen_route';
  static const String _keyAuthUid = 'last_authenticated_uid';
  static const String _keyOnboardingDone = 'has_ever_completed_onboarding';

  /// Saves the current route if it's an authenticated app route
  static Future<void> saveLastRoute(String route) async {
    if (route.isEmpty) return;

    // Do not save authentication, splash, or transient policy routes
    if (route == RouteNames.splash ||
        route == RouteNames.login ||
        route == RouteNames.signup ||
        route == RouteNames.otpVerify ||
        route == RouteNames.accountDeleted ||
        route == RouteNames.forgotPassword ||
        route.startsWith('/terms') ||
        route.startsWith('/privacy')) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastRoute, route);
    } catch (_) {}
  }

  /// Gets the last active route if valid
  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_keyLastRoute);
      if (route != null &&
          route.isNotEmpty &&
          !route.contains('login') &&
          !route.contains('splash') &&
          !route.contains('otp') &&
          !route.contains('account-deleted')) {
        return route;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Records that an authenticated UID is active on this device
  static Future<void> saveAuthUid(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthUid, uid);
    } catch (_) {}
  }

  /// Checks if an authenticated user UID was saved from a previous session
  static Future<String?> getAuthUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthUid);
    } catch (_) {
      return null;
    }
  }

  /// Flags that onboarding has been completed on this device
  static Future<void> markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingDone, true);
    } catch (_) {}
  }

  /// Checks if onboarding was marked complete locally
  static Future<bool> isOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingDone) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Clears persistence on explicit sign out
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastRoute);
      await prefs.remove(_keyAuthUid);
    } catch (_) {}
  }
}
