import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/companion.dart';
import 'rating_stars.dart';

class CompanionCard extends StatelessWidget {
  final Companion c;
  final bool compact; // true = list row layout
  const CompanionCard({super.key, required this.c, this.compact = false});

  void _open(BuildContext context) => context.push('/explore/companion/${c.id}');

  Widget _image(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Hero(
          tag: 'avatar-${c.id}',
          child: Image.network(c.avatarUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 48))),
        ),
        Positioned(top: 8, left: 8, child: _pill(Icons.location_on, '${c.distanceKm.toStringAsFixed(1)} km')),
        if (c.verified)
          const Positioned(top: 8, right: 8, child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.verified, color: Colors.blue, size: 20))),
      ]);

  Widget _pill(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 12, color: Colors.white), const SizedBox(width: 2),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]));

  Widget _info(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${c.name}, ${c.age}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          RatingStars(rating: c.rating, size: 14),
          const SizedBox(height: 4),
          Text(c.tags.take(2).join(' • '), style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            Text('\$${c.hourlyRate.toStringAsFixed(0)}/hr', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            SizedBox(height: 30, child: FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 12)),
                onPressed: () => _open(context), child: const Text('Book Now'))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        child: InkWell(
          onTap: () => _open(context),
          child: compact
              ? SizedBox(height: 130, child: Row(children: [
                  SizedBox(width: 120, child: _image(context)),
                  Expanded(child: Center(child: _info(context))),
                ]))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: _image(context)), _info(context)]),
        ),
      );
}
