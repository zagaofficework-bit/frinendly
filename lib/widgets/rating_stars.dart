import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating, size;
  final bool showValue;
  const RatingStars({super.key, required this.rating, this.size = 16, this.showValue = true});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
              size: size, color: Colors.amber.shade600),
        if (showValue) Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w600))),
      ]);
}

class RatingBadge extends StatelessWidget {
  final double rating;
  final int count;
  const RatingBadge({super.key, required this.rating, required this.count});
  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
        label: Text('${rating.toStringAsFixed(1)} ($count)'),
      );
}
