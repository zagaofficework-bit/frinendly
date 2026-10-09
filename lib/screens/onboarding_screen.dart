import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/companion.dart';
import '../providers/auth_provider.dart';
import '../providers/companion_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  double rate = 25;
  final bio = TextEditingController();
  final activities = <String>{};
  bool idUploaded = false, selfieDone = false, payoutLinked = false;
  final days = <String>{'Sat', 'Sun'};
  TimeOfDay from = const TimeOfDay(hour: 10, minute: 0), to = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() { bio.dispose(); super.dispose(); }

  Future<void> _pick(bool isFrom) async {
    final t = await showTimePicker(context: context, initialTime: isFrom ? from : to);
    if (t != null) setState(() => isFrom ? from = t : to = t);
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(hostModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Host mode')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Find a Friend'), icon: Icon(Icons.search)),
            ButtonSegment(value: true, label: Text('Become a Friend'), icon: Icon(Icons.favorite_outline)),
          ],
          selected: {host},
          onSelectionChanged: (s) => ref.read(hostModeProvider.notifier).set(s.first),
        )),
        const SizedBox(height: 16),
        if (!host)
          GlassCard(child: Column(children: [
            const Icon(Icons.groups_2_outlined, size: 56),
            const SizedBox(height: 8),
            Text('Looking for company?', style: Theme.of(context).textTheme.titleLarge),
            const Text('Head to Explore to find verified, platonic companions near you.', textAlign: TextAlign.center),
          ]))
        else
          Stepper(
            physics: const NeverScrollableScrollPhysics(),
            currentStep: step,
            onStepContinue: () async {
              if (step < 3) {
                setState(() => step++);
              } else {
                final auth = ref.read(authProvider);
                if (!auth.isAuthenticated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please sign in to register as a companion.'),
                      action: SnackBarAction(label: 'Sign In', onPressed: () => context.push('/auth')),
                    ),
                  );
                  return;
                }

                final newCompanion = Companion(
                  id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                  name: auth.user!.displayName,
                  age: 24,
                  city: 'Mumbai',
                  bio: bio.text.trim().isNotEmpty ? bio.text.trim() : 'Friendly platonic companion ready to explore activities together!',
                  avatarUrl: auth.user!.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
                  hourlyRate: rate,
                  rating: 5.0,
                  reviewCount: 0,
                  distanceKm: 0.5,
                  verified: idUploaded && selfieDone,
                  backgroundChecked: true,
                  languages: const ['English', 'Hindi'],
                  tags: activities.isNotEmpty ? activities.toList() : const ['Coffee', 'Foodie'],
                  activities: activities.isNotEmpty ? activities.toList() : const ['Coffee'],
                  badges: const ['New Host', 'Identity Verified'],
                );

                await registerCompanion(ref, newCompanion, userId: auth.user!.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Congratulations! Your companion profile is now live.')),
                );
                context.go('/explore');
              }
            },
            onStepCancel: () { if (step > 0) setState(() => step--); },
            onStepTapped: (i) => setState(() => step = i),
            steps: [
              Step(isActive: step >= 0, title: const Text('Profile'), content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Text('Hourly rate: \$${rate.round()}'),
                Slider(min: 10, max: 150, divisions: 28, value: rate, onChanged: (v) => setState(() => rate = v)),
                Wrap(spacing: 8, children: [
                  for (final a in kActivities)
                    FilterChip(label: Text(a), selected: activities.contains(a), onSelected: (s) => setState(() => s ? activities.add(a) : activities.remove(a))),
                ]),
              ])),
              Step(isActive: step >= 1, title: const Text('Identity verification'), content: Column(children: [
                ListTile(leading: Icon(idUploaded ? Icons.check_circle : Icons.badge_outlined, color: idUploaded ? Colors.green : null),
                    title: const Text('Upload government ID'), subtitle: const Text('Placeholder: wire to image_picker + Cloud Storage'),
                    onTap: () => setState(() => idUploaded = true)),
                ListTile(leading: Icon(selfieDone ? Icons.check_circle : Icons.face_retouching_natural, color: selfieDone ? Colors.green : null),
                    title: const Text('Take a selfie check'), onTap: () => setState(() => selfieDone = true)),
              ])),
              Step(isActive: step >= 2, title: const Text('Payouts'), content: Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                onPressed: () => setState(() => payoutLinked = true), // Open Stripe Express onboarding URL from your backend
                icon: Icon(payoutLinked ? Icons.check : Icons.account_balance),
                label: Text(payoutLinked ? 'Stripe account linked' : 'Set up Stripe Express payouts')))),
              Step(isActive: step >= 3, title: const Text('Availability'), content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, children: [
                  for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                    FilterChip(label: Text(d), selected: days.contains(d), onSelected: (s) => setState(() => s ? days.add(d) : days.remove(d))),
                ]),
                Row(children: [
                  TextButton(onPressed: () => _pick(true), child: Text('From ${from.format(context)}')),
                  TextButton(onPressed: () => _pick(false), child: Text('To ${to.format(context)}')),
                ]),
              ])),
            ],
          ),
      ]),
    );
  }
}
