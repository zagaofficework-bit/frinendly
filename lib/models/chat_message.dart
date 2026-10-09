import 'companion.dart';

enum MessageType { text, voice, location }

class ChatMessage {
  final String id, text;
  final bool mine;
  final MessageType type;
  final DateTime time;
  const ChatMessage({required this.id, required this.text, required this.mine, this.type = MessageType.text, required this.time});
}

class ChatThread {
  final Companion companion;
  final String lastMessage, bookingStatus;
  final int unread;
  final bool online;
  const ChatThread({required this.companion, required this.lastMessage, required this.bookingStatus, this.unread = 0, this.online = false});
}
