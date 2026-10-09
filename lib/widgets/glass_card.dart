import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}
