import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../models/companion.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});
  Color _statusColor(String s) => switch (s) { 'Confirmed' => Colors.green, 'Pending' => Colors.orange, _ => Colors.grey };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(threadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: threads.isEmpty
          ? const Center(child: Text('No conversations yet'))
          : ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = threads[i];
                return ListTile(
                  onTap: () => context.push('/chat/${t.companion.id}'),
                  leading: Stack(children: [
                    CircleAvatar(radius: 26, backgroundImage: NetworkImage(t.companion.avatarUrl)),
                    Positioned(right: 0, bottom: 0, child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(color: t.online ? Colors.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2)))),
                  ]),
                  title: Row(children: [
                    Text(t.companion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor(t.bookingStatus).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(t.bookingStatus, style: TextStyle(fontSize: 11, color: _statusColor(t.bookingStatus))),
                    ),
                  ]),
                  subtitle: Text(t.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: t.unread > 0 ? Badge(label: Text('${t.unread}')) : null,
                );
              },
            ),
    );
  }
}

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String companionId;
  const ChatRoomScreen({super.key, required this.companionId});
  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomState();
}

class _ChatRoomState extends ConsumerState<ChatRoomScreen> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  late final List<ChatMessage> messages = [
    ChatMessage(id: '1', text: 'Hi! Excited for our meetup 😊', mine: false, time: DateTime.now().subtract(const Duration(minutes: 30))),
    ChatMessage(id: '2', text: 'Same here! Is the cafe okay?', mine: true, time: DateTime.now().subtract(const Duration(minutes: 28))),
  ];

  @override
  void dispose() { controller.dispose(); scroll.dispose(); super.dispose(); }

  void _add(String text, MessageType type) {
    setState(() => messages.add(ChatMessage(id: '${messages.length + 1}', text: text, mine: true, type: type, time: DateTime.now())));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _send() {
    final t = controller.text.trim();
    if (t.isEmpty) return;
    controller.clear();
    _add(t, MessageType.text);
  }

  @override
  Widget build(BuildContext context) {
    final Companion? c = ref.watch(allCompanionsProvider).valueOrNull?.where((e) => e.id == widget.companionId).firstOrNull;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundImage: c == null ? null : NetworkImage(c.avatarUrl)),
          const SizedBox(width: 10),
          Text(c?.name ?? 'Chat'),
        ]),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => showSosSheet(context),
            icon: const Icon(Icons.sos), label: const Text('SOS'),
          ),
        ],
      ),
      body: Column(children: [
        const SafetyBanner(),
        Expanded(child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final m = messages[i];
            return Align(
              alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(color: m.mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m.type == MessageType.voice) Icon(Icons.graphic_eq, color: m.mine ? cs.onPrimary : cs.onSurface),
                    if (m.type == MessageType.location) Icon(Icons.location_on, color: m.mine ? cs.onPrimary : cs.onSurface),
                    if (m.type != MessageType.text) const SizedBox(width: 6),
                    Flexible(child: Text(m.text, style: TextStyle(color: m.mine ? cs.onPrimary : cs.onSurface))),
                  ]),
                  Text(DateFormat.jm().format(m.time), style: TextStyle(fontSize: 10, color: (m.mine ? cs.onPrimary : cs.onSurface).withValues(alpha: 0.7))),
                ]),
              ),
            );
          },
        )),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.location_on_outlined), tooltip: 'Share location', onPressed: () => _add('Shared live location (mock)', MessageType.location)),
            Expanded(child: TextField(
              controller: controller,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(hintText: 'Message', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
            )),
            IconButton(icon: const Icon(Icons.mic_none), tooltip: 'Voice note (mock)', onPressed: () => _add('Voice note 0:07', MessageType.voice)),
            IconButton.filled(icon: const Icon(Icons.send), onPressed: _send),
          ]),
        )),
      ]),
    );
  }
}
