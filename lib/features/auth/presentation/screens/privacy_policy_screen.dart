import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF7EFE9), // Soft warm cream/beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7EFE9),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            width: screenWidth > 700 ? 650 : double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(
                      Icons.security_rounded,
                      color: Color(0xFF8B6B58),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'ResumeOS Privacy Policy',
                      style: AppTypography.titleLarge.copyWith(
                        color: const Color(0xFF5A453A),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Last Updated: May 31, 2026',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const Divider(height: 32, color: Color(0xFFE8DCD3)),
                  
                  _buildSectionHeader('1. Overview of Data Privacy'),
                  _buildSectionBody(
                    'At ResumeOS, privacy is a core principle. We design our systems to ensure your professional candidate profiles, resumes, and career details are kept completely secure and under your absolute control. This policy explains what information we collect, how it is processed, and your rights.',
                  ),

                  _buildSectionHeader('2. Information We Collect'),
                  _buildSectionBody(
                    'To operate the ATS resume-optimization platform effectively, we collect only the necessary candidate attributes:\n\n'
                    '• User Identity: Name, email address, display name, and profile pictures when signing in via Google or GitHub OAuth.\n'
                    '• Professional Profiles: Specific data points you enter, including skills, educational background, certifications, achievements, and work experience.\n'
                    '• Generated Resumes: The generated ATS-optimized resumes and portfolio projects stored inside your secure user data tree.\n'
                    '• Repository metadata: If you sync with GitHub, we query and store public repository details (titles, descriptions, language usages) to generate corresponding project sections.',
                  ),

                  _buildSectionHeader('3. How We Process & Share Your Data'),
                  _buildSectionBody(
                    'We do not sell, rent, or trade your personal details with advertisers or data brokers. Your data is strictly shared with the following essential services to operate the platform:\n\n'
                    '• Database Storage: Encrypted data storage via Firebase Firestore.\n'
                    '• Authentication: Managed securely by Firebase Authentication.\n'
                    '• Transactional Emails: Transactional OTP verification codes and reset codes are dispatched via the Resend API.\n'
                    '• AI Optimization: Portions of your experience and job descriptions are securely transmitted to Google Gemini and OpenRouter APIs under HTTPS encryption to compute resume bullets. This text is solely used for processing your prompt, never for training global baseline LLM weights.',
                  ),

                  _buildSectionHeader('4. Strict Data Retention & Deletion Rights'),
                  _buildSectionBody(
                    'We believe in absolute data minimization. Our retention policies are designed to respect your right to be forgotten:\n\n'
                    '• The 10-Minute Unverified Purge: If a user creates an account via manual Email/Password but fails to verify their email address via OTP within 10 minutes, our Cloudflare background cron dynamically and permanently deletes the unverified record from both Firebase Authentication and Firestore database to prevent orphaned records.\n'
                    '• Instant Account Deletion: When you choose to delete your account permanently, the operation is immediate. Our serverless Cloudflare gateway loops through Firestore, wipes all subcollections, and purges the Firebase Auth user without caching copies.',
                  ),

                  _buildSectionHeader('5. Security Measures'),
                  _buildSectionBody(
                    'We utilize HTTPS encryption for all API communication. Firestore rules strictly prohibit other candidates from reading or editing your resume files. Custom developer API keys are stored solely inside secure local device storage and never transit our backend.',
                  ),

                  _buildSectionHeader('6. Compliance (GDPR & CCPA)'),
                  _buildSectionBody(
                    'ResumeOS respects user rights under GDPR and CCPA. You have the right to request access to your stored files, correct errors in your profile, or request complete deletion. You can fulfill these directly within the application settings.',
                  ),

                  _buildSectionHeader('7. Changes to this Policy'),
                  _buildSectionBody(
                    'We may update this Privacy Policy as our features evolve. If significant changes occur, we will notify you inside the dashboard or via your registered email.',
                  ),

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Your privacy is our standard. Thank you for using ResumeOS.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: const Color(0xFF8B6B58),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF5A453A),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 12,
        height: 1.6,
      ),
    );
  }
}
