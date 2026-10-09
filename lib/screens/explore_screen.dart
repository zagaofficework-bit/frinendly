import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/companion.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final mode = ref.watch(viewModeProvider);
    final result = ref.watch(companionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Explore'), actions: [
        SegmentedButton<ViewModeType>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: ViewModeType.grid, icon: Icon(Icons.grid_view)),
            ButtonSegment(value: ViewModeType.list, icon: Icon(Icons.view_list)),
            ButtonSegment(value: ViewModeType.stack, icon: Icon(Icons.style)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => ref.read(viewModeProvider.notifier).set(s.first),
        ),
        const SizedBox(width: 12),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(child: SearchBar(
              hintText: 'Search name or interest',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => ref.read(filterProvider.notifier).update(filter.copyWith(query: v)),
            )),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.tune),
              onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const FilterBottomSheet()),
            ),
          ]),
        ),
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final a in kActivities)
            Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
              label: Text(a), selected: filter.activity == a,
              onSelected: (s) => ref.read(filterProvider.notifier).update(filter.copyWith(activity: s ? a : null)))),
        ])),
        Expanded(child: result.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) return const Center(child: Text('No companions match your filters.'));
            switch (mode) {
              case ViewModeType.grid:
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allCompanionsProvider);
                    await ref.read(allCompanionsProvider.future);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.66, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => CompanionCard(c: list[i]),
                  ),
                );
              case ViewModeType.list:
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allCompanionsProvider);
                    await ref.read(allCompanionsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => CompanionCard(c: list[i], compact: true),
                  ),
                );
              case ViewModeType.stack:
                return SwipeStack(key: ValueKey(list.length), items: list);
            }
          },
        )),
      ]),
    );
  }
}

class SwipeStack extends StatefulWidget {
  final List<Companion> items;
  const SwipeStack({super.key, required this.items});
  @override
  State<SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<SwipeStack> {
  int index = 0;
  double dx = 0;
  void _next() => setState(() { index++; dx = 0; });

  @override
  Widget build(BuildContext context) {
    if (index >= widget.items.length) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('You have seen everyone nearby!'),
        TextButton(onPressed: () => setState(() => index = 0), child: const Text('Start over')),
      ]));
    }
    final top = widget.items[index];
    final next = index + 1 < widget.items.length ? widget.items[index + 1] : null;
    return Column(children: [
      Expanded(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Stack(children: [
          if (next != null) Positioned.fill(child: Transform.scale(scale: 0.94, child: CompanionCard(c: next))),
          Positioned.fill(child: GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => dx += d.delta.dx),
            onHorizontalDragEnd: (_) {
              if (dx.abs() > 120) {
                final liked = dx > 0;
                final c = top;
                _next();
                if (liked) context.push('/explore/companion/${c.id}');
              } else {
                setState(() => dx = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(dx, 0, 0)..rotateZ(dx / 1200),
              transformAlignment: Alignment.center,
              child: CompanionCard(c: top),
            ),
          )),
        ]),
      )),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(iconSize: 32, onPressed: _next, icon: const Icon(Icons.close)),
          const SizedBox(width: 32),
          IconButton.filled(iconSize: 32, onPressed: () { final c = top; _next(); context.push('/explore/companion/${c.id}'); }, icon: const Icon(Icons.favorite)),
        ]),
      ),
    ]);
  }
}
