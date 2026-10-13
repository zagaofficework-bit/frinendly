import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/companion.dart';
import 'package:friendify/providers/companion_provider.dart';
import 'package:friendify/providers/booking_provider.dart';
import 'package:friendify/providers/theme_provider.dart';
import 'package:friendify/screens/onboarding_screen.dart';

class _TestWalletNotifier extends WalletNotifier {
  @override
  double build() => 120.0;
}

class _TestHostModeNotifier extends BoolNotifier {
  @override
  bool build() => true;
}

void main() {
  group('Tab 3: Host Mode & Management Dashboard Tests', () {
    const sampleCompanion = Companion(
      id: 'c_host_test',
      name: 'Rohan Host',
      age: 26,
      city: 'Mumbai',
      bio: 'Experienced city guide and badminton player.',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
      hourlyRate: 35.0,
      rating: 4.9,
      reviewCount: 8,
      distanceKm: 1.2,
      verified: true,
      backgroundChecked: true,
      isActive: true,
      activities: ['Coffee', 'Sightseeing'],
      tags: ['Coffee', 'Guide'],
    );

    testWidgets('Non-host user sees Find a Friend / Become a Host segmented button and onboarding flow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myCompanionProfileProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Host Mode'), findsOneWidget);
      expect(find.text('Find a Friend'), findsOneWidget);
      expect(find.text('Become a Host'), findsOneWidget);

      // Tap Become a Host segment
      await tester.tap(find.text('Become a Host'));
      await tester.pumpAndSettle();

      // Verify Stepper appears with Step 0
      expect(find.byType(Stepper), findsOneWidget);
      expect(find.text('Listing Details'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Continue'), findsWidgets);
    });

    testWidgets('Onboarding stepper steps through details, activities, and checks guest auth guard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myCompanionProfileProvider.overrideWith((ref) => Future.value(null)),
            hostModeProvider.overrideWith(_TestHostModeNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnboardingScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 0 -> Step 1
      await tester.tap(find.text('Continue').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Identity & Safety Check'), findsOneWidget);

      // Step 1 -> Step 2
      await tester.tap(find.text('Continue').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Escrow Payout Setup'), findsOneWidget);

      // Step 2 -> Step 3
      await tester.tap(find.text('Continue').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Availability & Hours'), findsOneWidget);

      // Step 3 submission by unauthenticated guest shows guard SnackBar
      await tester.tap(find.text('Continue').hitTestable());
      await tester.pumpAndSettle();

      expect(find.textContaining('Please sign in or create an account'), findsOneWidget);
    });

    testWidgets('Registered companion user sees live Host Dashboard with metrics and availability switch', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myCompanionProfileProvider.overrideWith((ref) => Future.value(sampleCompanion)),
            walletProvider.overrideWith(_TestWalletNotifier.new),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Host Dashboard renders profile details
      expect(find.text('Rohan Host'), findsOneWidget);
      expect(find.textContaining('Mumbai'), findsOneWidget);
      expect(find.textContaining('Accepting Bookings'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Wallet card with escrow metrics
      expect(find.text('Host Wallet'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('Verified Host'), findsOneWidget);

      // Quick action tiles
      expect(find.text('View Public Profile'), findsOneWidget);
      expect(find.text('Edit Hourly Rate'), findsOneWidget);
      expect(find.text('Offered Activities'), findsOneWidget);

      // Open Edit Hourly Rate dialog
      await tester.tap(find.text('Edit Hourly Rate'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Hourly Rate'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);

      // Verify Profile Completeness card
      expect(find.textContaining('Profile Completeness'), findsOneWidget);

      // Verify all detail editor quick action tiles exist
      expect(find.text('Edit Bio & Location'), findsOneWidget);
      expect(find.text('Languages Spoken'), findsOneWidget);
      expect(find.text('Manage Gallery Photos'), findsOneWidget);

      // Test Edit Bio & Location dialog
      await tester.tap(find.text('Edit Bio & Location'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Bio & Details'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mumbai'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Offered Activities dialog
      await tester.tap(find.text('Offered Activities'));
      await tester.pumpAndSettle();
      expect(find.text('Select the platonic activities you are happy to accompany guests to:'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Languages Spoken dialog
      await tester.tap(find.text('Languages Spoken'));
      await tester.pumpAndSettle();
      expect(find.text('Select the languages you can comfortably converse in:'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Manage Gallery Photos dialog
      await tester.tap(find.text('Manage Gallery Photos'));
      await tester.pumpAndSettle();
      expect(find.text('Manage Photo Gallery'), findsOneWidget);
      expect(find.text('Add Photo by URL:'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Incoming Client Bookings card presence
      expect(find.text('Incoming Client Bookings'), findsOneWidget);

      // Test Operating Hours & Days tile and dialog
      expect(find.text('Operating Hours & Days'), findsOneWidget);
      await tester.tap(find.text('Operating Hours & Days'));
      await tester.pumpAndSettle();
      expect(find.text('Available Days:'), findsOneWidget);
      expect(find.text('Operating Hours Window:'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Test Client Reviews tile and dialog
      expect(find.text('Client Reviews'), findsOneWidget);
      await tester.tap(find.text('Client Reviews'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Client Reviews'), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Test Host Wallet Payout dialog
      expect(find.text('Withdraw →'), findsOneWidget);
      await tester.tap(find.text('Withdraw →'));
      await tester.pumpAndSettle();
      expect(find.text('Host Payout & Withdrawal'), findsOneWidget);
      expect(find.text('UPI ID / Account IBAN'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
