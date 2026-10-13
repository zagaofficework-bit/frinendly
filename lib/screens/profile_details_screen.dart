import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/companion.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';
import 'booking_modal.dart';

Future<void> _showAddReviewDialog(
    BuildContext context, WidgetRef ref, Companion c) async {
  final auth = ref.read(authProvider);
  if (!auth.isAuthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please sign in to leave a review.'),
        action: SnackBarAction(
            label: 'Sign In', onPressed: () => context.push('/auth')),
      ),
    );
    return;
  }
  await showDialog(
    context: context,
    builder: (ctx) => _AddReviewDialog(companion: c),
  );
}

class _AddReviewDialog extends ConsumerStatefulWidget {
  final Companion companion;
  const _AddReviewDialog({required this.companion});

  @override
  ConsumerState<_AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends ConsumerState<_AddReviewDialog> {
  double _rating = 5.0;
  late final TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AlertDialog(
      title: Text('Review ${widget.companion.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating:'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 30,
                    ),
                    onPressed: () => setState(() => _rating = i.toDouble()),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your Experience',
                hintText: 'Share feedback about your meetup...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final text = _commentCtrl.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context);
            final newReview = Review(
              author: auth.user?.displayName ?? 'Anonymous Member',
              text: text,
              rating: _rating,
              date: DateTime.now(),
            );
            await submitReview(ref, widget.companion.id, newReview);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Thank you! Your review has been submitted.')),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class ProfileDetailsScreen extends ConsumerWidget {
  final String id;
  const ProfileDetailsScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companionByIdProvider(id));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (c) => c == null
          ? const Scaffold(body: Center(child: Text('Not found')))
          : _Body(c: c),
    );
  }
}

class _Body extends ConsumerWidget {
  final Companion c;
  const _Body({required this.c});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final reviews = ref.watch(reviewsProvider(c.id));
    final auth = ref.watch(authProvider);
    final myCompanion = ref.watch(myCompanionProfileProvider).valueOrNull;
    final isSelf = (auth.user != null && c.userId != null && c.userId == auth.user!.id) ||
        (myCompanion != null && myCompanion.id == c.id);

    return Scaffold(
      bottomNavigationBar: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${c.hourlyRate.toStringAsFixed(0)}/hr',
                    style:
                        text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Text('+15% platform fee', style: TextStyle(fontSize: 11)),
              ]),
          const SizedBox(width: 16),
          Expanded(
              child: isSelf
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.person),
                      label: const Text('Your Host Profile (Preview)'),
                      onPressed: () => context.go('/host'),
                    )
                  : Row(
                      children: [
                        OutlinedButton.icon(
                          key: const Key('profile_chat_button'),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          onPressed: () => context.push('/chat/${c.id}'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => showBookingModal(context, c),
                            child: const Text('Book Now'),
                          ),
                        ),
                      ],
                    )),
        ]),
      )),
      body: CustomScrollView(slivers: [
        SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            actions: [
              if (!isSelf)
                IconButton(
                  tooltip: 'Chat with ${c.name}',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => context.push('/chat/${c.id}'),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _Carousel(c: c))),
        SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              Row(children: [
                Expanded(
                    child: Text('${c.name}, ${c.age}',
                        style: text.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold))),
                RatingBadge(rating: c.rating, count: c.reviewCount),
              ]),
              Wrap(spacing: 8, children: [
                Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.location_on, size: 16),
                    label: Text(
                        '${c.city} · ${c.distanceKm.toStringAsFixed(1)} km')),
                if (c.verified)
                  const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar:
                          Icon(Icons.verified, size: 16, color: Colors.blue),
                      label: Text('ID verified')),
                if (c.backgroundChecked)
                  const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.shield, size: 16, color: Colors.green),
                      label: Text('Background checked')),
              ]),
              const SizedBox(height: 12),
              Text('About', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(c.bio),
              const SizedBox(height: 12),
              Text('Languages', style: text.titleMedium),
              Wrap(spacing: 8, children: [
                for (final l in c.languages) Chip(label: Text(l))
              ]),
              Text('Badges & skills', style: text.titleMedium),
              Wrap(spacing: 8, children: [
                for (final b in [...c.badges, ...c.tags])
                  Chip(
                      label: Text(b),
                      avatar: const Icon(Icons.workspace_premium, size: 16))
              ]),
              const SizedBox(height: 16),
              GlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Transparent pricing', style: text.titleMedium),
                    const SizedBox(height: 8),
                    BookingSummary(companion: c, hours: 2),
                    const Text(
                        'Estimate for 2 hours. Choose your duration while booking.',
                        style: TextStyle(fontSize: 11)),
                  ])),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Reviews', style: text.titleMedium),
                if (!isSelf)
                  TextButton.icon(
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Write Review'),
                    onPressed: () => _showAddReviewDialog(context, ref, c),
                  ),
              ]),
              const SizedBox(height: 8),
              reviews.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No reviews yet',
                              style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('Be the first to review this companion!',
                              style: text.bodySmall?.copyWith(
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }
                  return Column(children: [
                    for (var star = 5; star >= 1; star--)
                      Row(children: [
                        SizedBox(width: 18, child: Text('$star')),
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                            child: LinearProgressIndicator(
                                value: list
                                        .where((r) => r.rating.round() == star)
                                        .length /
                                    list.length,
                                borderRadius: BorderRadius.circular(4))),
                      ]),
                    const SizedBox(height: 8),
                    for (final r in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text(r.author.isNotEmpty ? r.author[0] : 'U')),
                        title: Row(children: [
                          Text(r.author),
                          const SizedBox(width: 8),
                          RatingStars(
                              rating: r.rating, size: 12, showValue: false)
                        ]),
                        subtitle: Text(
                            '${r.text}\n${DateFormat.yMMMd().format(r.date)}'),
                        isThreeLine: true,
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 40),
            ]))),
      ]),
    );
  }
}

class _Carousel extends StatefulWidget {
  final Companion c;
  const _Carousel({required this.c});
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final imgs = [widget.c.avatarUrl, ...widget.c.gallery].where((u) => u.trim().isNotEmpty).toList();
    if (imgs.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: Text(
          widget.c.name.isNotEmpty ? widget.c.name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: imgs.length,
        onPageChanged: (i) => setState(() => page = i),
        itemBuilder: (_, i) {
          final img = Image.network(imgs[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey.shade300));
          return i == 0 ? Hero(tag: 'avatar-${widget.c.id}', child: img) : img;
        },
      ),
      Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < imgs.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: page == i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                    color: page == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4)),
              ),
          ])),
    ]);
  }
}
