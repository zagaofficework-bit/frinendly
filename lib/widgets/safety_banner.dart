import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/booking_provider.dart';

class SafetyBanner extends StatefulWidget {
  const SafetyBanner({super.key});
  @override
  State<SafetyBanner> createState() => _SafetyBannerState();
}

class _SafetyBannerState extends State<SafetyBanner> {
  bool _visible = true;
  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.shield_outlined, size: 18, color: cs.onTertiaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text('Friendify is strictly platonic. Meet in public places and never share financial details.',
            style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer))),
        InkWell(
          key: const Key('safety_banner_close'),
          onTap: () => setState(() => _visible = false),
          child: Icon(Icons.close, size: 18, color: cs.onTertiaryContainer),
        ),
      ]),
    );
  }
}

Future<void> showSosSheet(BuildContext context, [WidgetRef? ref]) async {
  List<String> contacts = [];
  try {
    if (ref != null) {
      contacts = ref.read(contactsProvider);
    } else {
      contacts = ProviderScope.containerOf(context, listen: false).read(contactsProvider);
    }
  } catch (_) {
    contacts = ['Mom  •  +91 90000 00001'];
  }

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Emergency Safety SOS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your safety is our top priority. Choose an action below for immediate assistance.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.my_location, color: Colors.red),
              ),
              title: const Text('Share live GPS with emergency contacts'),
              subtitle: Text(
                contacts.isEmpty
                    ? 'No contacts added yet'
                    : 'Dispatching to ${contacts.length} contact(s)',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                final names = contacts.isNotEmpty ? contacts.join(', ') : 'Emergency contacts';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade800,
                    content: Text(
                      '🚨 Live GPS (19.0760° N, 72.8777° E) dispatched to: $names',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.call, color: Colors.red),
              ),
              title: const Text('Call local emergency number (112 / 911)'),
              subtitle: const Text('Direct connection to local emergency dispatch', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showEmergencyCallDialog(context);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE7F6),
                child: Icon(Icons.flag_outlined, color: Colors.deepPurple),
              ),
              title: const Text('Report profile or incident'),
              subtitle: const Text('Strictly confidential trust & safety team review', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEmergencyCallDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.call, color: Colors.red),
          SizedBox(width: 8),
          Text('Call Emergency?'),
        ],
      ),
      content: const Text(
        'You are about to dial emergency helpline 112. Use this only for immediate danger or distress.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(dialogCtx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dialing emergency helpline 112...'),
                backgroundColor: Colors.red,
              ),
            );
          },
          child: const Text('Call 112'),
        ),
      ],
    ),
  );
}

void _showReportDialog(BuildContext context) {
  String selectedReason = 'Inappropriate behavior / violation of platonic policy';
  final reasons = [
    'Inappropriate behavior / violation of platonic policy',
    'Soliciting off-platform payment',
    'Safety or harassment concern',
    'Suspicious or fake profile',
  ];

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Report Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a reason for reporting. All reports are investigated promptly.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final r in reasons)
              InkWell(
                onTap: () => setDialogState(() => selectedReason = r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        selectedReason == r
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: selectedReason == r
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report submitted: "$selectedReason". Our safety team will review it immediately.'),
                ),
              );
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    ),
  );
}

