import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/companion_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/safety_banner.dart';

enum BookingTab { upcoming, past, canceled }


class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<AccountScreen> {
  BookingTab tab = BookingTab.upcoming;
  bool pushBookings = true, pushMessages = true;

  Future<void> _addContact() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add emergency contact'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Name • phone')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add'))],
      ),
    );
    c.dispose();
    if (v != null && v.isNotEmpty) ref.read(contactsProvider.notifier).add(v);
  }

  Color _statusColor(BookingStatus s) => switch (s) {
        BookingStatus.confirmed => Colors.green,
        BookingStatus.completed => Colors.blue,
        BookingStatus.canceled => Colors.red,
        BookingStatus.pending => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bookings = ref.watch(bookingsProvider);
    final wallet = ref.watch(walletProvider);
    final contacts = ref.watch(contactsProvider);
    final mode = ref.watch(themeModeProvider);
    final shown = bookings.where((b) => switch (tab) {
          BookingTab.upcoming => b.isUpcoming,
          BookingTab.past => !b.isUpcoming && b.status != BookingStatus.canceled,
          BookingTab.canceled => b.status == BookingStatus.canceled,
        }).toList();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).signOut();
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(bookingsProvider.notifier).refresh(),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (authState.isAuthenticated)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      authState.user!.displayName.isNotEmpty ? authState.user!.displayName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(authState.user!.displayName, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(authState.user!.email, style: text.bodySmall),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          authState.user!.isCompanion ? 'Verified Companion' : 'Verified Member',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.account_circle_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Welcome to Friendify', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Text('Sign in to sync your bookings, chats, and emergency contacts.', style: TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Sign In or Register'),
                    ),
                  ),
                ]),
              ),
            ),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Wallet balance'),
                Text('\$${wallet.toStringAsFixed(2)}', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              ])),
              FilledButton(
                onPressed: wallet > 0 ? () { ref.read(walletProvider.notifier).withdraw(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout initiated via Stripe (mock).'))); } : null,
                child: const Text('Withdraw'),
              ),
            ])),
          ),
          const SizedBox(height: 16),
          Text('Bookings', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<BookingTab>(
            segments: const [
              ButtonSegment(value: BookingTab.upcoming, label: Text('Upcoming')),
              ButtonSegment(value: BookingTab.past, label: Text('Past')),
              ButtonSegment(value: BookingTab.canceled, label: Text('Canceled')),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          if (shown.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nothing here yet'))),
          for (final b in shown) Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(b.companion.avatarUrl),
                        onBackgroundImageError: (_, __) {},
                        child: Text(b.companion.name.isNotEmpty ? b.companion.name[0] : 'C'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${b.activity} with ${b.companion.name}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(b.status).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    b.status.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(b.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat.MMMEd().add_jm().format(b.start)} · ${b.hours}h',
                              style: text.bodySmall,
                            ),
                            Text(
                              '${b.location} · \$${b.total.toStringAsFixed(2)}',
                              style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (b.isUpcoming) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancel Booking'),
                                content: Text('Are you sure you want to cancel the booking with ${b.companion.name}? Full refund will be issued.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Booking')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(bookingsProvider.notifier).cancel(b.id);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Complete Meetup'),
                          onPressed: () async {
                            await ref.read(bookingsProvider.notifier).complete(b.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Meetup concluded! Escrow payout of \$${(b.subtotal * 0.85).toStringAsFixed(2)} released to host wallet.'),
                                ),
                              );
                              _showPostMeetupReviewDialog(b);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  if (b.status == BookingStatus.completed) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          key: Key('rate_review_${b.id}'),
                          icon: const Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
                          label: const Text('Rate & Review'),
                          onPressed: () => _showPostMeetupReviewDialog(b),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        const Divider(height: 32),
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.teal),
            const SizedBox(width: 8),
            Text('Trust & Safety Center', style: text.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text('100% Platonic Verified', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every companion undergoes identity verification and community screening. Meetups are strictly platonic and public-place only.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.sos, color: Colors.red, size: 16),
                      label: const Text('Test SOS Trigger'),
                      onPressed: () => showSosSheet(context, ref),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.rule_outlined, size: 16),
                      label: const Text('Code of Conduct'),
                      onPressed: _showCodeOfConductDialog,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.lock_clock_outlined, size: 16),
                      label: const Text('Escrow Guarantee'),
                      onPressed: _showEscrowInfoDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        Row(children: [
          Text('Emergency contacts', style: text.titleMedium),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add), onPressed: _addContact),
        ]),
        for (final c in contacts) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.contact_emergency_outlined),
          title: Text(c),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ref.read(contactsProvider.notifier).remove(c)),
        ),
        const Divider(height: 32),
        Text('Settings', style: text.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Booking updates'), value: pushBookings, onChanged: (v) => setState(() => pushBookings = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Message notifications'), value: pushMessages, onChanged: (v) => setState(() => pushMessages = v)),
      ])),
    );
  }

  void _showCodeOfConductDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rule, color: Colors.blue),
            SizedBox(width: 8),
            Text('Platonic Code of Conduct'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Purely Platonic: Friendify is strictly for non-romantic friendship and companionship.'),
            SizedBox(height: 8),
            Text('2. Public Places Only: Initial and ongoing meetups must occur in verified public venues.'),
            SizedBox(height: 8),
            Text('3. Mutual Respect: Zero tolerance for harassment, offensive behavior, or non-consensual contact.'),
            SizedBox(height: 8),
            Text('4. Platform Escrow: All transactions must stay on Friendify for fraud protection.'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  void _showEscrowInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.green),
            SizedBox(width: 8),
            Text('Escrow Protection Policy'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Funds Authorized On Booking: Your payment is held securely in escrow and not charged until meetup.'),
            SizedBox(height: 8),
            Text('• Automatic Payout Release: After mutual check-in and meetup conclusion, 85% is released to the companion.'),
            SizedBox(height: 8),
            Text('• 100% Refund on Cancellations: If either party cancels before check-in, full refund is credited back immediately.'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got It')),
        ],
      ),
    );
  }

  Future<void> _showPostMeetupReviewDialog(Booking b) => showDialog<void>(
        context: context,
        builder: (_) => _MeetupReviewDialog(booking: b),
      );
}

class _MeetupReviewDialog extends ConsumerStatefulWidget {
  final Booking booking;
  const _MeetupReviewDialog({required this.booking});

  @override
  ConsumerState<_MeetupReviewDialog> createState() => _MeetupReviewDialogState();
}

class _MeetupReviewDialogState extends ConsumerState<_MeetupReviewDialog> {
  final _commentController = TextEditingController();
  double _selectedRating = 5.0;
  double _selectedTip = 0.0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text('Review ${b.companion.name}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How was your platonic meetup experience?'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starVal = index + 1.0;
                return IconButton(
                  icon: Icon(
                    starVal <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _selectedRating = starVal),
                );
              }),
            ),
            Center(
              child: Text(
                '${_selectedRating.toInt()} / 5 Stars',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('meetup_review_text_field'),
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Share feedback (punctuality, great conversation, activities...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Optional Host Tip:'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [0.0, 5.0, 10.0, 20.0].map((tip) {
                final isSelected = _selectedTip == tip;
                return ChoiceChip(
                  label: Text(tip == 0.0 ? 'No tip' : '\$${tip.toInt()}'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedTip = tip),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          key: const Key('submit_meetup_review_button'),
          onPressed: () async {
            final auth = ref.read(authProvider);
            final review = Review(
              author: auth.user?.displayName ?? 'Verified Member',
              rating: _selectedRating,
              text: _commentController.text.trim().isEmpty
                  ? 'Great meetup experience! Highly recommended.'
                  : _commentController.text.trim(),
              date: DateTime.now(),
            );

            await submitReview(ref, b.companion.id, review);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Thank you! Your ${_selectedRating.toInt()}-star review for ${b.companion.name} was published.${_selectedTip > 0 ? ' \$${_selectedTip.toInt()} tip added!' : ''}',
                  ),
                ),
              );
            }
          },
          child: const Text('Submit Review'),
        ),
      ],
    );
  }

}

