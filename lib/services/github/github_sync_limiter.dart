import 'package:shared_preferences/shared_preferences.dart';

class SyncLimitStatus {
  final bool isBlocked;
  final String message;
  final Duration? cooldownRemaining;
  final int limitLeftToday;
  final bool showWarning;

  const SyncLimitStatus({
    required this.isBlocked,
    required this.message,
    this.cooldownRemaining,
    this.limitLeftToday = 80,
    this.showWarning = false,
  });
}

class GitHubSyncLimiter {
  static const _keyTimestamps = 'github_sync_timestamps';
  static const _keyBlockedUntil = 'github_sync_blocked_until';

  /// Check the current rate limit status.
  static Future<SyncLimitStatus> checkLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Check if explicitly blocked
      final blockedUntilStr = prefs.getString(_keyBlockedUntil);
      if (blockedUntilStr != null) {
        final blockedUntil = DateTime.tryParse(blockedUntilStr);
        if (blockedUntil != null && now.isBefore(blockedUntil)) {
          final remaining = blockedUntil.difference(now);
          final isDayBlock = remaining.inHours > 2; // if more than 2h, it's likely the 24h block
          final msg = isDayBlock
              ? 'Daily sync limit reached (80 refreshes). Activated for 24h.'
              : 'Hourly sync limit reached (55 refreshes). Activated for 2h.';
          return SyncLimitStatus(
            isBlocked: true,
            message: msg,
            cooldownRemaining: remaining,
            limitLeftToday: 0,
            showWarning: false,
          );
        } else if (blockedUntil != null) {
          // Block expired, clean up
          await prefs.remove(_keyBlockedUntil);
        }
      }

      // Load timestamps
      final timestamps = await _getTimestamps(prefs);
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final oneDayAgo = now.subtract(const Duration(hours: 24));

      // Filter lists
      final hourTimestamps = timestamps.where((t) => t.isAfter(oneHourAgo)).toList();
      final dayTimestamps = timestamps.where((t) => t.isAfter(oneDayAgo)).toList();

      final hourCount = hourTimestamps.length;
      final dayCount = dayTimestamps.length;

      // 1. Check daily hard limit
      if (dayCount >= 80) {
        final blockTime = now.add(const Duration(hours: 24));
        await prefs.setString(_keyBlockedUntil, blockTime.toIso8601String());
        return SyncLimitStatus(
          isBlocked: true,
          message: 'Daily sync limit reached (80 refreshes). Activated for 24h.',
          cooldownRemaining: const Duration(hours: 24),
          limitLeftToday: 0,
          showWarning: false,
        );
      }

      // 2. Check hourly hard limit
      if (hourCount >= 55) {
        final blockTime = now.add(const Duration(hours: 2));
        await prefs.setString(_keyBlockedUntil, blockTime.toIso8601String());
        return SyncLimitStatus(
          isBlocked: true,
          message: 'Hourly sync limit reached (55 refreshes). Activated for 2h.',
          cooldownRemaining: const Duration(hours: 2),
          limitLeftToday: 0,
          showWarning: false,
        );
      }

      // 3. Check warning threshold (> 45 in 1 hour)
      if (hourCount > 45) {
        final left = 55 - hourCount;
        return SyncLimitStatus(
          isBlocked: false,
          message: 'Approaching hourly limit. Limit left to fetch today: $left',
          limitLeftToday: left,
          showWarning: true,
        );
      }

      // Default safe state
      final remainingDayFetches = 80 - dayCount;
      return SyncLimitStatus(
        isBlocked: false,
        message: 'Sync limit left: $remainingDayFetches',
        limitLeftToday: remainingDayFetches,
        showWarning: false,
      );
    } catch (_) {
      // Fallback in case of SharedPreferences errors
      return const SyncLimitStatus(
        isBlocked: false,
        message: '',
        limitLeftToday: 80,
        showWarning: false,
      );
    }
  }

  /// Record a successful sync operation.
  static Future<void> recordSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final timestamps = await _getTimestamps(prefs);
      
      // Add current timestamp
      timestamps.add(now);

      // Prune timestamps older than 24 hours to keep the list clean and small
      final oneDayAgo = now.subtract(const Duration(hours: 24));
      final cleanTimestamps = timestamps.where((t) => t.isAfter(oneDayAgo)).toList();

      // Save back
      final listStr = cleanTimestamps.map((t) => t.toIso8601String()).toList();
      await prefs.setStringList(_keyTimestamps, listStr);

      // Recalculate block state to immediately set blockedUntil if they just reached 55 or 80
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final hourCount = cleanTimestamps.where((t) => t.isAfter(oneHourAgo)).length;
      final dayCount = cleanTimestamps.length; // since cleanTimestamps is already filtered for 24h

      if (dayCount >= 80) {
        final blockTime = now.add(const Duration(hours: 24));
        await prefs.setString(_keyBlockedUntil, blockTime.toIso8601String());
      } else if (hourCount >= 55) {
        final blockTime = now.add(const Duration(hours: 2));
        await prefs.setString(_keyBlockedUntil, blockTime.toIso8601String());
      }
    } catch (_) {}
  }

  /// Helper to load and parse timestamps list.
  static Future<List<DateTime>> _getTimestamps(SharedPreferences prefs) async {
    final list = prefs.getStringList(_keyTimestamps) ?? [];
    final res = <DateTime>[];
    for (final str in list) {
      final dt = DateTime.tryParse(str);
      if (dt != null) res.add(dt);
    }
    return res;
  }
}
