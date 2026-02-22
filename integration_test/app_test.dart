import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safenetai/main.dart' as app;

/// Module 8: End-to-End Integration Tests
///
/// This script tests the full flow of the app running on a real device/emulator.
/// It verifies that all components (UI, Navigation, backend connections)
/// work together seamlessly.
///
/// To run:
/// flutter test integration_test/app_test.dart
void main() {
  // Initialize the Integration Test framework
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SafeNet AI Core E2E Journeys', () {
    testWidgets('App Start -> Role Selection Navigation', (
      WidgetTester tester,
    ) async {
      // 1. Start the full application
      app.main();

      // 2. Wait for the app to initialize (splash screen, Firebase init)
      // Pump frames until the UI is completely stable
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 3. Verify we are on the Homepage / Welcome Screen
      expect(find.text('SafeNet AI'), findsOneWidget);
      expect(find.text('Select Your Role'), findsOneWidget);

      // 4. Tap the 'Resident' role button
      final residentCard = find.text('Resident');
      expect(residentCard, findsOneWidget);
      await tester.tap(residentCard);

      // 5. Wait for the navigation transition to complete
      await tester.pumpAndSettle();

      // 6. Verify we have reached the Resident Login Page
      // The login page usually asks for Email/Password or shows "Resident Login"
      expect(
        find.byType(TextFormField),
        findsWidgets,
      ); // Should have email/password fields
      expect(find.text('Login'), findsOneWidget); // Should have a login button

      // 7. Verify we can navigate back to the role selection
      // Tap the back button in the AppBar
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Should be back on the Homepage
        expect(find.text('Select Your Role'), findsOneWidget);
      }
    });

    testWidgets('App Start -> Security Navigation flow', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap Security Profile
      final securityCard = find.text('Security');
      expect(securityCard, findsOneWidget);
      await tester.tap(securityCard);
      await tester.pumpAndSettle();

      // Verify Login UI
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Login'), findsOneWidget);
    });
  });
}
