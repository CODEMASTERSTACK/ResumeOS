import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_strings.dart';
import '../../routes/route_names.dart';

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

    return Scaffold(
      body: child,
      bottomNavigationBar: _AppBottomNav(
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

class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> destinations;
  final ValueChanged<int> onTap;

  const _AppBottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSelectedGenerate = currentIndex == 2;

    return Container(
      height: 92, // Elevated space to let floating button protrude cleanly without overlap
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Curved White Bottom Bar Container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 72, // Standard white bar height (taller to avoid text overlap)
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: destinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = currentIndex == index;
                    final isGenerate = index == 2;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end, // Align everything to the bottom
                            children: [
                              if (isGenerate)
                                const SizedBox(height: 22) // Empty space placeholder matching icon height perfectly to prevent overflow
                              else
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    key: ValueKey(isSelected),
                                    size: 22,
                                    color: isSelected
                                        ? const Color(0xFF8B6B58) // Signature Brand Brown
                                        : Colors.grey.shade400, // Line-art grey
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF8B6B58)
                                      : Colors.grey.shade500,
                                ),
                                child: Text(item.label),
                              ),
                              const SizedBox(height: 8), // Standard bottom padding
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
            top: -7, // Protrudes beautifully above the curved white bar by half its diameter
            left: screenWidth / 2 - 28, // Perfectly centered horizontally
            child: _FloatingCenterButton(
              isSelected: isSelectedGenerate,
              onTap: () => onTap(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCenterButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingCenterButton({
    required this.isSelected,
    required this.onTap,
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
    // Cycle the icon every 3 seconds
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
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFF8B6B58) : Colors.black,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (widget.isSelected ? const Color(0xFF8B6B58) : Colors.black)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
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
                  ? const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                      key: ValueKey('ai_icon'),
                    )
                  : Text(
                      'R.',
                      key: const ValueKey('r_logo'),
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
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
    );
  }
}
