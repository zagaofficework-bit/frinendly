import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking.dart';
import '../core/supabase_config.dart';
import 'companion_provider.dart';
import '../repositories/repositories.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = SupabaseConfig.client;
  final companionRepo = ref.watch(companionRepositoryProvider);
  if (SupabaseConfig.isConfigured && client != null) {
    return SupabaseBookingRepository(client, companionRepo);
  }
  return MockBookingRepository();
});
final paymentServiceProvider = Provider<PaymentService>((_) => MockPaymentService());

class BookingsNotifier extends Notifier<List<Booking>> {
  @override
  List<Booking> build() {
    final repo = ref.watch(bookingRepositoryProvider);
    if (repo is MockBookingRepository) {
      return List.from(MockBookingRepository.initialBookings);
    }
    _loadInitial();
    return [];
  }

  Future<void> _loadInitial() async {
    final list = await ref.read(bookingRepositoryProvider).fetchUserBookings();
    state = list;
  }

  Future<void> refresh() async {
    final list = await ref.read(bookingRepositoryProvider).fetchUserBookings();
    state = list;
  }

  Future<Booking> add(Booking b, {String? clientId}) async {
    final saved = await ref.read(bookingRepositoryProvider).create(b, clientId: clientId);
    state = [saved, ...state];
    return saved;
  }

  Future<void> cancel(String id) async {
    await ref.read(bookingRepositoryProvider).updateStatus(id, BookingStatus.canceled);
    state = [for (final b in state) b.id == id ? b.copyWith(status: BookingStatus.canceled) : b];
  }

  Future<void> complete(String id) async {
    await ref.read(bookingRepositoryProvider).updateStatus(id, BookingStatus.completed);
    final booking = state.where((b) => b.id == id).firstOrNull;
    if (booking != null) {
      ref.read(walletProvider.notifier).credit(booking.subtotal * 0.85);
    }
    state = [for (final b in state) b.id == id ? b.copyWith(status: BookingStatus.completed) : b];
  }
}
final bookingsProvider = NotifierProvider<BookingsNotifier, List<Booking>>(BookingsNotifier.new);

class WalletNotifier extends Notifier<double> {
  @override
  double build() => 248.50;
  void credit(double amount) => state = state + amount;
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
