import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/error_sanitizer.dart';

enum ToastType { success, error, info }

class ToastEvent {
  final String message;
  final ToastType type;
  final String? title;
  final Duration duration;
  final DateTime timestamp;

  ToastEvent({
    required this.message,
    required this.type,
    this.title,
    required this.duration,
    required this.timestamp,
  });
}

final toastEventProvider = StateProvider<ToastEvent?>((ref) => null);

class CustomToast {
  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final sanitizedMessage = type == ToastType.error ? ErrorSanitizer.sanitize(message) : message;

    try {
      final container = ProviderScope.containerOf(context);
      container.read(toastEventProvider.notifier).state = ToastEvent(
        message: sanitizedMessage,
        type: type,
        title: title,
        duration: duration,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      _showFallbackSnackBar(context, sanitizedMessage, type, title, duration);
    }
  }

  static void _showFallbackSnackBar(
    BuildContext context,
    String message,
    ToastType type,
    String? title,
    Duration duration,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    Color primaryColor;
    IconData icon;
    String defaultTitle;

    switch (type) {
      case ToastType.success:
        primaryColor = const Color(0xFF10B981); // Premium emerald green
        icon = Icons.check_circle_outline_rounded;
        defaultTitle = 'Success';
        break;
      case ToastType.error:
        primaryColor = const Color(0xFFEF4444); // Premium red/rose
        icon = Icons.error_outline_rounded;
        defaultTitle = 'Error';
        break;
      case ToastType.info:
        primaryColor = const Color(0xFF1E5FF5); // Premium blue
        icon = Icons.info_outline_rounded;
        defaultTitle = 'Information';
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF13111C).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Type Icon Indicator
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
                  // Text Content
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? defaultTitle,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close Icon Button
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                    onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
