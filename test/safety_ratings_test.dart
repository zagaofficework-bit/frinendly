import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/companion.dart';
import 'package:friendify/models/review.dart';
import 'package:friendify/repositories/repositories.dart';
import 'package:friendify/screens/account_screen.dart';

void main() {
  group('Sprint 5: Trust, Safety Hardening & Ratings System Tests', () {
    late MockCompanionRepository companionRepo;

    setUp(() {
      MockBookingRepository.reset();
      companionRepo = MockCompanionRepository();
    });


    test('Companion copyWith creates accurate clones with updated metrics', () {
      const initial = Companion(
        id: 'c_test',
        name: 'Test Companion',
        age: 25,
        city: 'Mumbai',
        bio: 'Bio text',
        avatarUrl: 'https://example.com/avatar.jpg',
        hourlyRate: 30.0,
        rating: 4.5,
        reviewCount: 10,
        distanceKm: 2.0,
      );

      final updated = initial.copyWith(
        rating: 4.8,
        reviewCount: 11,
        verified: true,
      );

      expect(updated.id, 'c_test');
      expect(updated.rating, 4.8);
      expect(updated.reviewCount, 11);
      expect(updated.verified, true);
      expect(updated.city, 'Mumbai');
    });

    test('addReview recalculates companion average rating and increments review count', () async {
      final initialCompanion = await companionRepo.byId('c0');
      expect(initialCompanion, isNotNull);
      final initialCount = initialCompanion!.reviewCount;
      final initialRating = initialCompanion.rating;

      final newReview = Review(
        author: 'Priya Sharma',
        text: 'Absolute delight! Super punctual and polite conversation.',
        rating: 5.0,
        date: DateTime.now(),
      );

      final ok = await companionRepo.addReview('c0', newReview);
      expect(ok, true);

      final updatedCompanion = await companionRepo.byId('c0');
      expect(updatedCompanion, isNotNull);
      expect(updatedCompanion!.reviewCount, initialCount + 1);

      final expectedRating = double.parse(
        (((initialRating * initialCount) + 5.0) / (initialCount + 1)).toStringAsFixed(1),
      );
      expect(updatedCompanion.rating, expectedRating);
    });

    testWidgets('AccountScreen displays Trust & Safety Center with policies and SOS testing', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Trust & Safety Center header and badge
      expect(find.text('Trust & Safety Center'), findsOneWidget);
      expect(find.text('100% Platonic Verified'), findsOneWidget);

      // Tap Code of Conduct chip
      expect(find.text('Code of Conduct'), findsOneWidget);
      await tester.tap(find.text('Code of Conduct'));
      await tester.pumpAndSettle();

      expect(find.text('Platonic Code of Conduct'), findsOneWidget);
      expect(find.textContaining('Purely Platonic: Friendify is strictly for non-romantic friendship'), findsOneWidget);
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      // Tap Escrow Guarantee chip
      expect(find.text('Escrow Guarantee'), findsOneWidget);
      await tester.tap(find.text('Escrow Guarantee'));
      await tester.pumpAndSettle();

      expect(find.text('Escrow Protection Policy'), findsOneWidget);
      expect(find.textContaining('Funds Authorized On Booking'), findsOneWidget);
      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();

      // Tap Test SOS Trigger
      expect(find.text('Test SOS Trigger'), findsOneWidget);
      await tester.tap(find.text('Test SOS Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Safety SOS'), findsOneWidget);
      expect(find.text('Share live GPS with emergency contacts'), findsOneWidget);
      await tester.tap(find.text('Share live GPS with emergency contacts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('🚨 Live GPS'), findsOneWidget);
    });

    testWidgets('AccountScreen past bookings allow post-meetup rating and feedback submission', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to "Past" bookings tab
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();


      // Rate & Review button should be visible for completed booking b_sample_2
      expect(find.byKey(const Key('rate_review_b_sample_2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rate_review_b_sample_2')));
      await tester.pumpAndSettle();

      // Modal review dialog is displayed
      expect(find.textContaining('Review Liam'), findsOneWidget);
      expect(find.text('5 / 5 Stars'), findsOneWidget);
      expect(find.byKey(const Key('meetup_review_text_field')), findsOneWidget);

      // Enter review feedback
      await tester.enterText(
        find.byKey(const Key('meetup_review_text_field')),
        'Fantastic meetup! Liam was very polite and great gym buddy.',
      );

      // Select tip
      await tester.tap(find.text('\$10'));
      await tester.pumpAndSettle();

      // Submit review
      await tester.tap(find.byKey(const Key('submit_meetup_review_button')));
      await tester.pumpAndSettle();

      // Verify success snackbar with rating and tip confirmation
      expect(find.textContaining('Thank you! Your 5-star review for Liam was published. \$10 tip added!'), findsOneWidget);
    });
  });
}
