import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase_config.dart';
import '../models/companion.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
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
  final activities = <String>{'Coffee', 'Sightseeing'};
  bool idUploaded = false, selfieDone = false, payoutLinked = false;
  final days = <String>{'Sat', 'Sun'};
  TimeOfDay from = const TimeOfDay(hour: 10, minute: 0), to = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() {
    bio.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final t = await showTimePicker(context: context, initialTime: isFrom ? from : to);
    if (t != null) setState(() => isFrom ? from = t : to = t);
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(hostModeProvider);
    final auth = ref.watch(authProvider);
    final myCompanionAsync = ref.watch(myCompanionProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Mode'),
        actions: [
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ActionChip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(auth.user?.displayName ?? 'Host'),
                onPressed: () => context.push('/account'),
              ),
            ),
        ],
      ),
      body: myCompanionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading host profile: $err')),
        data: (myCompanion) {
          // If already registered as a companion, show the Host Dashboard!
          if (myCompanion != null) {
            return _HostDashboard(companion: myCompanion);
          }

          // Otherwise, show the Become a Host onboarding flow
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Find a Friend'),
                      icon: Icon(Icons.search),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Become a Host'),
                      icon: Icon(Icons.favorite_outline),
                    ),
                  ],
                  selected: {host},
                  onSelectionChanged: (s) => ref.read(hostModeProvider.notifier).set(s.first),
                ),
              ),
              const SizedBox(height: 16),
              if (!host)
                _FindFriendLanding(onSwitchToHost: () => ref.read(hostModeProvider.notifier).set(true))
              else
                _buildHostOnboardingFlow(auth),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHostOnboardingFlow(AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!auth.isAuthenticated)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Guest Mode Active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in now to save your host listing directly to Supabase.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => context.push('/auth'),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: step,
          onStepContinue: () async {
            if (step < 3) {
              setState(() => step++);
            } else {
              if (!auth.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please sign in or create an account to finalize your host profile.'),
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
                bio: bio.text.trim().isNotEmpty
                    ? bio.text.trim()
                    : 'Friendly platonic companion ready to explore coffee spots, art exhibits and city sights!',
                avatarUrl: auth.user!.avatarUrl ??
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
                hourlyRate: rate,
                rating: 5.0,
                reviewCount: 0,
                distanceKm: 0.8,
                verified: idUploaded && selfieDone,
                backgroundChecked: true,
                isActive: true,
                languages: const ['English', 'Hindi'],
                tags: activities.isNotEmpty ? activities.toList() : const ['Coffee', 'Foodie'],
                activities: activities.isNotEmpty ? activities.toList() : const ['Coffee', 'Sightseeing'],
                badges: const ['New Host', 'Identity Verified'],
              );

              final saved = await registerCompanion(ref, newCompanion, userId: auth.user!.id);
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    saved != null
                        ? '🎉 Congratulations! Your companion profile is live!'
                        : 'Host profile created locally.',
                  ),
                ),
              );
            }
          },
          onStepCancel: () {
            if (step > 0) setState(() => step--);
          },
          onStepTapped: (i) => setState(() => step = i),
          steps: [
            Step(
              isActive: step >= 0,
              title: const Text('Listing Details'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: bio,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Host Bio',
                      hintText: 'Share your interests, favorite spots, and platonic activities...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Hourly Rate:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('\$${rate.round()} / hour',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          )),
                    ],
                  ),
                  Slider(
                    min: 10,
                    max: 150,
                    divisions: 28,
                    value: rate,
                    onChanged: (v) => setState(() => rate = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('Select Activities You Offer:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final a in kActivities)
                        FilterChip(
                          label: Text(a),
                          selected: activities.contains(a),
                          onSelected: (s) => setState(() => s ? activities.add(a) : activities.remove(a)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Step(
              isActive: step >= 1,
              title: const Text('Identity & Safety Check'),
              content: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      idUploaded ? Icons.check_circle : Icons.badge_outlined,
                      color: idUploaded ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Government ID Verification'),
                    subtitle: Text(idUploaded ? 'ID Uploaded & Verified' : 'Aadhaar / Passport verification simulation'),
                    trailing: idUploaded ? const Icon(Icons.check, color: Colors.green) : const Text('Tap to Verify'),
                    onTap: () => setState(() => idUploaded = true),
                  ),
                  ListTile(
                    leading: Icon(
                      selfieDone ? Icons.check_circle : Icons.face_retouching_natural,
                      color: selfieDone ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Selfie Liveness Match'),
                    subtitle: Text(selfieDone ? 'Biometric Face Matched' : 'Take a quick 3-second face match check'),
                    trailing: selfieDone ? const Icon(Icons.check, color: Colors.green) : const Text('Tap to Match'),
                    onTap: () => setState(() => selfieDone = true),
                  ),
                ],
              ),
            ),
            Step(
              isActive: step >= 2,
              title: const Text('Escrow Payout Setup'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Earnings are held securely in escrow and released directly to your account upon meetup completion.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => payoutLinked = true),
                    icon: Icon(payoutLinked ? Icons.check_circle : Icons.account_balance),
                    label: Text(payoutLinked ? 'Stripe Express Connected' : 'Connect Stripe Express Payouts'),
                  ),
                ],
              ),
            ),
            Step(
              isActive: step >= 3,
              title: const Text('Availability & Hours'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Days Available:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                        FilterChip(
                          label: Text(d),
                          selected: days.contains(d),
                          onSelected: (s) => setState(() => s ? days.add(d) : days.remove(d)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.schedule, size: 16),
                        onPressed: () => _pick(true),
                        label: Text('From: ${from.format(context)}'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.schedule, size: 16),
                        onPressed: () => _pick(false),
                        label: Text('To: ${to.format(context)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FindFriendLanding extends StatelessWidget {
  final VoidCallback onSwitchToHost;
  const _FindFriendLanding({required this.onSwitchToHost});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          child: Column(
            children: [
              const Icon(Icons.groups_2_outlined, size: 56, color: Colors.teal),
              const SizedBox(height: 12),
              Text('Looking for Platonic Company?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Find verified companions for coffee chats, workout sessions, local sightseeing, and board games.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.explore),
                label: const Text('Explore Companions Near You'),
                onPressed: () => context.go('/explore'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_outlined, size: 36, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Want to earn as a Companion?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Set your hourly rate (\$20-\$50/hr) and get booked for shared activities.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onSwitchToHost,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HostDashboard extends ConsumerWidget {
  final Companion companion;
  const _HostDashboard({required this.companion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Host Status Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(companion.avatarUrl),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              companion.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            if (companion.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${companion.city} · \$${companion.hourlyRate.toStringAsFixed(0)}/hr',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              '${companion.rating.toStringAsFixed(1)} (${companion.reviewCount} reviews)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Availability Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: companion.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        companion.isActive ? 'Accepting Bookings' : 'Listing Paused',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: companion.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: companion.isActive,
                    onChanged: (val) async {
                      await updateCompanionAvailability(ref, companion.id, val);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'Listing is now Online!' : 'Listing paused.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Earnings and Escrow Metric Card
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.teal.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.teal),
                          SizedBox(width: 6),
                          Text('Host Wallet', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 4),
                      Text('Escrow Protected', style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.orange.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.military_tech_outlined, size: 18, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Trust Tier', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verified Host',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Text('100% ID Checked', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Quick Actions
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.preview_outlined, color: Colors.blue),
                title: const Text('View Public Profile'),
                subtitle: const Text('See how your listing appears in Explore'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/explore/companion/${companion.id}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.purple),
                title: const Text('Edit Hourly Rate'),
                subtitle: Text('Current: \$${companion.hourlyRate.toStringAsFixed(0)}/hr'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditRateDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.local_activity_outlined, color: Colors.teal),
                title: const Text('Offered Activities'),
                subtitle: Text(companion.activities.join(', ')),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Host Trust & Safety Notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Strict Platonic Policy: All bookings are protected by 24/7 SOS dispatch and escrow guarantees.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditRateDialog(BuildContext context, WidgetRef ref, Companion companion) {
    double tempRate = companion.hourlyRate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Hourly Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\$${tempRate.round()} / hr',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
              Slider(
                min: 10,
                max: 150,
                divisions: 28,
                value: tempRate,
                onChanged: (v) => setState(() => tempRate = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final client = SupabaseConfig.client;
                if (client != null) {
                  try {
                    await client.from('companions').update({'hourly_rate': tempRate}).eq('id', companion.id);
                    ref.invalidate(myCompanionProfileProvider);
                    ref.invalidate(allCompanionsProvider);
                  } catch (_) {}
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
