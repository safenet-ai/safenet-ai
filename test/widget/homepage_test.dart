import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safenetai/home.dart';

/// Module 7: UI Widget Tests — Black-Box
///
/// Tests the user-visible behavior of key screens without knowledge
/// of internal implementation.
void main() {
  group('Homepage — Role Selection Screen', () {
    testWidgets('should display SafeNet AI title', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      expect(find.text('SafeNet AI'), findsOneWidget);
    });

    testWidgets('should display "Select Your Role" heading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      expect(find.text('Select Your Role'), findsOneWidget);
    });

    testWidgets('should display all 4 role options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      expect(find.text('Authority'), findsOneWidget);
      expect(find.text('Resident'), findsOneWidget);
      expect(find.text('Worker'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('should display role icons', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.handyman_outlined), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    });

    testWidgets('should display subtitle text', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      expect(find.text('Choose your profile to continue'), findsOneWidget);
    });

    testWidgets('tapping Authority should navigate', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      await tester.tap(find.text('Authority'));
      await tester.pumpAndSettle();

      // After navigation, Homepage should no longer be visible
      // (the login page takes over the entire screen)
      expect(find.text('Select Your Role'), findsNothing);
    });

    testWidgets('tapping Resident should navigate', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      await tester.tap(find.text('Resident'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Role'), findsNothing);
    });

    testWidgets('tapping Worker should navigate', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Role'), findsNothing);
    });

    testWidgets('tapping Security should navigate', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Homepage()));

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Role'), findsNothing);
    });
  });
}
