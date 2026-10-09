import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/companion.dart';

class BookingSummary extends StatelessWidget {
  final Companion companion;
  final int hours;
  const BookingSummary({super.key, required this.companion, required this.hours});
  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 18 : null)),
        ]));
  @override
  Widget build(BuildContext context) {
    final sub = companion.hourlyRate * hours;
    return Column(children: [
      _row('Hourly rate', '\$${companion.hourlyRate.toStringAsFixed(2)}/hr'),
      _row('Duration', '$hours hr${hours > 1 ? 's' : ''}'),
      _row('Subtotal', '\$${sub.toStringAsFixed(2)}'),
      _row('Platform fee (${(Pricing.feeRate * 100).toInt()}%)', '\$${Pricing.fee(sub).toStringAsFixed(2)}'),
      const Divider(),
      _row('Estimated total', '\$${Pricing.total(companion.hourlyRate, hours).toStringAsFixed(2)}', bold: true),
    ]);
  }
}
