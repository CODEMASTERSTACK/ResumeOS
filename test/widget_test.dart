import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:ai_career_os/main.dart';
import 'package:ai_career_os/features/profile/presentation/screens/points_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AiCareerOsApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  testWidgets('PointsScreen renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PointsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PointsScreen), findsOneWidget);
  });
}
