import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The always-visible "I need help right now" safety affordance.
///
/// Mounted as the first child of the top-level column on onboarding, Home,
/// and the session screen. A contained tonal chip, deliberately not an
/// AppBar (no elevation, no title, not full-bleed) so it stays discoverable
/// without reading as chrome on the calm screens. The crisis screen does not
/// mount this (it would self-route); it has its own explicit return control.
class CrisisHeader extends StatelessWidget {
  const CrisisHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: 'I need help right now',
              child: TextButton.icon(
                onPressed: () => context.go('/crisis'),
                icon: const Icon(Icons.volunteer_activism, size: 20),
                label: const Text('I need help right now'),
                style: TextButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
