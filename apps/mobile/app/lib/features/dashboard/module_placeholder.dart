import 'package:flutter/material.dart';
import 'package:najath_core/najath_core.dart';

/// Stands in for a module whose feature package has not been built out yet.
///
/// Kept as a real route so the access matrix, the router guard and the nav
/// shell can all be exercised end to end before every screen exists.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({required this.title, this.message, super.key});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 44,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'Not built yet',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
