import 'package:flutter/foundation.dart';
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
  double build() {
    _loadFromProfile();
    return 248.50;
  }

  void _loadFromProfile() {
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      client.from('profiles').select('wallet_balance').eq('id', userId).maybeSingle().then((res) {
        if (res != null && res['wallet_balance'] != null) {
          state = (res['wallet_balance'] as num).toDouble();
        }
      }).catchError((e) {
        debugPrint('⚠️ Error loading wallet balance: $e');
      });
    }
  }

  Future<void> credit(double amount) async {
    state = state + amount;
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        await client.from('profiles').update({'wallet_balance': state}).eq('id', userId);
      } catch (e) {
        debugPrint('⚠️ Error updating wallet balance: $e');
      }
    }
  }

  Future<void> withdraw() async {
    state = 0;
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        await client.from('profiles').update({'wallet_balance': 0.0}).eq('id', userId);
      } catch (e) {
        debugPrint('⚠️ Error resetting wallet balance: $e');
      }
    }
  }
}
final walletProvider = NotifierProvider<WalletNotifier, double>(WalletNotifier.new);

class ContactsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromDb();
    return ['Mom  •  +91 90000 00001'];
  }

  Future<void> _loadFromDb() async {
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final res = await client
            .from('emergency_contacts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: true);
        final list = (res as List).map((row) => '${row['name']}  •  ${row['phone']}').toList();
        if (list.isNotEmpty) {
          state = list;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading emergency contacts: $e');
      }
    }
  }

  Future<void> add(String c) async {
    state = [...state, c];
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final parts = c.split('•').map((s) => s.trim()).toList();
        final name = parts.first;
        final phone = parts.length > 1 ? parts.last : '';
        await client.from('emergency_contacts').insert({
          'user_id': userId,
          'name': name,
          'phone': phone,
        });
      } catch (e) {
        debugPrint('⚠️ Error saving emergency contact: $e');
      }
    }
  }

  Future<void> remove(String c) async {
    state = state.where((e) => e != c).toList();
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final parts = c.split('•').map((s) => s.trim()).toList();
        final name = parts.first;
        await client.from('emergency_contacts').delete().eq('user_id', userId).eq('name', name);
      } catch (e) {
        debugPrint('⚠️ Error removing emergency contact: $e');
      }
    }
  }
}
final contactsProvider = NotifierProvider<ContactsNotifier, List<String>>(ContactsNotifier.new);
