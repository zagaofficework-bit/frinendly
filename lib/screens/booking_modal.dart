import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/companion.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/companion_provider.dart';
import '../widgets/widgets.dart';

Future<void> showBookingModal(BuildContext context, Companion c) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BookingModal(companion: c),
  );
}

class BookingModal extends ConsumerStatefulWidget {
  final Companion companion;
  const BookingModal({super.key, required this.companion});
  @override
  ConsumerState<BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends ConsumerState<BookingModal> {
  int step = 0;
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 17, minute: 0);
  int hours = 2;
  late String activity = widget.companion.activities.first;
  final location = TextEditingController();
  bool paying = false;
  static const durations = [1, 2, 3, 4, 6, 8];

  @override
  void dispose() { location.dispose(); super.dispose(); }

  bool get canContinue => step != 2 || location.text.trim().isNotEmpty;

  Future<void> _pay() async {
    final auth = ref.read(authProvider);
    final myCompanion = ref.read(myCompanionProfileProvider).valueOrNull;
    if ((auth.user != null && widget.companion.userId != null && widget.companion.userId == auth.user!.id) ||
        (myCompanion != null && myCompanion.id == widget.companion.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot book your own host profile.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() => paying = true);
    final ok = await ref.read(paymentServiceProvider).checkout(Pricing.total(widget.companion.hourlyRate, hours));
    if (!ok) { if (mounted) setState(() => paying = false); return; }

    final newBooking = Booking(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      companion: widget.companion,
      start: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      hours: hours,
      activity: activity,
      location: location.text.trim().isNotEmpty ? location.text.trim() : 'Public Venue',
      status: BookingStatus.confirmed,
      clientName: auth.user?.displayName ?? 'Guest Member',
      clientAvatar: auth.user?.avatarUrl,
    );

    await ref.read(bookingsProvider.notifier).add(
      newBooking,
      clientId: auth.user?.id,
    );

    // Send automated booking event into the companion's chat thread
    final formattedTime = DateFormat('EEE, MMM d · h:mm a').format(newBooking.start);
    final bookingMsgText = '📅 Booking Confirmed!\nActivity: $activity\nWhen: $formattedTime ($hours hrs)\nLocation: ${newBooking.location}\nEscrow: \$${newBooking.total.toStringAsFixed(2)} secured';

    try {
      await ref.read(chatMessagesProvider(widget.companion.id).notifier).send(
        bookingMsgText,
        payload: {
          'booking_id': newBooking.id,
          'type': 'booking_confirmation',
          'activity': activity,
          'hours': hours,
          'location': newBooking.location,
          'start_time': newBooking.start.toIso8601String(),
        },
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context);

    // Seamlessly transition client into chat room to coordinate meetup
    try {
      context.push('/chat/${widget.companion.id}');
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Booking confirmed & payment secured! Coordinate your meetup in chat.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (step) {
      case 0:
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Host Active Days: ${widget.companion.availabilityDays.join(", ")} (${widget.companion.availabilityHours})',
                    style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.calendar_today), title: Text(DateFormat.yMMMEd().format(date)), trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                if (d != null) setState(() => date = d);
              }),
          ListTile(leading: const Icon(Icons.access_time), title: Text(time.format(context)), trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: time);
                if (t != null) setState(() => time = t);
              }),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Duration'),
          Wrap(spacing: 8, children: [
            for (final d in durations)
              ChoiceChip(label: Text(d == 8 ? 'Full day' : '$d hr'), selected: hours == d, onSelected: (_) => setState(() => hours = d)),
          ]),
          const SizedBox(height: 16),
          const Text('Activity'),
          Wrap(spacing: 8, children: [
            for (final a in kActivities) ChoiceChip(label: Text(a), selected: activity == a, onSelected: (_) => setState(() => activity = a)),
          ]),
        ]);
      case 2:
        return Column(children: [
          // Replace this placeholder with google_maps_flutter + Places autocomplete.
          Container(
            height: 120, width: double.infinity,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map_outlined, size: 36), Text('Google Maps picker (mock)')])),
          ),
          const SizedBox(height: 12),
          TextField(controller: location, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Public meeting place', prefixIcon: Icon(Icons.place_outlined), border: OutlineInputBorder())),
          Wrap(spacing: 8, children: [
            for (final s in ['Blue Tokai Cafe', 'Starbucks', 'City Mall Food Court', 'Central Park', 'Museum Cafe', 'Public Library'])
              ActionChip(
                avatar: const Icon(Icons.place, size: 14),
                label: Text(s),
                onPressed: () => setState(() => location.text = s),
              ),
          ]),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.shield_outlined, size: 14, color: Colors.green),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Always choose well-lit, populated public venues.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ]),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('${DateFormat.MMMEd().format(date)} at ${time.format(context)}'),
            subtitle: Text('$activity @ ${location.text.trim().isNotEmpty ? location.text.trim() : "Public Venue"}'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Escrow Protection: Funds will be held securely until your meetup is completed.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BookingSummary(companion: widget.companion, hours: hours),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Date & time', 'Duration & activity', 'Meeting location', 'Payment summary'];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Book ${widget.companion.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (step + 1) / 4, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 12),
          Text('Step ${step + 1}/4 · ${titles[step]}', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _stepBody(),
          const SizedBox(height: 16),
          Row(
            children: [
              if (step > 0)
                TextButton(
                  onPressed: paying ? null : () => setState(() => step--),
                  child: const Text('Back'),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: step < 3
                    ? FilledButton(
                        onPressed: canContinue ? () => setState(() => step++) : null,
                        child: const Text('Continue'),
                      )
                    : FilledButton.icon(
                        onPressed: paying ? null : _pay,
                        icon: paying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.lock_outline),
                        label: Text(
                          'Secure Escrow (\$${Pricing.total(widget.companion.hourlyRate, hours).toStringAsFixed(0)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
