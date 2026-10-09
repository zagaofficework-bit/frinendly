import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../models/companion.dart';
import '../providers/chat_provider.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});
  Color _statusColor(String s) => switch (s) {
        'Confirmed' => Colors.green,
        'Pending' => Colors.orange,
        _ => Colors.grey,
      };

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
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(t.companion.avatarUrl),
                        onBackgroundImageError: (_, __) {},
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: t.online ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Text(t.companion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(t.bookingStatus).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.bookingStatus,
                          style: TextStyle(fontSize: 11, color: _statusColor(t.bookingStatus)),
                        ),
                      ),
                    ],
                  ),
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
  final Set<String> _playingVoiceNotes = {};

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    await ref.read(chatMessagesProvider(widget.companionId).notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _sendLocation(String name, double lat, double lng) async {
    await ref.read(chatMessagesProvider(widget.companionId).notifier).send(
      '📍 Meetup spot: $name',
      type: MessageType.location,
      payload: {
        'location_name': name,
        'latitude': lat,
        'longitude': lng,
      },
    );
    _scrollToBottom();
  }

  Future<void> _sendVoiceNote(int durationSeconds) async {
    await ref.read(chatMessagesProvider(widget.companionId).notifier).send(
      'Voice note (0:${durationSeconds.toString().padLeft(2, '0')})',
      type: MessageType.voice,
      payload: {
        'duration_seconds': durationSeconds,
      },
    );
    _scrollToBottom();
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Safe Meetup Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a recommended public venue for platonic companionship:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.coffee, color: Colors.green),
                ),
                title: const Text('Starbucks Coffee, Bandra West'),
                subtitle: const Text('Verified public cafe venue', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation('Starbucks Coffee, Bandra West', 19.0600, 72.8338);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.local_cafe, color: Colors.green),
                ),
                title: const Text('Blue Tokai Roasters, Bandra'),
                subtitle: const Text('Artisan coffee & coworking spot', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation('Blue Tokai Roasters, Bandra', 19.0558, 72.8290);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.shopping_bag_outlined, color: Colors.blue),
                ),
                title: const Text('Phoenix Palladium, Lower Parel'),
                subtitle: const Text('High-traffic central shopping mall', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation('Phoenix Palladium, Lower Parel', 18.9950, 72.8250);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.my_location, color: Colors.orange),
                ),
                title: const Text('Share Live GPS Coordinates'),
                subtitle: const Text('Live location snapshot (19.0760, 72.8777)', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation('Current GPS Location', 19.0760, 72.8777);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recordVoiceNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulating voice recording... (0:08)'),
        duration: Duration(milliseconds: 1200),
      ),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _sendVoiceNote(8);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Companion? c = ref.watch(allCompanionsProvider).valueOrNull?.where((e) => e.id == widget.companionId).firstOrNull;
    final messages = ref.watch(chatMessagesProvider(widget.companionId));
    final cs = Theme.of(context).colorScheme;

    // Auto-scroll when messages count updates
    ref.listen(chatMessagesProvider(widget.companionId), (prev, next) {
      if (next.length != (prev?.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: c != null ? NetworkImage(c.avatarUrl) : null,
              onBackgroundImageError: c != null ? (_, __) {} : null,
              child: c == null ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c?.name ?? 'Companion', style: const TextStyle(fontSize: 16)),
                  Text(
                    'Online • Platonic Match',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('chat_sos_button'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => showSosSheet(context, ref),
            icon: const Icon(Icons.sos),
            label: const Text('SOS'),
          ),
        ],
      ),
      body: Column(
        children: [
          const SafetyBanner(),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Loading conversation...', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return _buildMessageBubble(m, cs);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('chat_location_button'),
                    icon: const Icon(Icons.location_on_outlined),
                    tooltip: 'Share public meetup spot',
                    onPressed: _showLocationPicker,
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('chat_input_field'),
                      controller: controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('chat_mic_button'),
                    icon: const Icon(Icons.mic_none),
                    tooltip: 'Voice note',
                    onPressed: _recordVoiceNote,
                  ),
                  IconButton.filled(
                    key: const Key('chat_send_button'),
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m, ColorScheme cs) {
    final isMine = m.mine;
    final bubbleColor = isMine ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMine ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.type == MessageType.voice) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_playingVoiceNotes.contains(m.id)) {
                          _playingVoiceNotes.remove(m.id);
                        } else {
                          _playingVoiceNotes.add(m.id);
                        }
                      });
                    },
                    child: Icon(
                      _playingVoiceNotes.contains(m.id)
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 32,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.graphic_eq, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    _playingVoiceNotes.contains(m.id) ? 'Playing...' : m.text,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ] else if (m.type == MessageType.location) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: isMine ? Colors.amberAccent : Colors.red),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isMine ? Colors.black26 : Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 13, color: textColor),
                        const SizedBox(width: 4),
                        Text(
                          'Public Meetup Point',
                          style: TextStyle(fontSize: 10, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                m.text,
                style: TextStyle(color: textColor),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(m.time),
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 13,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

