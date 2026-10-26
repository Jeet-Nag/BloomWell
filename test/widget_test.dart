import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloomwell/main.dart';
import 'package:bloomwell/presentation/screens/move_screen.dart';
import 'package:bloomwell/presentation/screens/home_dashboard_screen.dart';
import 'package:bloomwell/presentation/screens/water_screen.dart';
import 'package:bloomwell/presentation/screens/onboarding_screen.dart';
import 'package:bloomwell/presentation/controllers/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('BloomWell app boots up without crashing smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BloomWellApp());
    expect(find.byType(BloomWellApp), findsOneWidget);
  });

  testWidgets('Guided Session 2-Step Flow: Exercise -> Rest -> Skip Rest -> Yoga -> Completed -> Replay', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveScreen(controller: controller),
        ),
      ),
    );

    // Initial state: Tab 1 Daily Activity is visible
    expect(find.text('Daily Activity'), findsOneWidget);
    expect(find.text('Exercise Library'), findsOneWidget);

    // Switch to Tab 2: Exercise Library
    await tester.tap(find.text('Exercise Library'));
    await tester.pumpAndSettle();

    // Verify "Today's Session" heading and Step 1 Exercise card
    expect(find.text("Today's Session"), findsOneWidget);
    expect(find.text('Daily Low-Impact Exercise'), findsOneWidget);
    expect(find.text('Play Exercise'), findsOneWidget);

    // Step 2 Yoga card is initially locked
    expect(find.text('Unlocks after Exercise and 5-min rest'), findsOneWidget);

    // Step 1: Tap "Play Exercise"
    await tester.tap(find.text('Play Exercise'));
    await tester.pumpAndSettle();

    // Active player is now showing with "Mark Exercise Finished ✓"
    final markExerciseBtn = find.text('Mark Exercise Finished ✓');
    expect(markExerciseBtn, findsOneWidget);
    await tester.ensureVisible(markExerciseBtn);
    await tester.pumpAndSettle();

    // Trigger Exercise completion via "Mark Exercise Finished ✓"
    await tester.tap(markExerciseBtn);
    await tester.pumpAndSettle();

    // Verify Step 1 is marked completed and 5-Minute Rest card is shown
    expect(find.text('Exercise completed! Great effort.'), findsOneWidget);
    expect(find.text('5-Minute Rest'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);

    final skipRestBtn = find.text('Skip Rest');
    expect(skipRestBtn, findsOneWidget);
    await tester.ensureVisible(skipRestBtn);
    await tester.pumpAndSettle();

    // Step 2: Tap "Skip Rest"
    await tester.tap(skipRestBtn);
    await tester.pumpAndSettle();

    // Rest card is gone
    expect(find.text('5-Minute Rest'), findsNothing);

    // Yoga card is now active with "Mark Yoga Finished ✓"
    final markYogaBtn = find.text('Mark Yoga Finished ✓');
    expect(markYogaBtn, findsOneWidget);
    await tester.ensureVisible(markYogaBtn);
    await tester.pumpAndSettle();

    // Trigger Yoga completion via "Mark Yoga Finished ✓"
    await tester.tap(markYogaBtn);
    await tester.pumpAndSettle();

    // Session Completed card is shown
    expect(find.text('Today’s Session Completed! 🎉'), findsOneWidget);
    final replayBtn = find.text('Replay Session');
    expect(replayBtn, findsOneWidget);
    await tester.ensureVisible(replayBtn);
    await tester.pumpAndSettle();

    // Tap "Replay Session"
    await tester.tap(replayBtn);
    await tester.pumpAndSettle();

    // Resets back to initial state
    expect(find.text('Play Exercise'), findsOneWidget);
    expect(find.text('Unlocks after Exercise and 5-min rest'), findsOneWidget);
  });

  testWidgets('HomeDashboardScreen does not render Today Meals or Today Movement cards', (WidgetTester tester) async {
    final controller = AppController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDashboardScreen(
            controller: controller,
            onNavigateToTab: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify removed cards are NOT found on Home screen
    expect(find.text("Today's Meals"), findsNothing);
    expect(find.text("Today's Planned Nourishment"), findsNothing);
    expect(find.text("Gentle Movement & Walk"), findsNothing);
    expect(find.text("Today's Movement"), findsNothing);

    // Verify retained cards are present
    expect(find.text("Water Today"), findsOneWidget);
    expect(find.text("15-Day Weight Check"), findsOneWidget);
    expect(find.text("Sleep & Wake-Up Schedule"), findsOneWidget);
  });

  testWidgets('WaterScreen has removed 10-minute snooze button completely', (WidgetTester tester) async {
    final controller = AppController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaterScreen(controller: controller),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 10-minute snooze button is NOT present
    expect(find.text('Snooze (10 min)'), findsNothing);
    expect(find.text('Snooze 10m'), findsNothing);

    // Verify skip session and take bottle photo buttons are present
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Take Bottle Photo'), findsOneWidget);
  });

  testWidgets('OnboardingScreen initial step renders preferred name input and 6-step progress', (WidgetTester tester) async {
    final controller = AppController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingScreen(
            controller: controller,
            onCompleted: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify progress indicator is 1/6
    expect(find.text('1/6'), findsOneWidget);

    // Verify Welcome and Name step components
    expect(find.text('Welcome to BloomWell'), findsOneWidget);
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
