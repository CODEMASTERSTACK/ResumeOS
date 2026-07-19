import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import '../../routes/route_names.dart';
import 'custom_toast.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _destinations = [
    _NavItem(
      label: AppStrings.navHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      route: RouteNames.dashboard,
    ),
    _NavItem(
      label: AppStrings.navProjects,
      icon: Icons.code_outlined,
      activeIcon: Icons.code_rounded,
      route: RouteNames.projects,
    ),
    _NavItem(
      label: AppStrings.navGenerate,
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      route: RouteNames.generate,
    ),
    _NavItem(
      label: AppStrings.navHistory,
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      route: RouteNames.history,
    ),
    _NavItem(
      label: AppStrings.navProfile,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      route: RouteNames.profile,
    ),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/projects')) return 1;
    if (location.startsWith('/generate')) return 2;
    if (location.startsWith('/history')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _currentIndex(location);

    final hideNav = location == RouteNames.generate;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF07060F),
      body: child,
      bottomNavigationBar: hideNav
          ? null
          : _AppBottomNav(
              currentIndex: currentIndex,
              destinations: _destinations,
              onTap: (index) => context.go(_destinations[index].route),
            ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

class _AppBottomNav extends ConsumerStatefulWidget {
  final int currentIndex;
  final List<_NavItem> destinations;
  final ValueChanged<int> onTap;

  const _AppBottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  @override
  ConsumerState<_AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends ConsumerState<_AppBottomNav> with TickerProviderStateMixin {
  late AnimationController _toastController;
  late Animation<double> _toastAnim;
  ToastEvent? _currentToast;
  Timer? _toastDismissTimer;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Slightly longer for the liquid physics to shine
    );
    _toastAnim = CurvedAnimation(
      parent: _toastController,
      curve: const Cubic(0.2, 0.8, 0.2, 1.15), // Custom springy droplet pop curve
      reverseCurve: Curves.easeInBack, // Smooth liquid absorption snap back
    );
  }

  @override
  void dispose() {
    _toastController.dispose();
    _toastDismissTimer?.cancel();
    super.dispose();
  }

  void _triggerToast(ToastEvent toast) {
    _toastDismissTimer?.cancel();

    if (_toastController.value > 0) {
      // Morph existing toast back, update content, and spring back up
      _toastController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentToast = toast;
          });
          _toastController.forward();
          _startDismissTimer(toast);
        }
      });
    } else {
      setState(() {
        _currentToast = toast;
      });
      _toastController.forward();
      _startDismissTimer(toast);
    }
  }

  void _startDismissTimer(ToastEvent toast) {
    _toastDismissTimer = Timer(toast.duration, () {
      if (mounted) {
        _toastController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentToast = null;
            });
          }
        });
      }
    });
  }

  Widget _buildDynamicIsland(double screenWidth, double progress) {
    if (_currentToast == null) return const SizedBox.shrink();

    Color primaryColor;
    IconData icon;
    String defaultTitle;

    switch (_currentToast!.type) {
      case ToastType.success:
        primaryColor = const Color(0xFF10B981);
        icon = Icons.check_circle_outline_rounded;
        defaultTitle = 'Success';
        break;
      case ToastType.error:
        primaryColor = const Color(0xFFEF4444);
        icon = Icons.error_outline_rounded;
        defaultTitle = 'Error';
        break;
      case ToastType.info:
        primaryColor = const Color(0xFF1E5FF5);
        icon = Icons.info_outline_rounded;
        defaultTitle = 'Information';
        break;
    }

    final targetWidth = screenWidth - 32;
    const targetHeight = 74.0;
    const targetLeft = 16.0;
    const targetTop = -90.0; // Float beautifully above the curved nav bar

    double currentWidth;
    double currentHeight;
    double currentLeft;
    double currentTop;
    double currentRadius;

    if (progress < 0.4) {
      // Phase 1: Stretching upward like a liquid droplet (0.0 to 0.4)
      final t = progress / 0.4;
      // Width shrinks slightly for volume conservation
      currentWidth = 56.0 + (48.0 - 56.0) * t;
      // Height stretches upward to form an oval droplet
      currentHeight = 56.0 + (80.0 - 56.0) * t;
      // Move up towards detaching point
      currentTop = -7.0 + (-50.0 - (-7.0)) * t;
      // Center horizontally
      currentLeft = screenWidth / 2 - (currentWidth / 2);
      // Circle/oval corners
      currentRadius = currentWidth / 2;
    } else {
      // Phase 2: Detaching and expanding horizontally into dynamic island (0.4 to 1.0)
      final t = (progress - 0.4) / 0.6;
      // Width expands from droplet width to full width
      currentWidth = 48.0 + (targetWidth - 48.0) * t;
      // Height settles from stretched height to final height
      currentHeight = 80.0 + (targetHeight - 80.0) * t;
      // Top finishes moving to floating position
      currentTop = -50.0 + (targetTop - (-50.0)) * t;
      // Left moves to horizontal margins
      currentLeft = (screenWidth / 2 - 24) + (targetLeft - (screenWidth / 2 - 24)) * t;
      // Radius morphs to final rounded corners
      currentRadius = 24.0 + (20.0 - 24.0) * t;
    }

    // Content Opacity (fade in quickly as the dynamic island finishes horizontal expansion)
    final contentOpacity = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);

    return Positioned(
      top: currentTop,
      left: currentLeft,
      child: GestureDetector(
        onTap: () {
          _toastDismissTimer?.cancel();
          _toastController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _currentToast = null;
              });
            }
          });
        },
        child: Container(
          width: currentWidth,
          height: currentHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF13111C),
            borderRadius: BorderRadius.circular(currentRadius),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: progress < 0.65
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: contentOpacity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentToast!.title ?? defaultTitle,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentToast!.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.close_rounded,
                        color: Colors.white38,
                        size: 14,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ToastEvent?>(toastEventProvider, (prev, next) {
      if (next != null) {
        _triggerToast(next);
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isSelectedGenerate = widget.currentIndex == 2;

    return AnimatedBuilder(
      animation: _toastAnim,
      builder: (context, child) {
        final progress = _toastAnim.value;
        final isToastActive = _currentToast != null && progress > 0.0;

        // Squish the Generate button to 0.8 scale during launch tension, then snap it back to 1.0 once the droplet detaches
        double generateBtnScale;
        if (progress <= 0.3) {
          generateBtnScale = 1.0 - (progress / 0.3) * 0.2;
        } else if (progress <= 0.6) {
          generateBtnScale = 0.8 + ((progress - 0.3) / 0.3) * 0.2;
        } else {
          generateBtnScale = 1.0;
        }

        return Container(
          height: 92,
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Curved Dark Bottom Bar Container
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0B10),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: widget.destinations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = widget.currentIndex == index;
                        final isGenerate = index == 2;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onTap(index),
                            behavior: HitTestBehavior.opaque,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isGenerate)
                                    const SizedBox(height: 22)
                                  else
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        isSelected ? item.activeIcon : item.icon,
                                        key: ValueKey(isSelected),
                                        size: 22,
                                        color: isSelected
                                            ? const Color(0xFFCBE349)
                                            : Colors.white.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? const Color(0xFFCBE349)
                                          : Colors.white.withValues(alpha: 0.35),
                                    ),
                                    child: Text(item.label),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // 2. The Overlapping Floating Center Circular Button (index 2: Generate)
              Positioned(
                top: -7,
                left: screenWidth / 2 - 28,
                child: _FloatingCenterButton(
                  isSelected: isSelectedGenerate,
                  onTap: () => widget.onTap(2),
                  scale: generateBtnScale,
                ),
              ),

              // 3. Dynamic Island Droplet Toast
              if (isToastActive) _buildDynamicIsland(screenWidth, progress),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingCenterButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  const _FloatingCenterButton({
    required this.isSelected,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  State<_FloatingCenterButton> createState() => _FloatingCenterButtonState();
}

class _FloatingCenterButtonState extends State<_FloatingCenterButton> {
  bool _showAiIcon = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _showAiIcon = !_showAiIcon;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: widget.scale,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.isSelected ? const Color(0xFFCBE349) : const Color(0xFF1E1C2B),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: widget.isSelected ? 0.15 : 0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isSelected ? const Color(0xFFCBE349) : Colors.black)
                      .withValues(alpha: widget.isSelected ? 0.35 : 0.15),
                  blurRadius: widget.isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: _showAiIcon
                    ? Icon(
                        Icons.auto_awesome_rounded,
                        color: widget.isSelected ? Colors.black : Colors.white,
                        size: 24,
                        key: const ValueKey('ai_icon'),
                      )
                    : Text(
                        'R.',
                        key: const ValueKey('r_logo'),
                        style: GoogleFonts.playfairDisplay(
                          color: widget.isSelected ? Colors.black : Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
