import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/theme_provider.dart';

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
                            }
                          },
                        ),
                      ],
                    ),
                  ],
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
}
