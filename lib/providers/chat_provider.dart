import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_config.dart';
import '../models/booking.dart';
import '../models/chat_message.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';
import 'booking_provider.dart';
import 'companion_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = SupabaseConfig.client;
  if (SupabaseConfig.isConfigured && client != null) {
    return SupabaseChatRepository(client);
  }
  return MockChatRepository();
});

class LatestMessagesNotifier extends Notifier<Map<String, ChatMessage>> {
  @override
  Map<String, ChatMessage> build() {
    Future.microtask(() => _loadAll());
    return {};
  }

  Future<void> _loadAll() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final map = await repo.fetchLatestMessages();
      if (map.isNotEmpty) {
        state = {...state, ...map};
      }
    } catch (_) {}
  }

  void updateLatest(String companionId, ChatMessage msg) {
    final current = state[companionId];
    if (current == null || !msg.time.isBefore(current.time)) {
      state = {...state, companionId: msg};
    }
  }

  void seedMultiple(Map<String, ChatMessage> map) {
    state = {...state, ...map};
  }
}

final latestMessagesProvider = NotifierProvider<LatestMessagesNotifier, Map<String, ChatMessage>>(
  LatestMessagesNotifier.new,
);

class ChatMessagesNotifier extends AutoDisposeFamilyNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatMessage>? _subscription;

  @override
  List<ChatMessage> build(String arg) {
    final companionId = arg;
    final repo = ref.watch(chatRepositoryProvider);

    _subscription = repo.messageStream(companionId).listen((incoming) {
      if (!state.any((m) => m.id == incoming.id)) {
        state = [...state, incoming];
        ref.read(latestMessagesProvider.notifier).updateLatest(companionId, incoming);
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    _loadInitial(companionId);
    return [];
  }

  Future<void> _loadInitial(String companionId) async {
    final repo = ref.read(chatRepositoryProvider);
    final auth = ref.read(authProvider);
    final msgs = await repo.fetchMessages(companionId, userId: auth.user?.id);
    final incomingIds = msgs.map((m) => m.id).toSet();
    final combined = [
      ...msgs,
      ...state.where((m) => !incomingIds.contains(m.id)),
    ];
    state = combined;
    if (combined.isNotEmpty) {
      ref.read(latestMessagesProvider.notifier).updateLatest(companionId, combined.last);
    }
  }

  Future<ChatMessage> send(
    String text, {
    MessageType type = MessageType.text,
    Map<String, dynamic>? payload,
  }) async {
    final companionId = arg;
    final repo = ref.read(chatRepositoryProvider);
    final auth = ref.read(authProvider);
    final myCompanion = ref.read(myCompanionProfileProvider).valueOrNull;

    final targetCompanion = ref.read(allCompanionsProvider).valueOrNull?.where((c) => c.id == companionId).firstOrNull;
    final isHostReplying = (myCompanion != null && myCompanion.id == companionId) ||
        (auth.user != null && targetCompanion?.userId != null && targetCompanion!.userId == auth.user!.id);

    // If host is trying to send but there are zero messages from any client
    if (isHostReplying && state.isEmpty) {
      throw Exception('Cannot send message to your own profile without a client conversation.');
    }

    // Determine target receiver
    final incomingClientMsg = state.reversed.where((m) => m.senderId != null && m.senderId != auth.user?.id).firstOrNull;
    final targetReceiver = isHostReplying ? incomingClientMsg?.senderId : targetCompanion?.userId;

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      mine: true,
      senderId: auth.user?.id,
      receiverId: targetReceiver,
      type: type,
      time: DateTime.now(),
      payload: payload,
    );

    final saved = await repo.sendMessage(
      newMsg,
      companionId: companionId,
      senderId: auth.user?.id,
      receiverId: targetReceiver,
    );

    if (!state.any((m) => m.id == saved.id)) {
      state = [...state, saved];
    }
    ref.read(latestMessagesProvider.notifier).updateLatest(companionId, saved);

    return saved;
  }
}

final chatMessagesProvider =
    AutoDisposeNotifierProviderFamily<ChatMessagesNotifier, List<ChatMessage>, String>(
  ChatMessagesNotifier.new,
);

final threadsProvider = Provider<List<ChatThread>>((ref) {
  final companions = ref.watch(allCompanionsProvider).valueOrNull ?? [];
  final bookings = ref.watch(bookingsProvider);
  final latestMap = ref.watch(latestMessagesProvider);
  final auth = ref.watch(authProvider);
  final myCompanion = ref.watch(myCompanionProfileProvider).valueOrNull;

  final threads = <ChatThread>[];

  for (final c in companions) {
    // Check if this is the user's own companion profile
    final isSelf = (auth.user != null && c.userId != null && c.userId == auth.user!.id) ||
        (myCompanion != null && myCompanion.id == c.id);

    final matchingBooking = bookings.where((b) => b.companion.id == c.id).firstOrNull;
    final lastMsg = latestMap[c.id];

    // If it's my own host profile and nobody has chatted or booked it yet, don't show it in inbox
    if (isSelf && lastMsg == null && matchingBooking == null) {
      continue;
    }

    final bookingStatus = isSelf
        ? 'Host (Client Chat)'
        : (matchingBooking != null
            ? switch (matchingBooking.status) {
                BookingStatus.confirmed => 'Confirmed',
                BookingStatus.completed => 'Completed',
                BookingStatus.canceled => 'Canceled',
                BookingStatus.pending => 'Pending',
              }
            : (c.isActive ? 'Available' : 'Paused'));

    threads.add(ChatThread(
      companion: c,
      online: c.isActive,
      unread: 0,
      bookingStatus: bookingStatus,
      lastMessage: lastMsg != null ? lastMsg.text : 'Tap to message ${c.name}',
      lastMessageTime: lastMsg?.time,
    ));
  }

  // Active threads with messages or bookings sorted to top
  threads.sort((a, b) {
    final aHasBooking = bookings.any((bk) => bk.companion.id == a.companion.id);
    final bHasBooking = bookings.any((bk) => bk.companion.id == b.companion.id);
    final aHasMsg = latestMap.containsKey(a.companion.id);
    final bHasMsg = latestMap.containsKey(b.companion.id);

    final aScore = (aHasMsg ? 2 : 0) + (aHasBooking ? 1 : 0);
    final bScore = (bHasMsg ? 2 : 0) + (bHasBooking ? 1 : 0);

    if (aScore != bScore) {
      return bScore.compareTo(aScore);
    }
    if (a.lastMessageTime != null && b.lastMessageTime != null) {
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    } else if (a.lastMessageTime != null) {
      return -1;
    } else if (b.lastMessageTime != null) {
      return 1;
    }
    return 0;
  });

  return threads;
});

