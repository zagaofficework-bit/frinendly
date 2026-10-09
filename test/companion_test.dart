import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/companion.dart';
import 'package:friendify/models/review.dart';
import 'package:friendify/repositories/repositories.dart';
import 'package:friendify/screens/profile_details_screen.dart';

void main() {
  group('Sprint 2: Companion Directory & Geospatial Search Tests', () {
    late MockCompanionRepository repo;

    setUp(() {
      repo = MockCompanionRepository();
    });

    test('searchCompanions filters by city and activity', () async {
      final mumbaiCompanions = await repo.searchCompanions(city: 'Mumbai');
      expect(mumbaiCompanions.every((c) => c.city == 'Mumbai'), true);

      final coffeeCompanions = await repo.searchCompanions(activity: 'Coffee');
      expect(coffeeCompanions.every((c) => c.activities.contains('Coffee')), true);
    });

    test('addReview adds a review to the companion reviews list', () async {
      final initialReviews = await repo.reviews('c0');
      final initialCount = initialReviews.length;

      final newReview = Review(
        author: 'Ravi Test',
        text: 'Super friendly and punctual meetup!',
        rating: 5.0,
        date: DateTime.now(),
      );

      final ok = await repo.addReview('c0', newReview);
      expect(ok, true);

      final updatedReviews = await repo.reviews('c0');
      expect(updatedReviews.length, initialCount + 1);
      expect(updatedReviews.first.author, 'Ravi Test');
    });

    test('createOrUpdateCompanion adds a new companion profile', () async {
      const companion = Companion(
        id: 'c_test_99',
        name: 'Aarav New',
        age: 25,
        city: 'Mumbai',
        bio: 'Tech enthusiast and coffee lover.',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        hourlyRate: 35.0,
        rating: 5.0,
        reviewCount: 0,
        distanceKm: 1.5,
      );

      await repo.createOrUpdateCompanion(companion);
      final found = await repo.byId('c_test_99');
      expect(found, isNotNull);
      expect(found?.name, 'Aarav New');
    });

    testWidgets('ProfileDetailsScreen renders details and Write Review button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileDetailsScreen(id: 'c0'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('Write Review'), findsOneWidget);
      expect(find.text('Book Now'), findsOneWidget);
    });
  });
}
