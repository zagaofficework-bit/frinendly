import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/models/chat_message.dart';
import 'package:friendify/providers/chat_provider.dart';
import 'package:friendify/repositories/repositories.dart';
import 'package:friendify/screens/chat_screen.dart';

void main() {
  group('Sprint 4: Real-Time Chat & Safety SOS System Tests', () {
    late MockChatRepository repo;

    setUp(() {
      MockChatRepository.reset();
      repo = MockChatRepository();
    });

    test('Chat repository loads thread messages and allows sending new message', () async {
      final initial = await repo.fetchMessages('c1');
      expect(initial.length, 2);
      expect(initial.first.text, 'Hi! Excited for our meetup 😊');

      final msg = ChatMessage(
        id: 'test_msg_1',
        text: 'Looking forward to meeting!',
        mine: true,
        type: MessageType.text,
        time: DateTime.now(),
      );

      final sent = await repo.sendMessage(msg, companionId: 'c1');
      expect(sent.id, 'test_msg_1');

      final updated = await repo.fetchMessages('c1');
      expect(updated.length, 3);
      expect(updated.last.text, 'Looking forward to meeting!');
    });

    test('ChatMessage supports location and voice note serialization', () {
      final locMsg = ChatMessage(
        id: 'loc_1',
        text: '📍 Meetup spot: Starbucks Bandra',
        mine: true,
        type: MessageType.location,
        time: DateTime.now(),
        payload: {
          'location_name': 'Starbucks Bandra',
          'latitude': 19.0600,
          'longitude': 72.8338,
        },
      );

      final map = locMsg.toMap(senderId: 'u1', receiverId: 'c1', companionId: 'c1');
      expect(map['type'], 'location');
      expect(map['payload']['latitude'], 19.0600);

      final fromMap = ChatMessage.fromMap({
        'id': 'loc_1',
        'sender_id': 'u1',
        'type': 'location',
        'text': '📍 Meetup spot: Starbucks Bandra',
        'payload': {'latitude': 19.0600, 'longitude': 72.8338},
        'created_at': DateTime.now().toIso8601String(),
        'is_read': true,
      }, 'u1');

      expect(fromMap.mine, true);
      expect(fromMap.type, MessageType.location);
      expect(fromMap.isRead, true);
    });

    test('ChatMessagesNotifier sends message and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Keep active listener so autoDispose does not dispose state
      final sub = container.listen(chatMessagesProvider('c1'), (_, __) {});
      addTearDown(sub.close);

      // Yield event loop to let _loadInitial complete
      await Future<void>.delayed(Duration.zero);

      final stateBefore = container.read(chatMessagesProvider('c1'));
      expect(stateBefore.length, 2);

      await container.read(chatMessagesProvider('c1').notifier).send('New chat message');
      final stateAfter = container.read(chatMessagesProvider('c1'));
      expect(stateAfter.length, 3);
      expect(stateAfter.last.text, 'New chat message');
    });


    testWidgets('ChatRoomScreen renders messages, supports sending and displays SOS modal', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChatRoomScreen(companionId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check messages loaded
      expect(find.text('Hi! Excited for our meetup 😊'), findsOneWidget);

      // Dismiss safety banner
      expect(find.byKey(const Key('safety_banner_close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('safety_banner_close')));
      await tester.pumpAndSettle();
      expect(find.textContaining('strictly platonic'), findsNothing);

      // Enter and send text message
      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Hello companion!');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hello companion!'), findsOneWidget);

      // Tap SOS button and verify modal
      await tester.tap(find.byKey(const Key('chat_sos_button')));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Safety SOS'), findsOneWidget);
      expect(find.text('Share live GPS with emergency contacts'), findsOneWidget);
      expect(find.text('Call local emergency number (112 / 911)'), findsOneWidget);
      expect(find.text('Report profile or incident'), findsOneWidget);

      // Tap emergency GPS dispatch
      await tester.tap(find.text('Share live GPS with emergency contacts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('🚨 Live GPS'), findsOneWidget);
    });

    testWidgets('ChatRoomScreen location picker modal shares public meetup spot', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChatRoomScreen(companionId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap location icon
      await tester.tap(find.byKey(const Key('chat_location_button')));
      await tester.pumpAndSettle();

      expect(find.text('Share Safe Meetup Location'), findsOneWidget);
      expect(find.text('Starbucks Coffee, Bandra West'), findsOneWidget);

      // Select Starbucks
      await tester.tap(find.text('Starbucks Coffee, Bandra West'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Starbucks Coffee, Bandra West'), findsOneWidget);
      expect(find.text('Public Meetup Point'), findsOneWidget);
    });
  });
}
