import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'all'; // 'all', 'direct', 'broadcast'
  final Set<String> _expandedIds = {};

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 10) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base
      body: Stack(
        children: [
          // ── 1. Ambient Volumetric Lighting Mesh ─────────────────
          // Core Bright focal light source (top-left) - almost white-pink bloom
          Positioned(
            top: -60,
            left: -60,
            width: 220,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),

          // Neon Sunlight effect (bright warm golden sunlight leak)
          Positioned(
            top: -100,
            left: -100,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    const Color(0xFFFFFFE0),
                    const Color(0xFFFFEE55).withValues(alpha: 0.5),
                    const Color(0xFFFFB300).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Volumetric Diagonal Light Leak / Spotlight beam
          Positioned(
            top: -120,
            left: -120,
            width: screenHeight * 0.55,
            height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.6),
                      const Color(0xFF723FFD).withValues(alpha: 0.45),
                      const Color(0xFF1E6AFF).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Secondary soft blue highlight (extends center-right)
          Positioned(
            top: 60,
            left: 100,
            width: screenHeight * 0.4,
            height: screenHeight * 0.3,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E6AFF).withValues(alpha: 0.22),
              ),
            ),
          ),

          // Cinematic Blur overlay to blend layers into an immersive aurora bloom
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30),
              ),
            ),
          ),

          // ── 2. Content Foreground Layer ────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF10B981),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Rolling 10-Day Feed',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Mark All Read Button
                      notificationsAsync.maybeWhen(
                        data: (list) {
                          final unreadList = list.where((n) => !n.isRead).toList();
                          if (unreadList.isEmpty) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () {
                              ref.read(readNotificationsProvider.notifier).markAllAsRead(
                                    unreadList.map((n) => n.id).toList(),
                                  );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFCBE349).withValues(alpha: 0.40),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.done_all_rounded,
                                    color: Color(0xFFCBE349),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Read all',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFCBE349),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Main Feed
                Expanded(
                  child: notificationsAsync.when(
                    loading: () => _buildShimmer(),
                    error: (e, _) => Center(
                      child: Text(
                        'Failed to load notifications: $e',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    data: (items) {
                      final directItems = items.where((n) => n.isDirect).toList();
                      final broadcastItems = items.where((n) => !n.isDirect).toList();
                      final unreadCount = items.where((n) => !n.isRead).length;

                      final filtered = items.where((item) {
                        if (_selectedFilter == 'direct') return item.isDirect;
                        if (_selectedFilter == 'broadcast') return !item.isDirect;
                        return true;
                      }).toList();

                      return RefreshIndicator(
                        color: const Color(0xFFCBE349),
                        backgroundColor: const Color(0xFF13111C),
                        onRefresh: () async {
                          ref.invalidate(notificationsStreamProvider);
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 40),
                          children: [
                            // 1. Signature Metrics Banner
                            _buildOverviewBanner(
                              totalCount: items.length,
                              unreadCount: unreadCount,
                              directCount: directItems.length,
                            ),

                            const SizedBox(height: 16),

                            // 2. Signature Segmented Filter Tabs
                            _buildSegmentedFilter(
                              totalCount: items.length,
                              directCount: directItems.length,
                              broadcastCount: broadcastItems.length,
                            ),

                            const SizedBox(height: 18),

                            // 3. Notification Cards or Empty State
                            if (filtered.isEmpty)
                              _buildEmptyState(items.isNotEmpty)
                            else
                              ...List.generate(filtered.length, (idx) {
                                final notification = filtered[idx];
                                final isExpanded = _expandedIds.contains(notification.id);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14.0),
                                  child: _buildNotificationCard(notification, isExpanded),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Overview Metrics Banner (App Signature Pattern) ───────
  Widget _buildOverviewBanner({
    required int totalCount,
    required int unreadCount,
    required int directCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFFCBE349),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Activity Snapshot',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '10-DAY TOTAL',
                  '$totalCount',
                  'Past updates',
                  const Color(0xFFCBE349),
                ),
              ),
              Container(width: 1, height: 45, color: Colors.white.withValues(alpha: 0.08)),
              Expanded(
                child: _buildStatItem(
                  'NEW / UNREAD',
                  '$unreadCount',
                  'Requires review',
                  unreadCount > 0 ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 45, color: Colors.white.withValues(alpha: 0.08)),
              Expanded(
                child: _buildStatItem(
                  'DIRECT ALERTS',
                  '$directCount',
                  'Personal messages',
                  const Color(0xFFD26EAB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String subtitle, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: accentColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ── Segmented Filter Tabs (App Signature Architecture) ────
  Widget _buildSegmentedFilter({
    required int totalCount,
    required int directCount,
    required int broadcastCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _buildSegmentTab('all', 'All', totalCount),
          _buildSegmentTab('direct', 'Personal', directCount),
          _buildSegmentTab('broadcast', 'Broadcasts', broadcastCount),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String key, String title, int count) {
    final isSelected = _selectedFilter == key;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCBE349) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFCBE349).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: isSelected ? const Color(0xFF07060F) : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    color: isSelected ? const Color(0xFF07060F) : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification Card (App Signature Architecture) ────────
  Widget _buildNotificationCard(AppNotificationModel notification, bool isExpanded) {
    final isDirect = notification.isDirect;
    final isRead = notification.isRead;

    return GestureDetector(
      onTap: () {
        ref.read(readNotificationsProvider.notifier).markAsRead(notification.id);
        setState(() {
          if (isExpanded) {
            _expandedIds.remove(notification.id);
          } else {
            _expandedIds.add(notification.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isRead ? 0.02 : 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: !isRead
                ? (isDirect
                    ? const Color(0xFF723FFD).withValues(alpha: 0.55)
                    : const Color(0xFFCBE349).withValues(alpha: 0.55))
                : Colors.white.withValues(alpha: 0.06),
            width: !isRead ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: !isRead
                  ? (isDirect ? const Color(0xFF723FFD) : const Color(0xFFCBE349))
                      .withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: !isRead ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Feature Squircle Avatar Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDirect
                    ? const Color(0xFF723FFD).withValues(alpha: 0.15)
                    : const Color(0xFFCBE349).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDirect
                      ? const Color(0xFF723FFD).withValues(alpha: 0.35)
                      : const Color(0xFFCBE349).withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Icon(
                isDirect ? Icons.person_pin_rounded : Icons.campaign_rounded,
                color: isDirect ? const Color(0xFFB18CFF) : const Color(0xFFCBE349),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Header Row
                  Row(
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDirect
                              ? const Color(0xFF723FFD).withValues(alpha: 0.12)
                              : const Color(0xFFCBE349).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDirect
                                ? const Color(0xFF723FFD).withValues(alpha: 0.35)
                                : const Color(0xFFCBE349).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isDirect ? 'DIRECT FOR YOU' : 'ANNOUNCEMENT',
                          style: GoogleFonts.outfit(
                            color: isDirect ? const Color(0xFFD4BFFF) : const Color(0xFFCBE349),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Relative Timestamp
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeTime(notification.createdAt),
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Unread Glowing Dot
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDirect ? const Color(0xFF38BDF8) : const Color(0xFFCBE349),
                            boxShadow: [
                              BoxShadow(
                                color: (isDirect ? const Color(0xFF38BDF8) : const Color(0xFFCBE349))
                                    .withValues(alpha: 0.8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    notification.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Body
                  Text(
                    notification.body,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: isRead ? 0.60 : 0.85),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: isExpanded ? 50 : 3,
                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),

                  // Expand Toggle Hint
                  if (notification.body.length > 120) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isExpanded ? 'Show less' : 'Read more',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFCBE349),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFCBE349),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State (Matching Original Design DNA) ─────────────
  Widget _buildEmptyState(bool hasOtherNotifications) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFCBE349).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFCBE349).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: Color(0xFFCBE349),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasOtherNotifications
                  ? 'No notifications in this filter'
                  : "You're all caught up!",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasOtherNotifications
                  ? 'Switch back to the "All" tab to view your rolling 10-day updates.'
                  : 'No notifications delivered in the last 10 days. System updates, feature releases, and personal alerts will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer Skeleton Placeholder ───────────────────────────
  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
    );
  }
}
