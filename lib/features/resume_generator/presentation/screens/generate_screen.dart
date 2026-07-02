import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Provider ───────────────────────────────────────────────

final jobDescriptionProvider = StateProvider<String>((ref) => '');

// ── Generate Screen ────────────────────────────────────────

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _jdCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(jobDescriptionProvider);
    if (existing.isNotEmpty) _jdCtrl.text = existing;
  }

  @override
  void dispose() {
    _jdCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final jd = _jdCtrl.text.trim();
    if (jd.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please paste a complete job description (at least 50 characters)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ref.read(jobDescriptionProvider.notifier).state = jd;
    context.push(RouteNames.generateAnalyze);
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.white54, size: 20),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white24,
            size: 18,
          ),
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
        ),
        Divider(
          color: Colors.white.withValues(alpha: 0.04),
          height: 1,
          indent: 24,
          endIndent: 24,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final userAsync = ref.watch(userProfileProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.dashboard);
      },
      child: Scaffold(

      key: _scaffoldKey,
      backgroundColor: const Color(0xFF07060F),

      // ── Drawer ────────────────────────────────────────────
      drawer: Drawer(
        width: screenWidth * 0.72,
        backgroundColor: const Color(0xFF0C0B14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // User profile header
              userAsync.when(
                data: (user) {
                  final name = user?.name ?? 'User';
                  String domain = 'Technical';
                  if (user != null && user.domainBackground.isNotEmpty) {
                    if (user.domainBackground.toLowerCase() == 'both') {
                      domain = 'Technical + Non-Technical';
                    } else {
                      domain = user.domainBackground
                          .split('-')
                          .map((w) => w.isEmpty
                              ? ''
                              : w[0].toUpperCase() + w.substring(1))
                          .join('-');
                    }
                  }

                  final profileImageUrl = user?.profileImageUrl ?? '';
                  ImageProvider? avatarImage;
                  if (profileImageUrl.isNotEmpty) {
                    avatarImage = NetworkImage(profileImageUrl);
                  } else if (user?.gender.toLowerCase() == 'female') {
                    avatarImage =
                        const AssetImage('assets/images/female.png');
                  } else if (user?.gender.toLowerCase() == 'male') {
                    avatarImage =
                        const AssetImage('assets/images/male.png');
                  }

                  return SafeArea(
                    bottom: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 32, 24, 20),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF723FFD)
                                  .withValues(alpha: 0.15),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  domain,
                                  style: GoogleFonts.outfit(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFCBE349),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              Divider(
                  color: Colors.white.withValues(alpha: 0.06), height: 1),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(RouteNames.profile);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(RouteNames.dashboard);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.code_rounded,
                      title: 'Projects & Research',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(RouteNames.projects);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'History',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(RouteNames.history);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/profile/settings');
                      },
                    ),
                  ],
                ),
              ),

              // Log out + version
              Divider(
                  color: Colors.white.withValues(alpha: 0.06), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(authNotifierProvider.notifier)
                            .signOut();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFF5B5C),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Log out',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFF5B5C),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Version 1.82.1.0',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Body ──────────────────────────────────────────────
      body: Stack(
        children: [
          // Aurora background blobs
          Positioned(
            top: -60, left: -60, width: 200, height: 200,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.5, height: screenHeight * 0.4,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            width: screenHeight * 0.35, height: screenHeight * 0.35,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.22),
              ),
            ),
          ),
          // Blur wash over aurora
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.35),
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: Stack(
              children: [
                // ── Hamburger menu button ──────────────────
                Positioned(
                  top: 12, left: 12,
                  child: GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // ── App wordmark ───────────────────────────
                Positioned(
                  top: 18,
                  left: 0, right: 0,
                  child: Center(
                    child: Text(
                      'ResumeOS',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFCB9B6E),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                // ── Hero heading (vertically centred) ─────
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Paste the job description\nto start building\nyour perfect resume.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'AI will analyse the role and tailor every bullet\nto maximise your ATS match score.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.35),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Floating input capsule ─────────────────
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20, 0, 20,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 160,
                                  ),
                                  child: TextField(
                                    controller: _jdCtrl,
                                    maxLines: null,
                                    keyboardType:
                                        TextInputType.multiline,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Paste the job description here…',
                                      hintStyle: GoogleFonts.outfit(
                                        color: Colors.white
                                            .withValues(alpha: 0.28),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 4),
                                    ),
                                    cursorColor:
                                        const Color(0xFFCBE349),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ValueListenableBuilder(
                                valueListenable: _jdCtrl,
                                builder: (_, value, __) {
                                  final hasText =
                                      value.text.trim().isNotEmpty;
                                  return GestureDetector(
                                    onTap: hasText ? _analyze : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: hasText
                                            ? const Color(0xFFCB9B6E)
                                            : Colors.white.withValues(
                                                alpha: 0.07),
                                        boxShadow: hasText
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                          0xFFCB9B6E)
                                                      .withValues(
                                                          alpha: 0.35),
                                                  blurRadius: 12,
                                                  offset:
                                                      const Offset(
                                                          0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        color: hasText
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.2),
                                        size: 18,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),    // body Stack
    ),    // Scaffold
    );    // PopScope
  }
}
