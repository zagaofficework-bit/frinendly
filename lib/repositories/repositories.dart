import 'dart:async';
import '../models/booking.dart';
import '../models/chat_message.dart';
import '../models/companion.dart';
import '../models/review.dart';

abstract class CompanionRepository {
  Future<List<Companion>> fetchCompanions();
  Future<Companion?> byId(String id);
  Future<List<Review>> reviews(String companionId);
  Future<bool> addReview(String companionId, Review review);
  Future<Companion> createOrUpdateCompanion(Companion companion, {String? userId});
  Future<List<Companion>> searchCompanions({
    String? query,
    String? city,
    String? activity,
    double? minRate,
    double? maxRate,
    double? minRating,
  });
}

abstract class BookingRepository {
  Future<Booking> create(Booking booking, {String? clientId});
  Future<List<Booking>> fetchUserBookings({String? clientId});
  Future<bool> updateStatus(String bookingId, BookingStatus status);
}

abstract class PaymentService {
  Future<bool> checkout(double amount);
}

class MockCompanionRepository implements CompanionRepository {
  static const _names = ['Maya', 'Liam', 'Sofia', 'Noah', 'Aisha', 'Ethan', 'Zara', 'Leo'];
  static const _acts = ['Coffee', 'Gym Buddy', 'Event Plus-One', 'Sightseeing', 'Board Games'];
  static final List<Companion> _data = List.generate(_names.length, (i) => Companion(
        id: 'c$i', name: _names[i], age: 22 + i, city: i.isEven ? 'Mumbai' : 'Pune',
        bio: 'Friendly, curious and a great listener. I love exploring new places, '
            'trying local food and meeting new people. Strictly platonic, always fun!',
        avatarUrl: 'https://i.pravatar.cc/600?img=${i + 10}',
        gallery: List.generate(3, (g) => 'https://i.pravatar.cc/800?img=${i * 3 + g + 10}'),
        hourlyRate: 15.0 + i * 5, rating: 4.2 + (i % 5) * 0.15, reviewCount: 12 + i * 7,
        distanceKm: 0.8 + i * 1.3, verified: i != 3, backgroundChecked: i % 3 != 2,
        languages: const ['English', 'Hindi', 'Marathi'].take(1 + i % 3).toList(),
        tags: [_acts[i % 5], _acts[(i + 2) % 5], 'Foodie'],
        activities: [_acts[i % 5], _acts[(i + 2) % 5]],
        badges: const ['Top Rated', 'Great Listener', 'Punctual'].take(1 + i % 3).toList(),
      ));

  static final Map<String, List<Review>> _reviewsMap = {};

  @override
  Future<List<Companion>> fetchCompanions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_data);
  }

  @override
  Future<Companion?> byId(String id) async => _data.where((c) => c.id == id).firstOrNull;

  @override
  Future<List<Review>> reviews(String companionId) async {
    if (!_reviewsMap.containsKey(companionId)) {
      _reviewsMap[companionId] = List.generate(
        4,
        (i) => Review(
          author: ['Rohan', 'Priya', 'Sam', 'Anya'][i],
          rating: 5.0 - (i % 3) * 0.5,
          text: 'Wonderful company, very respectful and on time. Would book again!',
          date: DateTime.now().subtract(Duration(days: 6 + i * 9)),
        ),
      );
    }
    return _reviewsMap[companionId]!;
  }

  @override
  Future<bool> addReview(String companionId, Review review) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final list = _reviewsMap.putIfAbsent(companionId, () => []);
    list.insert(0, review);

    final index = _data.indexWhere((c) => c.id == companionId);
    if (index != -1) {
      final old = _data[index];
      final newCount = old.reviewCount + 1;
      final newRating = double.parse(
        (((old.rating * old.reviewCount) + review.rating) / newCount).toStringAsFixed(1),
      );
      _data[index] = old.copyWith(
        rating: newRating,
        reviewCount: newCount,
      );
    }
    return true;
  }


  @override
  Future<Companion> createOrUpdateCompanion(Companion companion, {String? userId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _data.removeWhere((c) => c.id == companion.id);
    _data.insert(0, companion);
    return companion;
  }

  @override
  Future<List<Companion>> searchCompanions({
    String? query,
    String? city,
    String? activity,
    double? minRate,
    double? maxRate,
    double? minRating,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _data.where((c) {
      final q = (query ?? '').toLowerCase();
      final loc = (city ?? '').toLowerCase();
      return (q.isEmpty || c.name.toLowerCase().contains(q) || c.tags.any((t) => t.toLowerCase().contains(q))) &&
          (loc.isEmpty || c.city.toLowerCase().contains(loc)) &&
          (activity == null || c.activities.contains(activity)) &&
          (minRate == null || c.hourlyRate >= minRate) &&
          (maxRate == null || c.hourlyRate <= maxRate) &&
          (minRating == null || c.rating >= minRating);
    }).toList();
  }
}

class MockPaymentService implements PaymentService {
  @override
  Future<bool> checkout(double amount) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

class SupabaseCompanionRepository implements CompanionRepository {
  final dynamic client; // SupabaseClient
  final CompanionRepository _fallback = MockCompanionRepository();
  SupabaseCompanionRepository(this.client);

  @override
  Future<List<Companion>> fetchCompanions() async {
    try {
      final response = await client.from('companions').select().eq('is_active', true);
      final list = (response as List).map((row) => Companion.fromMap(row as Map<String, dynamic>)).toList();
      if (list.isEmpty) return _fallback.fetchCompanions();
      return list;
    } catch (_) {
      return _fallback.fetchCompanions();
    }
  }

  @override
  Future<Companion?> byId(String id) async {
    try {
      final response = await client.from('companions').select().eq('id', id).maybeSingle();
      if (response == null) return _fallback.byId(id);
      return Companion.fromMap(response as Map<String, dynamic>);
    } catch (_) {
      return _fallback.byId(id);
    }
  }

  @override
  Future<List<Review>> reviews(String companionId) async {
    try {
      final response = await client.from('reviews').select().eq('companion_id', companionId).order('created_at', ascending: false);
      final list = (response as List).map((row) => Review.fromMap(row as Map<String, dynamic>)).toList();
      if (list.isEmpty) return _fallback.reviews(companionId);
      return list;
    } catch (_) {
      return _fallback.reviews(companionId);
    }
  }

  @override
  Future<bool> addReview(String companionId, Review review) async {
    try {
      final userId = client.auth.currentUser?.id;
      final data = review.toMap(companionId, authorId: userId?.toString());
      await client.from('reviews').insert(data);
      return true;
    } catch (_) {
      return _fallback.addReview(companionId, review);
    }
  }

  @override
  Future<Companion> createOrUpdateCompanion(Companion companion, {String? userId}) async {
    try {
      final data = companion.toMap();
      if (userId != null) data['user_id'] = userId;
      final res = await client.from('companions').upsert(data).select().single();
      return Companion.fromMap(res as Map<String, dynamic>);
    } catch (_) {
      return _fallback.createOrUpdateCompanion(companion, userId: userId);
    }
  }

  @override
  Future<List<Companion>> searchCompanions({
    String? query,
    String? city,
    String? activity,
    double? minRate,
    double? maxRate,
    double? minRating,
  }) async {
    try {
      dynamic builder = client.from('companions').select().eq('is_active', true);
      if (city != null && city.isNotEmpty) {
        builder = builder.ilike('city', '%$city%');
      }
      if (minRate != null && minRate > 0) {
        builder = builder.gte('hourly_rate', minRate);
      }
      if (maxRate != null && maxRate < 200) {
        builder = builder.lte('hourly_rate', maxRate);
      }
      if (minRating != null && minRating > 0) {
        builder = builder.gte('rating', minRating);
      }
      if (activity != null && activity.isNotEmpty) {
        builder = builder.contains('activities', [activity]);
      }
      if (query != null && query.isNotEmpty) {
        builder = builder.or('name.ilike.%$query%,bio.ilike.%$query%');
      }
      final response = await builder;
      final list = (response as List).map((row) => Companion.fromMap(row as Map<String, dynamic>)).toList();
      if (list.isEmpty && (query == null || query.isEmpty)) return _fallback.fetchCompanions();
      return list;
    } catch (_) {
      return _fallback.searchCompanions(
        query: query,
        city: city,
        activity: activity,
        minRate: minRate,
        maxRate: maxRate,
        minRating: minRating,
      );
    }
  }
}

class MockBookingRepository implements BookingRepository {
  static List<Booking> get initialBookings => [
    Booking(
      id: 'b_sample_1',
      companion: MockCompanionRepository._data[0],
      start: DateTime.now().add(const Duration(days: 1, hours: 3)),
      hours: 2,
      activity: 'Coffee',
      location: 'Blue Tokai Cafe, Bandra',
      status: BookingStatus.confirmed,
    ),
    Booking(
      id: 'b_sample_2',
      companion: MockCompanionRepository._data[1],
      start: DateTime.now().subtract(const Duration(days: 3)),
      hours: 1,
      activity: 'Gym Buddy',
      location: 'City Fitness Hub, Pune',
      status: BookingStatus.completed,
    ),
  ];

  static final List<Booking> _bookings = List.from(initialBookings);

  static void reset() {
    _bookings.clear();
    _bookings.addAll(initialBookings);
  }

  @override
  Future<Booking> create(Booking booking, {String? clientId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final confirmed = booking.copyWith(status: BookingStatus.confirmed);
    _bookings.insert(0, confirmed);
    return confirmed;
  }

  @override
  Future<List<Booking>> fetchUserBookings({String? clientId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_bookings);
  }

  @override
  Future<bool> updateStatus(String bookingId, BookingStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: status);
      return true;
    }
    return false;
  }
}

class SupabaseBookingRepository implements BookingRepository {
  final dynamic client; // SupabaseClient
  final CompanionRepository _companionRepo;
  final BookingRepository _fallback = MockBookingRepository();
  SupabaseBookingRepository(this.client, this._companionRepo);

  @override
  Future<Booking> create(Booking booking, {String? clientId}) async {
    try {
      final userId = clientId ?? client.auth.currentUser?.id;
      if (userId == null) {
        return _fallback.create(booking);
      }
      final data = booking.toMap(clientId: userId.toString());
      final response = await client.from('bookings').insert(data).select().single();
      return Booking.fromMap(response as Map<String, dynamic>, booking.companion);
    } catch (_) {
      return _fallback.create(booking);
    }
  }

  @override
  Future<List<Booking>> fetchUserBookings({String? clientId}) async {
    try {
      final userId = clientId ?? client.auth.currentUser?.id;
      if (userId == null) {
        return _fallback.fetchUserBookings();
      }
      final response = await client
          .from('bookings')
          .select('*, companions(*)')
          .eq('client_id', userId)
          .order('start_time', ascending: false);

      final list = <Booking>[];
      for (final row in response as List) {
        final companionData = row['companions'];
        final companion = companionData != null
            ? Companion.fromMap(companionData as Map<String, dynamic>)
            : (await _companionRepo.byId(row['companion_id'].toString())) ?? MockCompanionRepository._data.first;
        list.add(Booking.fromMap(row as Map<String, dynamic>, companion));
      }
      if (list.isEmpty) return _fallback.fetchUserBookings();
      return list;
    } catch (_) {
      return _fallback.fetchUserBookings();
    }
  }

  @override
  Future<bool> updateStatus(String bookingId, BookingStatus status) async {
    try {
      await client.from('bookings').update({'status': status.name}).eq('id', bookingId);
      return true;
    } catch (_) {
      return _fallback.updateStatus(bookingId, status);
    }
  }
}

abstract class ChatRepository {
  Future<List<ChatMessage>> fetchMessages(String companionId, {String? userId});
  Future<ChatMessage> sendMessage(ChatMessage message, {required String companionId, String? senderId});
  Stream<ChatMessage> messageStream(String companionId);
}

class MockChatRepository implements ChatRepository {
  static bool simulateAutoReply = false;
  static final Map<String, List<ChatMessage>> _threads = {};
  static final StreamController<MapEntry<String, ChatMessage>> _streamController =
      StreamController<MapEntry<String, ChatMessage>>.broadcast();

  static void reset() {
    _threads.clear();
    simulateAutoReply = false;
  }

  static void _initThreadIfEmpty(String companionId) {
    if (_threads.containsKey(companionId)) return;
    _threads[companionId] = [
      ChatMessage(
        id: 'msg_1',
        text: 'Hi! Excited for our meetup 😊',
        mine: false,
        time: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'msg_2',
        text: 'Same here! Looking forward to seeing you.',
        mine: true,
        time: DateTime.now().subtract(const Duration(minutes: 28)),
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String companionId, {String? userId}) async {
    _initThreadIfEmpty(companionId);
    return List.from(_threads[companionId]!);
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message, {required String companionId, String? senderId}) async {
    _initThreadIfEmpty(companionId);
    _threads[companionId]!.add(message);
    _streamController.add(MapEntry(companionId, message));

    if (message.mine && simulateAutoReply) {
      final reply = ChatMessage(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        text: message.type == MessageType.location
            ? 'Awesome! That meetup spot looks great. See you there! 📍'
            : 'Sounds great! I will be there right on time.',
        mine: false,
        time: DateTime.now(),
      );
      _threads[companionId]?.add(reply);
      _streamController.add(MapEntry(companionId, reply));
    }

    return message;
  }

  @override
  Stream<ChatMessage> messageStream(String companionId) {
    _initThreadIfEmpty(companionId);
    return _streamController.stream
        .where((entry) => entry.key == companionId)
        .map((entry) => entry.value);
  }
}


class SupabaseChatRepository implements ChatRepository {
  final dynamic client; // SupabaseClient
  final ChatRepository _fallback = MockChatRepository();
  SupabaseChatRepository(this.client);

  @override
  Future<List<ChatMessage>> fetchMessages(String companionId, {String? userId}) async {
    try {
      final currentUserId = userId ?? client.auth.currentUser?.id ?? '';
      final response = await client
          .from('chat_messages')
          .select()
          .eq('companion_id', companionId)
          .order('created_at', ascending: true);

      final list = (response as List)
          .map((row) => ChatMessage.fromMap(row as Map<String, dynamic>, currentUserId))
          .toList();

      if (list.isEmpty) return _fallback.fetchMessages(companionId, userId: userId);
      return list;
    } catch (_) {
      return _fallback.fetchMessages(companionId, userId: userId);
    }
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message, {required String companionId, String? senderId}) async {
    try {
      final currentUserId = senderId ?? client.auth.currentUser?.id ?? 'mock-user';
      final data = message.toMap(
        senderId: currentUserId,
        receiverId: companionId,
        companionId: companionId,
      );
      final response = await client.from('chat_messages').insert(data).select().single();
      return ChatMessage.fromMap(response as Map<String, dynamic>, currentUserId);
    } catch (_) {
      return _fallback.sendMessage(message, companionId: companionId, senderId: senderId);
    }
  }

  @override
  Stream<ChatMessage> messageStream(String companionId) {
    try {
      return _fallback.messageStream(companionId);
    } catch (_) {
      return _fallback.messageStream(companionId);
    }
  }
}
