import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../routes/route_names.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFFF5B5C),
                    title: 'Profile Context',
                    subtitle: 'View your complete profile summary & download as PDF',
                    topic: 'profile_context',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'APP INFORMATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF00D2FF),
                    title: 'About ResumeOS',
                    subtitle: 'Overview, core problems solved, and architecture',
                    topic: 'about',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12, top: 4),
              child: Text(
                'LEGAL & COMPLIANCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // Settings menu card
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF6366F1), // Indigo
                    title: 'Privacy Policy',
                    subtitle: 'Data collection, purposes, and sharing policies',
                    topic: 'privacy',
                  ),
                  _buildDivider(),
                  _buildSettingTile(
                    context: context,
                    icon: Icons.key_outlined,
                    iconColor: const Color(0xFF10B981), // Emerald
                    title: 'Authentication Disclosure',
                    subtitle: 'Google & GitHub OAuth scope compliance',
                    topic: 'oauth',
                  ),
                  _buildDivider(),
                  _buildSettingTile(
                    context: context,
                    icon: Icons.auto_awesome_outlined,
                    iconColor: const Color(0xFF8B5CF6), // Royal Purple
                    title: 'AI Data Usage & Disclaimers',
                    subtitle: 'Terms of Service and AI liability releases',
                    topic: 'ai_legal',
                  ),
                  _buildDivider(),
                  _buildSettingTile(
                    context: context,
                    icon: Icons.verified_user_outlined,
                    iconColor: const Color(0xFFF59E0B), // Amber Gold
                    title: 'Data Security & Age Limits',
                    subtitle: 'User rights, security measures, and workforce limits',
                    topic: 'security',
                  ),
                  _buildDivider(),
                  _buildSettingTile(
                    context: context,
                    icon: Icons.token_outlined,
                    iconColor: const Color(0xFFD26EAB), // Rose Pink
                    title: 'Owner of Will',
                    subtitle: 'BYOK Freemium: Configure custom Gemini & OpenRouter keys',
                    topic: 'byok',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12, top: 4),
              child: Text(
                'SUPPORT & FEEDBACK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.bug_report_outlined,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Report an Issue',
                    subtitle: 'Describe a bug or technical issue you encountered',
                    topic: 'report_issue',
                    onTapOverride: () => _showReportIssueDialog(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
              child: Text(
                'ACCOUNT SESSION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // Sign out card
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B5C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFFF5B5C), size: 20),
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFFF5B5C),
                  ),
                ),
                subtitle: const Text(
                  'Securely disconnect your account and session',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                onTap: () {
                  _showSignOutDialog(context, ref);
                },
              ),
            ),

            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
              child: Text(
                'DANGER ZONE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF5B5C),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // Delete account card
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF5B5C).withValues(alpha: 0.2), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B5C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_outlined, color: Color(0xFFFF5B5C), size: 20),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFFF5B5C),
                  ),
                ),
                subtitle: const Text(
                  'Permanently destroy your profile and all resumes',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF5B5C)),
                onTap: () {
                  _showDeleteAccountDialog(context, ref);
                },
              ),
            ),
            
            const SizedBox(height: 32),
            const Center(
              child: Column(
                children: [
                  Text(
                    'ResumeOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String topic,
    VoidCallback? onTapOverride,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTapOverride ?? () {
        if (topic == 'about') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AboutScreen(),
            ),
          );
        } else if (topic == 'byok') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OwnerOfWillScreen(),
            ),
          );
        } else if (topic == 'profile_context') {
          context.go('/profile/context');
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsDetailScreen(topic: topic),
            ),
          );
        }
      },
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Pop Settings screen
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFFFF5B5C), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext parentContext, WidgetRef ref) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0C0B10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5B5C), size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5B5C)),
            ),
          ],
        ),
        content: const Text(
          'All the data including your details, resume and logs will be permanently deleted from our database and they won\'t be recoverable.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              _showProcessingDialog(parentContext); // Show deleting... spinner using parentContext
              await _performAccountDeletion(parentContext, ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B5C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Confirm Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showProcessingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Color(0xFF0C0B10),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFFF5B5C)),
              SizedBox(width: 20),
              Text(
                'Permanently deleting account...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext parentContext, WidgetRef ref) async {
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      
      // Close the processing spinner
      if (parentContext.mounted) {
        Navigator.pop(parentContext); // Close spinner
      }

      // Show toast
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Account permanently deleted.'),
            backgroundColor: Color(0xFF0C0B10),
          ),
        );
      }

      if (parentContext.mounted) {
        parentContext.go(RouteNames.accountDeleted);
      }
      
    } catch (e) {
      // Close spinner
      if (parentContext.mounted) {
        Navigator.pop(parentContext);
      }
      
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFFF5B5C),
          ),
        );
      }
    }
  }

  void _showReportIssueDialog(BuildContext parentContext, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setStateDialog) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.bug_report_outlined, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Report an Issue',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please describe the bug or issue you encountered in detail. We appreciate your feedback!',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter details here...',
                      hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBE349)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: Colors.white38),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCBE349),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final desc = controller.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please describe the issue before submitting.',
                            style: GoogleFonts.outfit(),
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    // Close the input dialog using the dialog's context
                    Navigator.pop(dialogContext);

                    // Show checking limit snackbar using parentContext
                    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Verifying submission limits...',
                          style: GoogleFonts.outfit(),
                        ),
                        backgroundColor: const Color(0xFF1E1C2B),
                      ),
                    );

                    try {
                      final uid = ref.read(currentUserProvider)?.uid;
                      if (uid == null) {
                        throw Exception('User is not authenticated');
                      }

                      // Rate limit check: max 3 reports within 5 days
                      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
                      final recentReports = await ref
                          .read(firestoreProvider)
                          .collection('users')
                          .doc(uid)
                          .collection('reported_issues')
                          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fiveDaysAgo))
                          .get();

                      if (recentReports.docs.length >= 3) {
                        scaffoldMessenger.clearSnackBars();
                        if (parentContext.mounted) {
                          showDialog(
                            context: parentContext,
                            builder: (limitCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_rounded, color: Color(0xFFFFCC00), size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Submission Limit Reached',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'You can report a maximum of 3 issues within a 5-day period to prevent spam. Please try again later.',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCBE349),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.pop(limitCtx),
                                  child: Text(
                                    'OK',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return;
                      }

                      // Show loading indicator / progress snackbar using parentContext
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Reporting issue...',
                            style: GoogleFonts.outfit(),
                          ),
                          backgroundColor: const Color(0xFF1E1C2B),
                        ),
                      );

                      await ref
                          .read(firestoreProvider)
                          .collection('users')
                          .doc(uid)
                          .collection('reported_issues')
                          .add({
                        'description': desc,
                        'createdAt': FieldValue.serverTimestamp(),
                        'status': 'pending',
                      });

                      scaffoldMessenger.clearSnackBars();

                      // Show success message using parentContext
                      if (parentContext.mounted) {
                        showDialog(
                          context: parentContext,
                          builder: (successContext) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E2E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFFCBE349), size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  'Issue Reported',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              "Your issue has been reported and we'll look forward to solving it in the meantime.",
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCBE349),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => Navigator.pop(successContext),
                                child: Text(
                                  'OK',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      scaffoldMessenger.clearSnackBars();
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to report issue: $e',
                              style: GoogleFonts.outfit(),
                            ),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Submit',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class SettingsDetailScreen extends StatelessWidget {
  final String topic;
  const SettingsDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    String title = '';
    List<Widget> content = [];

    switch (topic) {
      case 'privacy':
        title = 'Privacy Policy';
        content = _buildPrivacyContent();
        break;
      case 'oauth':
        title = 'Authentication Disclosure';
        content = _buildOauthContent();
        break;
      case 'ai_legal':
        title = 'AI Terms & Liability';
        content = _buildAiContent();
        break;
      case 'security':
        title = 'Security & Age Limits';
        content = _buildSecurityContent();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPrivacyContent() {
    return [
      _sectionHeader('1. Data We Collect & Scope'),
      _bodyText('We collect the minimum amount of personal and professional information necessary to construct and host your professional resume portfolio:'),
      _bulletPoint('Identity Info', 'Full Name, Profile Photo/Avatar, Email Address, and Phone Number.'),
      _bulletPoint('Professional Profile', 'Education records (Degree, field of study, Board, GPA/Percentage), work/internship details, skills, certifications, and project lists.'),
      _bulletPoint('OAuth Identifiers', 'Unique profile tokens retrieved via secure Google and GitHub OAuth services.'),
      
      const SizedBox(height: 16),
      _sectionHeader('2. Purpose of Collection'),
      _bodyText('Every piece of data gathered is used strictly for core app features:'),
      _bulletPoint('Profile Synthesis', 'Formatting and populating ATS-compliant resume pages.'),
      _bulletPoint('GitHub Integration', 'Reading and synchronizing repository portfolios in real-time.'),
      
      const SizedBox(height: 16),
      _sectionHeader('3. Third-Party Sharing'),
      _bodyText('Because ResumeOS relies on Generative Artificial Intelligence, selected professional highlights (skills, role titles, company names, and project details) are transmitted securely to leading AI APIs (including Gemini, OpenAI, or OpenRouter) strictly for text enhancement. No third-party AI provider receives permanent rights to store or train on your identity. We do not sell or lease candidate details to third-party databases, brokers, or advertisers.'),
      
      const SizedBox(height: 16),
      _sectionHeader('4. Your Rights'),
      _bodyText('Candidates hold absolute legal authority over their private data. You retain rights to access your details at any time, edit/correct them via the Profile Tab, and permanently delete your profile along with all generated resume documents instantly from our databases.'),
    ];
  }

  List<Widget> _buildOauthContent() {
    return [
      _sectionHeader('1. OAuth Data Minimization'),
      _bodyText('In compliance with strict Google and GitHub OAuth API developer rules, we adhere to absolute Data Minimization (Scoping). We strictly request access to basic email and read-only profile scopes (e.g. email, openid, profile, read:user). We will NEVER request permissions to access, view, or modify your personal emails, calendar events, contacts, or source code repositories.'),
      
      const SizedBox(height: 16),
      _sectionHeader('2. Domain & Policy Verification'),
      _bodyText('As dictated by Google developer verification compliance, this official privacy policy is strictly hosted on a verified, owned domain. We do not use Google Docs, plain pastes, or generic URLs, assuring absolute authority and legal safety for OAuth authentication services.'),
      
      const SizedBox(height: 16),
      _sectionHeader('3. Environment Segregation'),
      _bodyText('To prevent developer testing operations from impacting client databases, we maintain fully segregated projects and environments for development (sandboxed, separate OAuth credentials) and production (verified production keys and SSL/TLS protection), ensuring complete account isolation.'),
    ];
  }

  List<Widget> _buildAiContent() {
    return [
      _sectionHeader('1. Real-Time AI Processing'),
      _bodyText('Our AI summary enhancer processes resume parameters in real-time. We explicitly guarantee that candidate resume details are processed in sandboxed sessions and are NEVER used to train the base foundation models of OpenAI, Gemini, or OpenRouter.'),
      
      const SizedBox(height: 16),
      _sectionHeader('2. AI Hallucination & Liability Release'),
      _warningBanner('AI is known to occasionally "hallucinate" or fabricate dates, accomplishments, and skills. The candidate is 100% legally responsible for thoroughly reviewing, editing, and verifying the absolute accuracy of their resume before applying for jobs. The application, developers, and parent companies hold zero liability for job rejections, application cancellations, or career setbacks arising from unverified AI-generated content.'),
      
      const SizedBox(height: 16),
      _sectionHeader('3. Intellectual Property (IP)'),
      _bodyText('Candidates retain 100% intellectual property ownership of the final generated PDF resumes produced by this app. You are free to publish, sell, share, or submit them. ResumeOS retains all proprietary rights to the underlying source code, database structures, graphic assets, layout designs, and generative text algorithms.'),
    ];
  }

  List<Widget> _buildSecurityContent() {
    return [
      _sectionHeader('1. Data Security Measures'),
      _bodyText('We implement multiple security safeguards to protect your personal information from unauthorized access, breach, or theft:'),
      _bulletPoint('Encryption', 'All data transferred between your device and the cloud is fully protected using standard SSL/TLS protocol encryption.'),
      _bulletPoint('Cloud Protection', 'We utilize Google Firebase Firestore built-in security rules to strictly authorize read/write operations to authenticated account owners only.'),
      
      const SizedBox(height: 16),
      _sectionHeader('2. Age Restrictions (18+)'),
      _bodyText('Our resume builder and career enhancement suite is designed exclusively for the adult workforce. In strict alignment with Google Sign-In and developer age-limit guidelines, individuals under the age of 18 (or 16 in select jurisdictions) are prohibited from creating accounts, accessing OAuth authentication, or using our resume enhancement services.'),
      
      const SizedBox(height: 16),
      _sectionHeader('3. Contact Legal Support'),
      _bodyText('If you have any questions regarding these compliance terms, security disclosures, or wish to execute your data deletion rights, please contact our legal desk at compliance@resumeos.com.'),
    ];
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.4,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _bulletPoint(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerOfWillScreen extends StatefulWidget {
  const OwnerOfWillScreen({super.key});

  @override
  State<OwnerOfWillScreen> createState() => _OwnerOfWillScreenState();
}

class _OwnerOfWillScreenState extends State<OwnerOfWillScreen> {
  final _geminiKeyController = TextEditingController();
  final _openRouterKeyController = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureOpenRouter = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyController.text = prefs.getString('custom_gemini_api_key') ?? '';
      _openRouterKeyController.text = prefs.getString('custom_openrouter_api_key') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_gemini_api_key', _geminiKeyController.text.trim());
    await prefs.setString('custom_openrouter_api_key', _openRouterKeyController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Keys saved successfully!'),
          backgroundColor: Color(0xFF0C0B10),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_gemini_api_key');
    await prefs.remove('custom_openrouter_api_key');
    
    setState(() {
      _geminiKeyController.clear();
      _openRouterKeyController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Keys reset to defaults.'),
          backgroundColor: Color(0xFF0C0B10),
        ),
      );
    }
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openRouterKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Owner of Will',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD26EAB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD26EAB).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFFD26EAB).withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFD26EAB), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BYOK Freemium Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFFE88BB4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Provide your own personal Gemini and OpenRouter API credentials to bypass developer platform boundaries. If left empty, the app will gracefully run using high-speed default developer billing keys.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gemini Card
                  _buildKeyCard(
                    title: 'Gemini AI API Key',
                    subtitle: 'Used for primary resume generation & summary analysis',
                    controller: _geminiKeyController,
                    obscure: _obscureGemini,
                    onToggleObscure: () => setState(() => _obscureGemini = !_obscureGemini),
                    hint: 'AIzaSy...',
                  ),
                  const SizedBox(height: 20),

                  // OpenRouter Card
                  _buildKeyCard(
                    title: 'OpenRouter API Key',
                    subtitle: 'Used as an automatic secondary failover/fallback provider',
                    controller: _openRouterKeyController,
                    obscure: _obscureOpenRouter,
                    onToggleObscure: () => setState(() => _obscureOpenRouter = !_obscureOpenRouter),
                    hint: 'sk-or-v1-...',
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearKeys,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset Defaults'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveKeys,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Keys'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD26EAB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKeyCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD26EAB), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}
