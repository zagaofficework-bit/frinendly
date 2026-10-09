import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking.dart';
import '../core/supabase_config.dart';
import '../repositories/repositories.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((_) {
  final client = SupabaseConfig.client;
  if (SupabaseConfig.isConfigured && client != null) {
    return SupabaseBookingRepository(client);
  }
  return MockBookingRepository();
});
final paymentServiceProvider = Provider<PaymentService>((_) => MockPaymentService());

class BookingsNotifier extends Notifier<List<Booking>> {
  @override
  List<Booking> build() => [];
  Future<void> add(Booking b) async {
    final saved = await ref.read(bookingRepositoryProvider).create(b);
    state = [saved, ...state];
  }
  void cancel(String id) => state = [for (final b in state) b.id == id ? b.copyWith(status: BookingStatus.canceled) : b];
}
final bookingsProvider = NotifierProvider<BookingsNotifier, List<Booking>>(BookingsNotifier.new);

class WalletNotifier extends Notifier<double> {
  @override
  double build() => 248.50;
  void withdraw() => state = 0;
}
final walletProvider = NotifierProvider<WalletNotifier, double>(WalletNotifier.new);

class ContactsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['Mom  •  +91 90000 00001'];
  void add(String c) => state = [...state, c];
  void remove(String c) => state = state.where((e) => e != c).toList();
}
final contactsProvider = NotifierProvider<ContactsNotifier, List<String>>(ContactsNotifier.new);
