import 'companion.dart';

enum MessageType { text, voice, location }

class ChatMessage {
  final String id, text;
  final bool mine;
  final MessageType type;
  final DateTime time;
  final Map<String, dynamic>? payload;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.mine,
    this.type = MessageType.text,
    required this.time,
    this.payload,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    final senderId = map['sender_id']?.toString() ?? '';
    final typeStr = map['type']?.toString() ?? 'text';
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      mine: senderId.isNotEmpty && senderId == currentUserId,
      type: switch (typeStr) {
        'voice' => MessageType.voice,
        'location' => MessageType.location,
        _ => MessageType.text,
      },
      time: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payload: map['payload'] as Map<String, dynamic>?,
      isRead: map['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap({
    required String senderId,
    required String receiverId,
    String? companionId,
  }) => {
    'sender_id': senderId,
    'receiver_id': receiverId,
    if (companionId != null) 'companion_id': companionId,
    'text': text,
    'type': type.name,
    if (payload != null) 'payload': payload,
    'is_read': isRead,
  };
}

class ChatThread {
  final Companion companion;
  final String lastMessage, bookingStatus;
  final int unread;
  final bool online;
  const ChatThread({required this.companion, required this.lastMessage, required this.bookingStatus, this.unread = 0, this.online = false});
}
