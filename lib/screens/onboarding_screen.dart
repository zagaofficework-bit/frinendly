import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/companion.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/companion_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/widgets.dart';

const kAvailableLanguages = [
  'English',
  'Hindi',
  'Marathi',
  'Gujarati',
  'Bengali',
  'Punjabi',
  'Spanish',
  'French',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  double rate = 25;
  final bio = TextEditingController();
  final cityController = TextEditingController(text: 'Mumbai');
  final ageController = TextEditingController(text: '24');
  final avatarController = TextEditingController();
  final activities = <String>{'Coffee', 'Sightseeing'};
  final languages = <String>{'English', 'Hindi'};
  bool idUploaded = false, selfieDone = false, payoutLinked = false;
  final days = <String>{'Sat', 'Sun'};
  TimeOfDay from = const TimeOfDay(hour: 10, minute: 0), to = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() {
    bio.dispose();
    cityController.dispose();
    ageController.dispose();
    avatarController.dispose();
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
                age: int.tryParse(ageController.text.trim()) ?? 21,
                city: cityController.text.trim().isNotEmpty ? cityController.text.trim() : 'Mumbai',
                bio: bio.text.trim().isNotEmpty
                    ? bio.text.trim()
                    : 'Friendly platonic companion ready to explore coffee spots, art exhibits and city sights!',
                avatarUrl: avatarController.text.trim().isNotEmpty
                    ? avatarController.text.trim()
                    : (auth.user!.avatarUrl?.isNotEmpty == true
                        ? auth.user!.avatarUrl!
                        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80'),
                hourlyRate: rate,
                rating: 5.0,
                reviewCount: 0,
                distanceKm: 0.8,
                verified: idUploaded && selfieDone,
                backgroundChecked: true,
                isActive: true,
                languages: languages.isNotEmpty ? languages.toList() : const ['English', 'Hindi'],
                tags: activities.isNotEmpty ? activities.toList() : const ['Coffee', 'Foodie'],
                activities: activities.isNotEmpty ? activities.toList() : const ['Coffee', 'Sightseeing'],
                badges: const ['New Host', 'Identity Verified'],
                availabilityDays: days.isNotEmpty ? days.toList() : const ['Sat', 'Sun'],
                availabilityHours: '${from.format(context)} - ${to.format(context)}',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            hintText: 'e.g. Mumbai, Pune',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            hintText: '18+',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  const Text('Languages You Speak:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final l in kAvailableLanguages)
                        FilterChip(
                          label: Text(l),
                          selected: languages.contains(l),
                          onSelected: (s) => setState(() => s ? languages.add(l) : languages.remove(l)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: avatarController,
                    decoration: const InputDecoration(
                      labelText: 'Profile Picture URL (Optional)',
                      hintText: 'https://images.unsplash.com/...',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
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
                    backgroundImage: companion.avatarUrl.isNotEmpty
                        ? NetworkImage(companion.avatarUrl)
                        : null,
                    onBackgroundImageError: companion.avatarUrl.isNotEmpty
                        ? (_, __) {}
                        : null,
                    child: companion.avatarUrl.isEmpty
                        ? Text(
                            companion.name.isNotEmpty
                                ? companion.name[0].toUpperCase()
                                : 'H',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          )
                        : null,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Escrow Protected', style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
                          InkWell(
                            onTap: () => _showPayoutDialog(context, ref, balance),
                            child: const Text('Withdraw →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ),
                        ],
                      ),
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

        // Incoming Client Bookings Card
        _buildIncomingBookingsCard(context, ref, companion),

        const SizedBox(height: 16),

        // Profile Completeness Card
        _buildCompletenessCard(context, companion),

        const SizedBox(height: 16),

        // Quick Actions & Profile Editor Card
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
                leading: const Icon(Icons.edit_note_rounded, color: Colors.deepPurple),
                title: const Text('Edit Bio & Location'),
                subtitle: Text(
                  '${companion.age} yrs old • ${companion.bio.isEmpty ? 'No bio set' : (companion.bio.length > 35 ? '${companion.bio.substring(0, 35)}...' : companion.bio)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditProfileDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.local_activity_outlined, color: Colors.teal),
                title: const Text('Offered Activities'),
                subtitle: Text(
                  companion.activities.isEmpty
                      ? 'Tap to select activities you offer'
                      : companion.activities.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditActivitiesDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.translate_rounded, color: Colors.indigo),
                title: const Text('Languages Spoken'),
                subtitle: Text(
                  companion.languages.isEmpty
                      ? 'English, Hindi'
                      : companion.languages.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditLanguagesDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule_rounded, color: Colors.blue),
                title: const Text('Operating Hours & Days'),
                subtitle: Text(
                  '${companion.availabilityDays.join(", ")} · ${companion.availabilityHours}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditAvailabilityDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.pink),
                title: const Text('Manage Gallery Photos'),
                subtitle: Text(
                  companion.gallery.isEmpty
                      ? 'Add photos to enhance your profile'
                      : '${companion.gallery.length} photos uploaded',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showManageGalleryDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, color: Colors.amber),
                title: const Text('Client Reviews'),
                subtitle: Text(
                  '${companion.rating.toStringAsFixed(1)} ★ (${companion.reviewCount} reviews received)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHostReviewsDialog(context, ref, companion),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.purple),
                title: const Text('Edit Hourly Rate'),
                subtitle: Text('Current: \$${companion.hourlyRate.toStringAsFixed(0)}/hr'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditRateDialog(context, ref, companion),
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

  Widget _buildCompletenessCard(BuildContext context, Companion companion) {
    int score = 0;
    final List<String> suggestions = [];
    if (companion.bio.trim().length >= 15) {
      score += 20;
    } else {
      suggestions.add('Add bio');
    }

    if (companion.activities.isNotEmpty) {
      score += 20;
    } else {
      suggestions.add('Pick activities');
    }

    if (companion.languages.isNotEmpty) {
      score += 20;
    } else {
      suggestions.add('Add languages');
    }

    if (companion.avatarUrl.trim().isNotEmpty) {
      score += 20;
    } else {
      suggestions.add('Profile photo');
    }

    if (companion.gallery.isNotEmpty) {
      score += 20;
    } else {
      suggestions.add('Add gallery photos');
    }

    final isAllStar = score == 100;

    return Card(
      elevation: 0,
      color: isAllStar
          ? Colors.green.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAllStar
              ? Colors.green.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isAllStar ? Icons.verified_rounded : Icons.pie_chart_rounded,
                      size: 20,
                      color: isAllStar ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAllStar ? 'All-Star Host Profile' : 'Profile Completeness',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '$score%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isAllStar ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100.0,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: isAllStar ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            if (isAllStar)
              const Text(
                '✨ Your host profile is 100% complete! Maximum visibility in Explore.',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
              )
            else
              Text(
                'Suggestions: ${suggestions.join(" • ")} to reach 100% and get more bookings.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Companion companion) {
    final cityCtl = TextEditingController(text: companion.city);
    final ageCtl = TextEditingController(text: companion.age.toString());
    final bioCtl = TextEditingController(text: companion.bio);
    final avatarCtl = TextEditingController(text: companion.avatarUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Bio & Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtl,
                      decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 75,
                    child: TextField(
                      controller: ageCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'About Me / Bio',
                  hintText: 'Share your background, interests, and hobbies...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: avatarCtl,
                decoration: const InputDecoration(
                  labelText: 'Avatar Image URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final updated = companion.copyWith(
                city: cityCtl.text.trim().isNotEmpty ? cityCtl.text.trim() : companion.city,
                age: int.tryParse(ageCtl.text.trim()) ?? companion.age,
                bio: bioCtl.text.trim(),
                avatarUrl: avatarCtl.text.trim().isNotEmpty ? avatarCtl.text.trim() : companion.avatarUrl,
              );
              final ok = await updateCompanionProfile(ref, updated);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Profile details updated successfully!' : 'Failed to update profile details.'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditActivitiesDialog(BuildContext context, WidgetRef ref, Companion companion) {
    final selected = Set<String>.from(companion.activities);
    final customCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Offered Activities'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the platonic activities you are happy to accompany guests to:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final a in kActivities)
                      FilterChip(
                        label: Text(a),
                        selected: selected.contains(a),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selected.add(a);
                            } else {
                              selected.remove(a);
                            }
                          });
                        },
                      ),
                    for (final custom in selected.where((item) => !kActivities.contains(item)))
                      FilterChip(
                        label: Text(custom),
                        selected: true,
                        onSelected: (_) => setState(() => selected.remove(custom)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtl,
                        decoration: const InputDecoration(
                          labelText: 'Add Custom Activity',
                          hintText: 'e.g. Photography Walk',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final text = customCtl.text.trim();
                        if (text.isNotEmpty) {
                          setState(() => selected.add(text));
                          customCtl.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final list = selected.toList();
                final updated = companion.copyWith(
                  activities: list,
                  tags: list,
                );
                final ok = await updateCompanionProfile(ref, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Activities updated successfully!' : 'Failed to update activities.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLanguagesDialog(BuildContext context, WidgetRef ref, Companion companion) {
    final selected = Set<String>.from(companion.languages);
    final customCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Languages Spoken'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the languages you can comfortably converse in:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final l in kAvailableLanguages)
                      FilterChip(
                        label: Text(l),
                        selected: selected.contains(l),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selected.add(l);
                            } else {
                              selected.remove(l);
                            }
                          });
                        },
                      ),
                    for (final custom in selected.where((item) => !kAvailableLanguages.contains(item)))
                      FilterChip(
                        label: Text(custom),
                        selected: true,
                        onSelected: (_) => setState(() => selected.remove(custom)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtl,
                        decoration: const InputDecoration(
                          labelText: 'Other Language',
                          hintText: 'e.g. German, Tamil',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final text = customCtl.text.trim();
                        if (text.isNotEmpty) {
                          setState(() => selected.add(text));
                          customCtl.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final updated = companion.copyWith(languages: selected.toList());
                final ok = await updateCompanionProfile(ref, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Languages updated successfully!' : 'Failed to update languages.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageGalleryDialog(BuildContext context, WidgetRef ref, Companion companion) {
    final gallery = List<String>.from(companion.gallery);
    final urlCtl = TextEditingController();

    const presets = [
      MapEntry('Coffee Cafe', 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=600&q=80'),
      MapEntry('City Tour', 'https://images.unsplash.com/photo-1477959858617-67f30bc75b82?auto=format&fit=crop&w=600&q=80'),
      MapEntry('Art & Museum', 'https://images.unsplash.com/photo-1518998053901-5348d3961a04?auto=format&fit=crop&w=600&q=80'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Manage Photo Gallery'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos show guests what it’s like hanging out with you in friendly spaces.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (gallery.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('No gallery photos yet. Add one below!'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < gallery.length; i++)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  gallery[i],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image, size: 28),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => gallery.removeAt(i)),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text('Add Photo by URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: urlCtl,
                          decoration: const InputDecoration(
                            hintText: 'https://images.unsplash.com/...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add_photo_alternate),
                        onPressed: () {
                          final text = urlCtl.text.trim();
                          if (text.isNotEmpty) {
                            setState(() => gallery.add(text));
                            urlCtl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Or add curated sample presets:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final p in presets)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text(p.key, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            if (!gallery.contains(p.value)) {
                              setState(() => gallery.add(p.value));
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final updated = companion.copyWith(gallery: gallery);
                final ok = await updateCompanionProfile(ref, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Gallery photos updated!' : 'Failed to update gallery photos.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
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
                final ok = await updateCompanionHourlyRate(ref, companion.id, tempRate);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Hourly rate updated to \$${tempRate.round()}/hr!'
                          : 'Failed to update hourly rate.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingBookingsCard(BuildContext context, WidgetRef ref, Companion companion) {
    final bookings = ref.watch(bookingsProvider);
    final hostBookings = bookings.where((b) {
      return b.companion.id == companion.id ||
          (companion.userId != null && b.companion.userId == companion.userId);
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.teal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Incoming Client Bookings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${hostBookings.length} total',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hostBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No client bookings yet',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'When guests book your profile from Explore, requests appear here with escrow details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final b in hostBookings) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b.clientName != null && b.clientName!.isNotEmpty
                                      ? '${b.clientName} · ${b.activity}'
                                      : 'Client Meetup · ${b.activity}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (b.status == BookingStatus.completed
                                          ? Colors.blue
                                          : (b.status == BookingStatus.confirmed
                                              ? Colors.green
                                              : Colors.orange))
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  b.status.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: b.status == BookingStatus.completed
                                        ? Colors.blue
                                        : (b.status == BookingStatus.confirmed ? Colors.green : Colors.orange),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat.MMMEd().add_jm().format(b.start)} · ${b.location}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${(b.subtotal * 0.85).toStringAsFixed(2)} net payout (Escrow secured)',
                            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                                label: const Text('Chat', style: TextStyle(fontSize: 12)),
                                onPressed: () => context.push('/chat/${companion.id}'),
                              ),
                              if (b.isUpcoming) ...[
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Complete', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    await ref.read(bookingsProvider.notifier).complete(b.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Meetup marked complete! Escrow of \$${(b.subtotal * 0.85).toStringAsFixed(2)} released to wallet.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showPayoutDialog(BuildContext context, WidgetRef ref, double balance) {
    final upiCtrl = TextEditingController(text: 'host@okhdfcbank');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Host Payout & Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance: \$${balance.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
            const SizedBox(height: 8),
            const Text(
              'Escrow earnings are deposited via Stripe Express or direct UPI transfer within 24 hours.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI ID / Account IBAN',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: balance > 0
                ? () {
                    ref.read(walletProvider.notifier).withdraw();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payout request of \$${balance.toStringAsFixed(2)} submitted successfully!')),
                    );
                  }
                : null,
            child: const Text('Confirm Payout'),
          ),
        ],
      ),
    );
  }

  void _showEditAvailabilityDialog(BuildContext context, WidgetRef ref, Companion companion) {
    final days = Set<String>.from(companion.availabilityDays);
    final hoursCtrl = TextEditingController(text: companion.availabilityHours);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Operating Hours & Days'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Days:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                      FilterChip(
                        label: Text(d),
                        selected: days.contains(d),
                        onSelected: (val) => setState(() => val ? days.add(d) : days.remove(d)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Operating Hours Window:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: hoursCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    hintText: 'e.g. 10:00 AM - 08:00 PM',
                    prefixIcon: Icon(Icons.access_time),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final updated = companion.copyWith(
                  availabilityDays: days.toList(),
                  availabilityHours: hoursCtrl.text.trim().isNotEmpty ? hoursCtrl.text.trim() : companion.availabilityHours,
                );
                final ok = await updateCompanionProfile(ref, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Availability hours saved!' : 'Failed to save availability.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHostReviewsDialog(BuildContext context, WidgetRef ref, Companion companion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Client Reviews (${companion.reviewCount})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, _) {
              final asyncReviews = ref.watch(reviewsProvider(companion.id));
              return asyncReviews.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No reviews received yet.')),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (_, i) {
                      final r = reviews[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(r.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(r.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Text(r.text, style: const TextStyle(fontSize: 12)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
