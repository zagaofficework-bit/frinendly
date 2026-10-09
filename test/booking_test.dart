import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/booking.dart';
import 'package:friendify/providers/booking_provider.dart';
import 'package:friendify/repositories/repositories.dart';
import 'package:friendify/screens/account_screen.dart';

void main() {
  group('Sprint 3: Booking Engine & Mock Escrow Tests', () {
    late MockBookingRepository repo;

    setUp(() {
      MockBookingRepository.reset();
      repo = MockBookingRepository();
    });

    test('Pricing model accurately calculates 15% platform fee and total', () {
      const rate = 20.0;
      const hours = 2;
      const subtotal = rate * hours; // 40.0
      final fee = Pricing.fee(subtotal); // 6.0
      final total = Pricing.total(rate, hours); // 46.0

      expect(subtotal, 40.0);
      expect(fee, 6.0);
      expect(total, 46.0);
    });

    test('Booking status lifecycle transitions correctly', () async {
      final initial = await repo.fetchUserBookings();
      expect(initial.isNotEmpty, true);

      final firstBooking = initial.first;
      expect(firstBooking.status, BookingStatus.confirmed);

      // Cancel booking
      final canceled = await repo.updateStatus(firstBooking.id, BookingStatus.canceled);
      expect(canceled, true);

      final updated = await repo.fetchUserBookings();
      final updatedFirst = updated.firstWhere((b) => b.id == firstBooking.id);
      expect(updatedFirst.status, BookingStatus.canceled);
    });

    test('WalletNotifier credits companion escrow payout', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wallet = container.read(walletProvider.notifier);
      final initialBalance = container.read(walletProvider);

      // Credit payout from $100 subtotal (85% payout = $85)
      wallet.credit(85.0);
      expect(container.read(walletProvider), initialBalance + 85.0);

      // Withdraw balance
      wallet.withdraw();
      expect(container.read(walletProvider), 0.0);
    });

    testWidgets('AccountScreen displays Booking tabs and seeded bookings', (WidgetTester tester) async {
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

      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Canceled'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsWidgets);
    });
  });
}
