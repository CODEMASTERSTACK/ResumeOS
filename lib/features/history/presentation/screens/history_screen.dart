import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/widgets/custom_toast.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Widget _buildStatItem(String label, String value, String subtitle, Color accentColor) {
    final isLong = value.length > 5;
    final double computedFontSize = isLong ? 11 : 18;
    final int computedMaxLines = isLong ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38, // Keeps all three stats columns vertically aligned
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: accentColor,
                fontSize: computedFontSize,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              maxLines: computedMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildStatsHeader(int totalCount, int avgAts, String latestRole) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  Icons.analytics_outlined,
                  color: Color(0xFFCBE349),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Resume Analytics',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Crafted',
                  '$totalCount',
                  'Resumes',
                  const Color(0xFFCBE349),
                ),
              ),
              Container(width: 1, height: 45, color: Colors.white.withValues(alpha: 0.08)),
              Expanded(
                child: _buildStatItem(
                  'Avg. ATS',
                  '$avgAts%',
                  'Score match',
                  avgAts >= 80
                      ? const Color(0xFF10B981)
                      : (avgAts >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                ),
              ),
              Container(width: 1, height: 45, color: Colors.white.withValues(alpha: 0.08)),
              Expanded(
                child: _buildStatItem(
                  'Latest Target',
                  latestRole,
                  'Active pursuit',
                  const Color(0xFFD26EAB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          AppStrings.resumeHistory,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          // 1. Core Bright focal light source (top-left) - almost white-pink bloom
          Positioned(
            top: -60,
            left: -60,
            width: 220,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6), // White-pink core bloom
              ),
            ),
          ),

          // 2. Neon Sunlight effect (bright warm golden sunlight leak)
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
                    const Color(0xFFFFFFE0), // Hot golden white sun core
                    const Color(0xFFFFEE55).withValues(alpha: 0.5), // Vibrant neon yellow bloom
                    const Color(0xFFFFB300).withValues(alpha: 0.25), // Neon amber halo
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 2. Volumetric Diagonal Light Leak / Spotlight beam
          Positioned(
            top: -120,
            left: -120,
            width: screenHeight * 0.55,
            height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15, // Soft diagonal sweep toward center-right
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.6), // Magenta highlight
                      const Color(0xFF723FFD).withValues(alpha: 0.45), // Purple highlight
                      const Color(0xFF1E6AFF).withValues(alpha: 0.25), // Blue accent
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Layered ambient purple glow layer for surrounding bloom
          Positioned(
            top: -50,
            left: -50,
            width: screenHeight * 0.4,
            height: screenHeight * 0.4,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.3),
              ),
            ),
          ),

          // 4. Secondary soft blue highlight (extends center-right)
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

          // 5. Cinematic Blur overlay to blend layers into an immersive aurora bloom
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30), // Integrated background overlay
              ),
            ),
          ),

          // 6. Content list
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: ref
                  .watch(firestoreProvider)
                  .collection('users')
                  .doc(uid)
                  .collection('resumes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _HistoryShimmer();
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _EmptyHistory(
                    onGenerate: () => context.go('/generate'),
                  );
                }

                // Calculate Stats
                final totalCount = docs.length;
                int sumAts = 0;
                String latestRole = 'N/A';
                if (docs.isNotEmpty) {
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    sumAts += data['atsScore'] as int? ?? 0;
                  }
                  final firstData = docs.first.data() as Map<String, dynamic>;
                  latestRole = firstData['jobRole'] as String? ?? 'N/A';
                }
                final avgAts = totalCount == 0 ? 0 : (sumAts / totalCount).round();

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 108),
                  itemCount: docs.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      return _buildStatsHeader(totalCount, avgAts, latestRole);
                    }

                    final docIndex = idx - 1;
                    final doc = docs[docIndex];
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _HistoryCard(
                        resumeId: doc.id,
                        data: data,
                        resumeNumber: (totalCount - docIndex).toString().padLeft(2, '0'),
                        onView: () => context.push('/generate/preview/${doc.id}'),
                        onDelete: () => _confirmDelete(context, ref, uid, doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String uid, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Resume?',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'This cannot be undone. The resume will be permanently removed.',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(firestoreProvider)
                    .collection('users')
                    .doc(uid)
                    .collection('resumes')
                    .doc(id)
                    .delete();
                if (context.mounted) {
                  CustomToast.show(
                    context,
                    message: 'Resume deleted successfully.',
                    type: ToastType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  CustomToast.show(
                    context,
                    message: 'Failed to delete resume: $e',
                    type: ToastType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              AppStrings.delete,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final String resumeId;
  final Map<String, dynamic> data;
  final String resumeNumber;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.resumeId,
    required this.data,
    required this.resumeNumber,
    required this.onView,
    required this.onDelete,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;

  Color get _scoreColor {
    final score = widget.data['atsScore'] as int? ?? 0;
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    final dt = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(dt);

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[dt.month - 1];
    final dayStr = dt.day.toString().padLeft(2, '0');

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minStr = dt.minute.toString().padLeft(2, '0');

    final absoluteStr = "$monthStr $dayStr, ${dt.year} • $hour:$minStr $amPm";

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now ($absoluteStr)';
        return '${diff.inMinutes}m ago ($absoluteStr)';
      }
      return '${diff.inHours}h ago ($absoluteStr)';
    }
    if (diff.inDays == 1) return 'Yesterday ($absoluteStr)';
    if (diff.inDays < 7) return '${diff.inDays}d ago ($absoluteStr)';

    return absoluteStr;
  }

  String _templateLabel(String t) {
    switch (t) {
      case 'atsProfessional':
        return 'ATS Pro';
      case 'modernMinimal':
        return 'Modern';
      case 'compactClean':
        return 'Compact';
      default:
        return 'ATS Pro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.data['jobRole'] as String? ?? 'Resume';
    final score = widget.data['atsScore'] as int? ?? 0;
    final template = widget.data['templateUsed'] as String? ?? 'ats_professional';
    final createdAt = widget.data['createdAt'];
    final detected = widget.data['detectedKeywords'] as List? ?? [];
    final missing = widget.data['missingKeywords'] as List? ?? [];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hovered ? 0.05 : 0.02),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFCBE349).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? const Color(0xFFCBE349).withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: _hovered ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resume Number Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBE349).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '#${widget.resumeNumber}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCBE349),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white38),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ATS Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _scoreColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: GoogleFonts.outfit(
                            color: _scoreColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'ATS',
                          style: GoogleFonts.outfit(
                            color: _scoreColor.withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Keywords and Template Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.015),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, size: 12, color: Colors.white30),
                        const SizedBox(width: 8),
                        Text(
                          'Template: ${_templateLabel(template)} Layout',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (detected.isNotEmpty || missing.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.label_outline_rounded, size: 12, color: Colors.white30),
                          const SizedBox(width: 8),
                          Text(
                            'Keywords: ${detected.length} matched • ${missing.length} missing',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onView,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBE349),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCBE349).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14, color: Colors.black),
                            const SizedBox(width: 6),
                            Text(
                              'View Resume',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                size: 14, color: AppColors.error),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.delete,
                              style: GoogleFonts.outfit(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyHistory({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.history_rounded, size: 36, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.noHistoryYet,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.noHistoryYetSub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onGenerate,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 280),
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052D4), Color(0xFF1E5FF5), Color(0xFF6FB1FC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052D4).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Generate Your First Resume',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryShimmer extends StatelessWidget {
  const _HistoryShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 56, bottom: 108),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF13111C).withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
      ),
    );
  }
}
