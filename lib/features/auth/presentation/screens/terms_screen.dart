import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms of Service',
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
                      Icons.gavel_rounded,
                      color: Color(0xFF8B6B58),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'AI Career OS Terms of Service',
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
                  
                  _buildSectionHeader('1. Welcome to AI Career OS'),
                  _buildSectionBody(
                    'Welcome to AI Career OS (also referred to as "SmartResume"). By creating an account or accessing our services, you agree to comply with and be bound by these Terms of Service. Please read them carefully. If you do not agree to these terms, you must not use or register for our platform.',
                  ),

                  _buildSectionHeader('2. Artificial Intelligence Disclosures & Consent'),
                  _buildSectionBody(
                    'AI Career OS leverages advanced Large Language Models (LLMs) via Google Gemini and OpenRouter APIs to analyze job descriptions, parse candidates\' backgrounds, and auto-rewrite highly optimized, professional resume bullets.\n\n'
                    '• Content Generation Accuracy: While our AI models are finely tuned for recruitment and ATS (Applicant Tracking System) optimization, AI-generated content can occasionally contain factual inconsistencies or "hallucinations." You are solely responsible for reviewing, editing, and verifying the absolute truthfulness of any generated resume details before distributing them to potential employers.\n'
                    '• Consent: By uploading resumes, portfolios, or job descriptions, you consent to the secure transfer and processing of this text content via third-party AI APIs.',
                  ),

                  _buildSectionHeader('3. Bring Your Own Key (BYOK) & Billing'),
                  _buildSectionBody(
                    'AI Career OS operates on a Freemium, BYOK (Bring Your Own Key) model to allow developers and power users to scale their usage at zero markup cost.\n\n'
                    '• Key Caching: If you configure custom API keys for Gemini or OpenRouter in the Settings page (under the "Owner of Will" feature), these keys are stored securely in local device storage and are never uploaded to our servers.\n'
                    '• Billing responsibility: When using your own keys, you are directly billed by the respective AI API providers under their standard developer rates. AI Career OS is not liable for any sudden billing surges or model usage limits incurred on your custom API keys.',
                  ),

                  _buildSectionHeader('4. GitHub Integration & Repository Synchronization'),
                  _buildSectionBody(
                    'Our platform allows candidates to sync their professional portfolios directly with GitHub.\n\n'
                    '• Read-Only Access: When you select "Continue with GitHub" or authenticate your repository portfolio, our application requests standard read-only access (e.g., repository list, commit statistics, file structures) to automatically generate descriptive project bullets.\n'
                    '• No Write Permissions: AI Career OS will never request, store, or execute write permissions or administrative access on your GitHub repositories.',
                  ),

                  _buildSectionHeader('5. Account Termination & Permanent Purging'),
                  _buildSectionBody(
                    'You maintain absolute ownership and control over your personal data. You have the right to terminate your account at any time:\n\n'
                    '• Single-Tap Deletion: In the Settings screen under the "Danger Zone," you can permanently delete your account. Tapping "Confirm Delete" triggers an atomic cleanup.\n'
                    '• Zero Retention Purging: Account deletion permanently and irrecoverably wipes your profile, Firestore user trees, nested subcollections (skills, experience, projects, education, achievements, resumes), and purges your authentication record from Firebase Auth. This data cannot be recovered by administrators.',
                  ),

                  _buildSectionHeader('6. Acceptable Use Policy'),
                  _buildSectionBody(
                    'You agree not to use AI Career OS to generate fraudulent credentials, falsify work experience, impersonate other entities, or attempt to reverse-engineer or abuse the Cloudflare serverless gateway or underlying database systems.',
                  ),

                  _buildSectionHeader('7. Limitation of Liability'),
                  _buildSectionBody(
                    'AI Career OS and its developers are provided "as is" without warranties of any kind. We are not liable for any employment outcomes, candidate rejections, resume parsing errors by external systems, or data loss arising from your use of this software.',
                  ),

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Thank you for trusting AI Career OS to accelerate your professional journey.',
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
