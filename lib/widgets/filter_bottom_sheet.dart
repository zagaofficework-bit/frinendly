import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/companion_provider.dart';

const kActivities = ['Coffee', 'Gym Buddy', 'Event Plus-One', 'Sightseeing', 'Board Games'];

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});
  @override
  ConsumerState<FilterBottomSheet> createState() => _State();
}

class _State extends ConsumerState<FilterBottomSheet> {
  late CompanionFilter f = ref.read(filterProvider);
  late final loc = TextEditingController(text: f.location);
  @override
  void dispose() { loc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: loc, decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined), labelText: 'Location', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const Text('Activity'),
            Wrap(spacing: 8, children: [
              for (final a in kActivities)
                ChoiceChip(label: Text(a), selected: f.activity == a, onSelected: (s) => setState(() => f = f.copyWith(activity: s ? a : null))),
            ]),
            const SizedBox(height: 16),
            Text('Hourly rate: \$${f.minRate.round()} - \$${f.maxRate.round()}'),
            RangeSlider(min: 0, max: 200, divisions: 40, values: RangeValues(f.minRate, f.maxRate),
                onChanged: (v) => setState(() => f = f.copyWith(minRate: v.start, maxRate: v.end))),
            Text('Minimum rating: ${f.minRating.toStringAsFixed(1)}'),
            Slider(min: 0, max: 5, divisions: 10, value: f.minRating, onChanged: (v) => setState(() => f = f.copyWith(minRating: v))),
            Row(children: [
              TextButton(onPressed: () { ref.read(filterProvider.notifier).update(const CompanionFilter()); Navigator.pop(context); }, child: const Text('Reset')),
              const Spacer(),
              FilledButton(onPressed: () { ref.read(filterProvider.notifier).update(f.copyWith(location: loc.text)); Navigator.pop(context); }, child: const Text('Apply')),
            ]),
          ]),
        ),
      );
}
