import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/companion.dart';
import '../models/review.dart';
import '../core/supabase_config.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';

final companionRepositoryProvider = Provider<CompanionRepository>((_) {
  final client = SupabaseConfig.client;
  if (SupabaseConfig.isConfigured && client != null) {
    return SupabaseCompanionRepository(client);
  }
  return MockCompanionRepository();
});

const _keep = Object();

class CompanionFilter {
  final String query, location;
  final String? activity;
  final double minRate, maxRate, minRating;
  const CompanionFilter({this.query = '', this.location = '', this.activity, this.minRate = 0, this.maxRate = 200, this.minRating = 0});
  CompanionFilter copyWith({String? query, String? location, Object? activity = _keep, double? minRate, double? maxRate, double? minRating}) =>
      CompanionFilter(
          query: query ?? this.query, location: location ?? this.location,
          activity: identical(activity, _keep) ? this.activity : activity as String?,
          minRate: minRate ?? this.minRate, maxRate: maxRate ?? this.maxRate, minRating: minRating ?? this.minRating);
}

class FilterNotifier extends Notifier<CompanionFilter> {
  @override
  CompanionFilter build() => const CompanionFilter();
  void update(CompanionFilter f) => state = f;
}
final filterProvider = NotifierProvider<FilterNotifier, CompanionFilter>(FilterNotifier.new);

enum ViewModeType { grid, list, stack }
class ViewModeNotifier extends Notifier<ViewModeType> {
  @override
  ViewModeType build() => ViewModeType.grid;
  void set(ViewModeType v) => state = v;
}
final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewModeType>(ViewModeNotifier.new);

final allCompanionsProvider = FutureProvider<List<Companion>>((ref) => ref.watch(companionRepositoryProvider).fetchCompanions());

final companionsProvider = Provider<AsyncValue<List<Companion>>>((ref) {
  final f = ref.watch(filterProvider);
  final auth = ref.watch(authProvider);
  final myCompanion = ref.watch(myCompanionProfileProvider).valueOrNull;

  return ref.watch(allCompanionsProvider).whenData((list) => list.where((c) {
        // Logical rule: Host cannot discover, swipe, or book themselves in Explore feed
        final isSelf = (auth.user != null && c.userId != null && c.userId == auth.user!.id) ||
            (myCompanion != null && myCompanion.id == c.id);
        if (isSelf) return false;

        final q = f.query.toLowerCase();
        final loc = f.location.toLowerCase();
        return (q.isEmpty || c.name.toLowerCase().contains(q) || c.tags.any((t) => t.toLowerCase().contains(q))) &&
            (loc.isEmpty || c.city.toLowerCase().contains(loc)) &&
            (f.activity == null || c.activities.contains(f.activity)) &&
            c.hourlyRate >= f.minRate && c.hourlyRate <= f.maxRate && c.rating >= f.minRating;
      }).toList());
});

final companionByIdProvider = FutureProvider.family<Companion?, String>((ref, id) => ref.watch(companionRepositoryProvider).byId(id));
final reviewsProvider = FutureProvider.family<List<Review>, String>((ref, id) => ref.watch(companionRepositoryProvider).reviews(id));

Future<bool> submitReview(dynamic ref, String companionId, Review review) async {
  final repo = ref.read(companionRepositoryProvider) as CompanionRepository;
  final ok = await repo.addReview(companionId, review);
  if (ok) {
    ref.invalidate(reviewsProvider(companionId));
    ref.invalidate(companionByIdProvider(companionId));
    ref.invalidate(allCompanionsProvider);
  }
  return ok;
}

Future<Companion?> registerCompanion(dynamic ref, Companion companion, {String? userId}) async {
  final repo = ref.read(companionRepositoryProvider) as CompanionRepository;
  final created = await repo.createOrUpdateCompanion(companion, userId: userId);
  ref.invalidate(allCompanionsProvider);
  ref.invalidate(myCompanionProfileProvider);
  return created;
}

final myCompanionProfileProvider = FutureProvider<Companion?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.user == null) return null;
  final client = SupabaseConfig.client;
  if (SupabaseConfig.isConfigured && client != null) {
    try {
      final res = await client
          .from('companions')
          .select()
          .eq('user_id', auth.user!.id)
          .maybeSingle();
      if (res != null) {
        return Companion.fromMap(res);
      }
    } catch (_) {}
  }
  return null;
});

Future<bool> updateCompanionAvailability(dynamic ref, String companionId, bool isActive) async {
  final client = SupabaseConfig.client;
  if (client != null) {
    try {
      final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
          .hasMatch(companionId);
      if (isUuid) {
        await client.from('companions').update({'is_active': isActive}).eq('id', companionId);
      }
      ref.invalidate(myCompanionProfileProvider);
      ref.invalidate(allCompanionsProvider);
      return true;
    } catch (_) {}
  }
  return false;
}

Future<bool> updateCompanionHourlyRate(dynamic ref, String companionId, double newRate) async {
  final client = SupabaseConfig.client;
  if (client != null) {
    try {
      final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
          .hasMatch(companionId);
      if (isUuid) {
        await client.from('companions').update({'hourly_rate': newRate}).eq('id', companionId);
      }
      ref.invalidate(myCompanionProfileProvider);
      ref.invalidate(allCompanionsProvider);
      return true;
    } catch (_) {}
  }
  return false;
}

Future<bool> updateCompanionProfile(dynamic ref, Companion companion) async {
  final client = SupabaseConfig.client;
  if (client != null) {
    try {
      final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
          .hasMatch(companion.id);
      if (isUuid) {
        await client.from('companions').update(companion.toMap()).eq('id', companion.id);
      } else if (companion.userId != null) {
        await client.from('companions').update(companion.toMap()).eq('user_id', companion.userId!);
      }
      ref.invalidate(myCompanionProfileProvider);
      ref.invalidate(allCompanionsProvider);
      return true;
    } catch (e) {
      debugPrint('⚠️ Error updating companion profile in Supabase: $e');
    }
  }
  final repo = ref.read(companionRepositoryProvider) as CompanionRepository;
  await repo.createOrUpdateCompanion(companion);
  ref.invalidate(myCompanionProfileProvider);
  ref.invalidate(allCompanionsProvider);
  return true;
}

