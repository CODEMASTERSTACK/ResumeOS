import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home & settings
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About ResumeOS',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero App Logo & Intro Section
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ResumeOS',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'ResumeOS is an intelligent, developer-first career optimization platform. It automates the synthesis of elite, ATS-optimized professional portfolios and resumes utilizing advanced GenAI orchestration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Problem Section
            _buildSectionHeader(
              context: context,
              icon: Icons.error_outline_rounded,
              iconColor: const Color(0xFFFF5B5C),
              title: 'The Problem It Solves',
            ),
            const SizedBox(height: 12),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubSection(
                    title: 'The ATS Filter Barrier',
                    description: 'Modern recruitment processes filter out over 75% of resumes using automated Applicant Tracking Systems (ATS) long before a human hiring manager reviews them. Generic resume formats lack the keyword matching and semantic alignments required to pass these strict algorithmic checks.',
                  ),
                  const SizedBox(height: 16),
                  _buildSubSection(
                    title: 'Format & Design Inconsistencies',
                    description: 'Job seekers spend hours fighting text editor layouts, resulting in inconsistent styles, page overflows, or unreadable structures. Converting interactive GitHub repository portfolios and projects into readable resume components manually is both tedious and error-prone.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // How It Works Section
            _buildSectionHeader(
              context: context,
              icon: Icons.offline_bolt_outlined,
              iconColor: const Color(0xFF00D2FF),
              title: 'How It Solves & What It Does',
            ),
            const SizedBox(height: 12),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureRow(
                    icon: Icons.psychology_outlined,
                    iconColor: const Color(0xFF00D2FF),
                    title: 'AI Resume Engineering',
                    description: 'Uses advanced generative language models to optimize summaries, analyze role alignment, write concise positioning strategies, and ensure your experience is highlighted using correct industry keywords.',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureRow(
                    icon: Icons.sync_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'GitHub Portfolio Sync',
                    description: 'Synchronizes your developer repositories in real-time, translating projects directly into polished, formatted resume sections with accurate metadata and descriptions.',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureRow(
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: const Color(0xFFEF4444),
                    title: 'ATS-Compliant Rendering',
                    description: 'Builds resumes in structured layouts matching ATS reading patterns, rendering instantly to high-quality PDF files ready for job portals and application systems.',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureRow(
                    icon: Icons.analytics_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'AI Positioning Analysis',
                    description: 'Instantly runs analysis on your profile to output actionable keywords, career strategy pointers, and JD alignments, giving you clear insights into how to target the role.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Under the Hood Section
            _buildSectionHeader(
              context: context,
              icon: Icons.developer_board_rounded,
              iconColor: const Color(0xFFD26EAB),
              title: 'Under the Hood & Architecture',
            ),
            const SizedBox(height: 12),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubSection(
                    title: 'GenAI Orchestration Engine',
                    description: 'ResumeOS uses Google Gemini 1.5 Pro and Flash models for language generation and structured data parsing. It also incorporates OpenRouter integration to provide secure secondary backup processing.',
                  ),
                  const SizedBox(height: 16),
                  _buildSubSection(
                    title: 'Freemium BYOK Model',
                    description: 'Equipped with the "Owner of Will" feature, ResumeOS supports Bring-Your-Own-Key. Users can set their own API keys stored securely in local device storage, completely bypassing default daily platform caps.',
                  ),
                  const SizedBox(height: 16),
                  _buildSubSection(
                    title: 'Cloud Security and Privacy First',
                    description: 'Built with Firebase Firestore backend utilizing user-authenticated row-level access rules. User credentials and professional records are protected under SSL/TLS HTTPS encryption at all times.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Tech Specs Badge Grid
            _buildSectionHeader(
              context: context,
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Platform Specifications',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildSpecTile('ATS Layouts', '95%+ Compatibility', Icons.verified_outlined, const Color(0xFF10B981)),
                _buildSpecTile('Default LLM', 'Gemini 1.5 Flash', Icons.auto_awesome_rounded, const Color(0xFF8B5CF6)),
                _buildSpecTile('Secondary Engine', 'OpenRouter API', Icons.alt_route_rounded, const Color(0xFFD26EAB)),
                _buildSpecTile('Data Transport', 'SSL/TLS HTTPS', Icons.lock_outline_rounded, const Color(0xFF00D2FF)),
              ],
            ),
            const SizedBox(height: 40),

            // Footer version info
            const Center(
              child: Column(
                children: [
                  Text(
                    'ResumeOS Client Suite',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white30,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Designed and Engineered for Professionals',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white30,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _buildSubSection({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecTile(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white30,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
