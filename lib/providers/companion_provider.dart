import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/companion.dart';
import '../models/review.dart';
import '../models/chat_message.dart';
import '../core/supabase_config.dart';
import '../repositories/repositories.dart';

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
  return ref.watch(allCompanionsProvider).whenData((list) => list.where((c) {
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

final threadsProvider = Provider<List<ChatThread>>((ref) {
  final list = ref.watch(allCompanionsProvider).valueOrNull ?? [];
  const statuses = ['Confirmed', 'Pending', 'Completed'];
  return [
    for (var i = 0; i < list.length && i < 5; i++)
      ChatThread(companion: list[i], online: i.isEven, unread: i == 1 ? 3 : (i == 3 ? 1 : 0),
          bookingStatus: statuses[i % 3], lastMessage: 'See you at the cafe, looking forward to it!')
  ];
});

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
  return created;
}
