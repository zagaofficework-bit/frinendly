import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/companion.dart';
import 'package:friendify/providers/companion_provider.dart';
import 'package:friendify/providers/booking_provider.dart';
import 'package:friendify/screens/explore_screen.dart';
import 'package:friendify/screens/booking_modal.dart';

void main() {
  group('Tab 1: Explore & Booking Engine Tests', () {
    const testCompanion = Companion(
      id: 'c0',
      name: 'Maya',
      age: 22,
      city: 'Mumbai',
      bio: 'Friendly and curious.',
      avatarUrl: 'https://i.pravatar.cc/600?img=10',
      hourlyRate: 15.0,
      rating: 4.8,
      reviewCount: 12,
      distanceKm: 0.8,
      activities: ['Coffee', 'Sightseeing'],
      tags: ['Coffee', 'Foodie'],
    );

    testWidgets('ExploreScreen renders SearchBar, Activity Chips and ViewMode switcher', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search bar and filter icons
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // View mode segmented button
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.view_list), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);

      // Activity chips
      expect(find.text('Coffee'), findsWidgets);
      expect(find.text('Gym Buddy'), findsWidgets);
    });

    testWidgets('ExploreScreen view mode switches to List and Stack mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap List view button
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(container.read(viewModeProvider), ViewModeType.list);

      // Tap Stack view button
      await tester.tap(find.byIcon(Icons.style));
      await tester.pumpAndSettle();
      expect(container.read(viewModeProvider), ViewModeType.stack);
      expect(find.byType(SwipeStack), findsOneWidget);
    });

    testWidgets('BookingModal navigates all 4 steps and confirms escrow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: BookingModal(companion: testCompanion),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Date & Time
      expect(find.text('Step 1/4 · Date & time'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Duration & Activity
      expect(find.text('Step 2/4 · Duration & activity'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Meeting Location
      expect(find.text('Step 3/4 · Meeting location'), findsOneWidget);
      // Select preset chip
      await tester.tap(find.text('Blue Tokai Cafe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Payment Summary & Escrow
      expect(find.text('Step 4/4 · Payment summary'), findsOneWidget);
      expect(find.textContaining('Secure Escrow'), findsOneWidget);

      // Secure Escrow tap
      await tester.tap(find.textContaining('Secure Escrow'));
      await tester.pumpAndSettle();

      // Verify booking added to provider state
      final bookings = container.read(bookingsProvider);
      expect(bookings.any((b) => b.companion.id == 'c0'), true);
    });
  });
}
