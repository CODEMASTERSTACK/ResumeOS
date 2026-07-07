import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../routes/route_names.dart';
import 'generate_screen.dart';

class PredefinedRolesScreen extends ConsumerWidget {
  const PredefinedRolesScreen({super.key});

  static const List<Map<String, dynamic>> _categories = [
    {
      'title': 'Engineering & Tech',
      'icon': Icons.code_rounded,
      'roles': [
        'Full-Stack Software Engineer',
        'Frontend Developer',
        'Backend Developer',
        'Mobile App Developer (Flutter/iOS/Android)',
        'DevOps & Cloud Engineer',
        'Embedded Systems Engineer',
        'Security Engineer',
        'QA Automation Engineer',
      ],
    },
    {
      'title': 'Data & Analytics',
      'icon': Icons.insights_rounded,
      'roles': [
        'Data Scientist',
        'Data Engineer',
        'Machine Learning Engineer',
        'AI Research Scientist',
        'Business Intelligence Analyst',
        'Data Analyst',
      ],
    },
    {
      'title': 'Product & Design',
      'icon': Icons.rocket_launch_rounded,
      'roles': [
        'Product Manager',
        'UI/UX Designer',
        'Product Designer',
        'Project Manager',
        'Scrum Master',
        'Technical Writer',
      ],
    },
    {
      'title': 'Finance & Business',
      'icon': Icons.analytics_outlined,
      'roles': [
        'Financial Analyst',
        'Business Analyst',
        'Quantitative Developer',
        'Investment Banking Analyst',
        'Risk Analyst',
        'Corporate Strategist',
      ],
    },
    {
      'title': 'Marketing & Sales',
      'icon': Icons.campaign_rounded,
      'roles': [
        'Marketing Specialist',
        'Growth Hacker',
        'SEO Specialist',
        'Sales Engineer',
        'Content Strategist',
        'Product Marketing Manager',
      ],
    },
  ];

  void _onRoleSelected(BuildContext context, WidgetRef ref, String roleName) {
    // Populate the provider with target role name request instruction
    ref.read(jobDescriptionProvider.notifier).state = 
        'Target Role: $roleName\n(Perform a general industry analysis for this role)';
    
    // Redirect user to the analysis screen
    context.push(RouteNames.generateAnalyze);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          'Pre-Defined Roles',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Aurora gradients
          Positioned(
            top: -60, left: -60, width: 220, height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.55, height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30),
              ),
            ),
          ),

          SafeArea(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: _categories.length,
              itemBuilder: (context, catIdx) {
                final category = _categories[catIdx];
                final List<String> roles = category['roles'] as List<String>;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Header
                      Row(
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            color: const Color(0xFFCBE349),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (category['title'] as String).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid of Roles
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 68,
                        ),
                        itemCount: roles.length,
                        itemBuilder: (context, roleIdx) {
                          final role = roles[roleIdx];
                          return GestureDetector(
                            onTap: () => _onRoleSelected(context, ref, role),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 1,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  role,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
