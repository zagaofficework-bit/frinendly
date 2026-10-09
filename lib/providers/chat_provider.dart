import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_config.dart';
import '../models/chat_message.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = SupabaseConfig.client;
  if (SupabaseConfig.isConfigured && client != null) {
    return SupabaseChatRepository(client);
  }
  return MockChatRepository();
});

class ChatMessagesNotifier extends AutoDisposeFamilyNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatMessage>? _subscription;

  @override
  List<ChatMessage> build(String arg) {
    final companionId = arg;
    final repo = ref.watch(chatRepositoryProvider);

    _subscription = repo.messageStream(companionId).listen((incoming) {
      if (!state.any((m) => m.id == incoming.id)) {
        state = [...state, incoming];
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
    state = msgs;
  }

  Future<ChatMessage> send(
    String text, {
    MessageType type = MessageType.text,
    Map<String, dynamic>? payload,
  }) async {
    final companionId = arg;
    final repo = ref.read(chatRepositoryProvider);
    final auth = ref.read(authProvider);

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      mine: true,
      type: type,
      time: DateTime.now(),
      payload: payload,
    );

    final saved = await repo.sendMessage(
      newMsg,
      companionId: companionId,
      senderId: auth.user?.id,
    );

    if (!state.any((m) => m.id == saved.id)) {
      state = [...state, saved];
    }

    return saved;
  }
}

final chatMessagesProvider =
    AutoDisposeNotifierProviderFamily<ChatMessagesNotifier, List<ChatMessage>, String>(
  ChatMessagesNotifier.new,
);
