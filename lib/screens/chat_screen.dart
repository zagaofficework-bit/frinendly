import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../models/companion.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';

class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) => switch (s) {
        'Confirmed' => Colors.green,
        'Pending' => Colors.orange,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final allThreads = ref.watch(threadsProvider);
    final threads = _query.isEmpty
        ? allThreads
        : allThreads.where((t) {
            final q = _query.toLowerCase();
            return t.companion.name.toLowerCase().contains(q) ||
                t.lastMessage.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allCompanionsProvider);
          ref.invalidate(myCompanionProfileProvider);
          await ref.read(allCompanionsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const Key('chat_search_field'),
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _query = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search chats or messages...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (threads.isEmpty) ...[
              const SizedBox(height: 80),
              Center(
                child: Text(
                  _query.isEmpty ? 'No conversations yet' : 'No chats found for "$_query"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ] else
              for (var i = 0; i < threads.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildThreadTile(context, threads[i]),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildThreadTile(BuildContext context, ChatThread t) {
    return ListTile(
      onTap: () => context.push('/chat/${t.companion.id}'),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: t.companion.avatarUrl.isNotEmpty
                ? NetworkImage(t.companion.avatarUrl)
                : null,
            onBackgroundImageError: t.companion.avatarUrl.isNotEmpty
                ? (_, __) {}
                : null,
            child: t.companion.avatarUrl.isEmpty
                ? Text(
                    t.companion.name.isNotEmpty
                        ? t.companion.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
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
          Expanded(
            child: Text(
              t.companion.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (t.lastMessageTime != null)
            Text(
              _formatTime(t.lastMessageTime!),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          if (t.unread > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Badge(label: Text('${t.unread}')),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return DateFormat.jm().format(time);
    }
    return DateFormat.MMMd().format(time);
  }
}

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String companionId;
  const ChatRoomScreen({
    super.key,
    required this.companionId,
  });

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
    try {
      await ref.read(chatMessagesProvider(widget.companionId).notifier).send(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                key: const Key('osm_pick_map_pin_button'),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.map_outlined, color: Theme.of(context).colorScheme.primary),
                ),
                title: const Text('Pick on Live OpenStreetMap Pin', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Drag pin & select any custom meeting venue', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await showDialog<MeetupLocationResult>(
                    context: context,
                    builder: (_) => const OsmLocationPickerDialog(),
                  );
                  if (res != null) {
                    _sendLocation(res.name, res.latitude, res.longitude);
                  }
                },
              ),
              const Divider(height: 12),
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

  Future<void> _sendImage(String imageUrl, String caption) async {
    await ref.read(chatMessagesProvider(widget.companionId).notifier).send(
      caption.isNotEmpty ? caption : 'Shared a photo',
      type: MessageType.image,
      payload: {
        'image_url': imageUrl,
      },
    );
    _scrollToBottom();
  }

  void _showImagePicker() {
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
                'Share Activity / Venue Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Share safe, verified meetup spot images or activity ideas:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F7FA),
                  child: Icon(Icons.coffee, color: Colors.teal),
                ),
                title: const Text('Coffee & Cafe Meetup'),
                subtitle: const Text('Cozy table setting photo', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImage(
                    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600',
                    'Found this nice cafe spot for our meetup! ☕',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E5F5),
                  child: Icon(Icons.palette_outlined, color: Colors.purple),
                ),
                title: const Text('Art Museum / Gallery'),
                subtitle: const Text('Exhibition hall atmosphere', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImage(
                    'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=600',
                    'How about visiting this art exhibition? 🎨',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.park_outlined, color: Colors.green),
                ),
                title: const Text('Park / Nature Walk'),
                subtitle: const Text('Outdoor walking spot', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImage(
                    'https://images.unsplash.com/photo-1448375240586-882707db888b?w=600',
                    'Great weather for a walk here! 🌳',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.add_photo_alternate_outlined, color: Colors.orange),
                ),
                title: const Text('Custom Photo URL...'),
                subtitle: const Text('Paste image web address with caption', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomPhotoUrlDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomPhotoUrlDialog() {
    final urlCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Image URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Image URL (https://...)',
                hintText: 'https://example.com/photo.jpg',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capCtrl,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'Check this spot!',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                _sendImage(url, capCtrl.text.trim());
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Companion? c = ref.watch(allCompanionsProvider).valueOrNull?.where((e) => e.id == widget.companionId).firstOrNull;
    final messages = ref.watch(chatMessagesProvider(widget.companionId));
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final myCompanion = ref.watch(myCompanionProfileProvider).valueOrNull;

    final isSelf = (auth.user != null && c?.userId != null && c!.userId == auth.user!.id) ||
        (myCompanion != null && myCompanion.id == widget.companionId);

    if (isSelf && messages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(c?.name ?? 'Host Profile'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum_outlined, size: 48, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 20),
                Text(
                  '${c?.name ?? "Host"} Inbox',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No client messages yet. When clients book or message your profile, their messages will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Messages'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Auto-scroll when messages count updates
    ref.listen(chatMessagesProvider(widget.companionId), (prev, next) {
      if (next.length != (prev?.length ?? 0)) {
        _scrollToBottom();
      }
    });

    final partnerName = isSelf ? '${c?.name ?? "Host"} · Client Conversation' : (c?.name ?? 'Companion');
    final partnerSubtitle = isSelf ? 'Host Mode · Replying to Client' : 'Online • Platonic Match';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: (c != null && c.avatarUrl.isNotEmpty) ? NetworkImage(c.avatarUrl) : null,
              onBackgroundImageError: (c != null && c.avatarUrl.isNotEmpty) ? (_, __) {} : null,
              child: (c == null || c.avatarUrl.isEmpty)
                  ? Text(partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'C')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(partnerName, style: const TextStyle(fontSize: 16)),
                  Text(
                    partnerSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelf ? Colors.blue.shade600 : Colors.green.shade600,
                    ),
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: (c != null && c.avatarUrl.isNotEmpty)
                                ? NetworkImage(c.avatarUrl)
                                : null,
                            onBackgroundImageError: (c != null && c.avatarUrl.isNotEmpty)
                                ? (_, __) {}
                                : null,
                            child: (c == null || c.avatarUrl.isEmpty)
                                ? Text(
                                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Say hello to $partnerName! 👋',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Meetups are strictly platonic. Plan your activities and choose verified public venues.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
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
                  IconButton(
                    key: const Key('chat_photo_button'),
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Share photo or activity',
                    onPressed: _showImagePicker,
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
            ] else if (m.type == MessageType.image) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 260),
                      child: Image.network(
                        m.payload?['image_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          width: 200,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  if (m.text.isNotEmpty && m.text != 'Shared a photo') ...[
                    const SizedBox(height: 6),
                    Text(
                      m.text,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ] else if (m.type == MessageType.location) ...[
              OsmMapBubble(
                locationName: m.payload?['location_name']?.toString() ??
                    (m.text.startsWith('📍 Meetup spot: ')
                        ? m.text.replaceFirst('📍 Meetup spot: ', '')
                        : m.text),
                latitude: (m.payload?['latitude'] as num?)?.toDouble() ?? 19.0600,
                longitude: (m.payload?['longitude'] as num?)?.toDouble() ?? 72.8338,
                isMine: isMine,
                textColor: textColor,
              ),
            ] else if (m.payload != null && m.payload!['type'] == 'booking_confirmation') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available, color: Colors.green, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Confirmed Escrow Booking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isMine ? textColor : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.text.replaceAll('📅 Booking Confirmed!\n', ''),
                      style: TextStyle(fontSize: 13, height: 1.35, color: textColor),
                    ),
                  ],
                ),
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

