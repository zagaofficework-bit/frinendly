import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:friendify/core/supabase_config.dart';
import 'package:friendify/models/companion.dart';
import 'package:friendify/models/booking.dart';
import 'package:friendify/models/review.dart';
import 'package:friendify/models/chat_message.dart';
import 'package:friendify/repositories/repositories.dart';
import 'package:friendify/providers/companion_provider.dart';
import 'package:friendify/providers/booking_provider.dart';
import 'package:friendify/providers/chat_provider.dart';

void main() {
  group('Supabase Live Database Connection & Table Relationships Tests', () {
    late SupabaseClient client;

    setUpAll(() async {
      // Initialize Supabase with project configuration
      client = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
      );
    });

    test('1. Test connection and load data from companions table', () async {
      final response = await client
          .from('companions')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      expect(response, isNotEmpty, reason: 'Companions table should return active companion profiles');
      
      final list = (response as List)
          .map((row) => Companion.fromMap(row as Map<String, dynamic>))
          .toList();

      expect(list.length, greaterThanOrEqualTo(5));
      final maya = list.firstWhere((c) => c.name.contains('Maya'));
      expect(maya.city, equals('Mumbai'));
      expect(maya.hourlyRate, greaterThan(0));
      expect(maya.activities, isNotEmpty);
      expect(maya.gallery, isNotEmpty);
    });

    test('2. Test reviews table and foreign key connection to companions', () async {
      final response = await client
          .from('reviews')
          .select('*, companions(*)')
          .order('created_at', ascending: false);

      expect(response, isA<List>());
      final list = response as List;
      if (list.isNotEmpty) {
        final firstReview = list.first as Map<String, dynamic>;
        expect(firstReview['companion_id'], isNotNull);
        expect(firstReview['companions'], isNotNull,
            reason: 'Foreign key to companions table should load related companion object');
        final companionData = firstReview['companions'] as Map<String, dynamic>;
        expect(companionData['name'], isNotNull);

        final reviewModel = Review.fromMap(firstReview);
        expect(reviewModel.rating, inInclusiveRange(1.0, 5.0));
      }
    });

    test('3. Test chat_messages table and connection with companions', () async {
      final response = await client
          .from('chat_messages')
          .select('*, companions(*)')
          .order('created_at', ascending: false)
          .limit(5);

      expect(response, isA<List>());
      final list = response as List;
      if (list.isNotEmpty) {
        final msg = list.first as Map<String, dynamic>;
        expect(msg['companion_id'], isNotNull);
        expect(msg['companions'], isNotNull,
            reason: 'Chat message foreign key join with companions table must succeed');
      }
    });

    test('4. Test bookings table schema and foreign key relationship with companions', () async {
      final response = await client
          .from('bookings')
          .select('*, companions(*)')
          .limit(5);

      expect(response, isA<List>(),
          reason: 'Bookings joined with companions should execute without schema or foreign key errors');
    });

    test('5. Test profiles and emergency_contacts tables connection', () async {
      final profilesRes = await client.from('profiles').select().limit(1);
      expect(profilesRes, isA<List>());

      final contactsRes = await client.from('emergency_contacts').select('*, profiles(*)').limit(1);
      expect(contactsRes, isA<List>());
    });

    test('6. Test Repository implementation with live Supabase client', () async {
      final companionRepo = SupabaseCompanionRepository(client);
      final companions = await companionRepo.fetchCompanions();

      expect(companions, isNotEmpty);
      expect(companions.first.name, isNotEmpty);

      final singleCompanion = await companionRepo.byId(companions.first.id);
      expect(singleCompanion, isNotNull);
      expect(singleCompanion!.id, equals(companions.first.id));

      final reviews = await companionRepo.reviews(companions.first.id);
      expect(reviews, isA<List<Review>>());
    });

    test('7. Test Riverpod Provider hooks with live Supabase repository overrides', () async {
      final container = ProviderContainer(
        overrides: [
          companionRepositoryProvider.overrideWithValue(SupabaseCompanionRepository(client)),
          bookingRepositoryProvider.overrideWithValue(
            SupabaseBookingRepository(client, SupabaseCompanionRepository(client)),
          ),
          chatRepositoryProvider.overrideWithValue(SupabaseChatRepository(client)),
        ],
      );

      addTearDown(container.dispose);

      // Test allCompanionsProvider hook
      final loadedCompanions = await container.read(allCompanionsProvider.future);
      expect(loadedCompanions, isNotEmpty);
      expect(loadedCompanions.any((c) => c.name.contains('Maya')), isTrue);

      // Test filterProvider hook integration
      final filteredState = container.read(companionsProvider);
      expect(filteredState.value, isNotNull);
      expect(filteredState.value!.length, equals(loadedCompanions.length));

      // Test filter by city
      container.read(filterProvider.notifier).update(
        const CompanionFilter(location: 'Mumbai'),
      );
      final mumbaiFiltered = container.read(companionsProvider);
      expect(
        mumbaiFiltered.value!.every((c) => c.city.toLowerCase().contains('mumbai')),
        isTrue,
      );
    });
  });
}
