import 'package:flutter/material.dart';

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
        InkWell(onTap: () => setState(() => _visible = false), child: Icon(Icons.close, size: 18, color: cs.onTertiaryContainer)),
      ]),
    );
  }
}

Future<void> showSosSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.my_location, color: Colors.red),
            title: const Text('Share live GPS with emergency contacts'),
            onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live location shared (mock).'))); },
          ),
          ListTile(
            leading: const Icon(Icons.call, color: Colors.red),
            title: const Text('Call local emergency number'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report this profile'),
            onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Our team will review it.'))); },
          ),
        ]),
      ),
    );
