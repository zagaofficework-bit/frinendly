import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/companion.dart';
import '../providers/booking_provider.dart';
import '../widgets/widgets.dart';

Future<void> showBookingModal(BuildContext context, Companion c) => showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => BookingModal(companion: c),
    );

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
    setState(() => paying = true);
    final ok = await ref.read(paymentServiceProvider).checkout(Pricing.total(widget.companion.hourlyRate, hours));
    if (!ok) { if (mounted) setState(() => paying = false); return; }
    await ref.read(bookingsProvider.notifier).add(Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(), companion: widget.companion,
      start: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      hours: hours, activity: activity, location: location.text.trim()));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Booking confirmed! Check your Account tab.')));
  }

  Widget _stepBody() {
    switch (step) {
      case 0:
        return Column(children: [
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
        return Column(children: [
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: Text('${DateFormat.MMMEd().format(date)} at ${time.format(context)}'), subtitle: Text('$activity @ ${location.text}')),
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
          Row(children: [
            if (step > 0) TextButton(onPressed: paying ? null : () => setState(() => step--), child: const Text('Back')),
            const Spacer(),
            if (step < 3)
              FilledButton(onPressed: canContinue ? () => setState(() => step++) : null, child: const Text('Continue'))
            else
              FilledButton.icon(
                onPressed: paying ? null : _pay,
                icon: paying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline),
                label: const Text('Pay with Stripe'),
              ),
          ]),
        ]),
      ),
    );
  }
}
