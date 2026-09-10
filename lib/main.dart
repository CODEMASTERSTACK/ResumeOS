import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'services/notifications/notification_service.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set background messaging handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Notification Service (Requests permissions, subscribes to topic 'all_users')
  NotificationService.instance.initialize();

  // ── Firestore offline persistence ─────────────────────────
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── System UI ─────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C0B10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: AiCareerOsApp()));
}

class AiCareerOsApp extends ConsumerStatefulWidget {
  const AiCareerOsApp({super.key});

  @override
  ConsumerState<AiCareerOsApp> createState() => _AiCareerOsAppState();
}

class _AiCareerOsAppState extends ConsumerState<AiCareerOsApp> {
  @override
  void initState() {
    super.initState();
    // Listen for foreground notifications and display a banner
    NotificationService.instance.onForegroundMessage.listen((message) {
      final notif = message.notification;
      if (notif != null) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E2E),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFCBE349), width: 1.2),
            ),
            content: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFFCBE349), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title ?? 'Notification',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (notif.body != null)
                        Text(
                          notif.body!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ResumeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
