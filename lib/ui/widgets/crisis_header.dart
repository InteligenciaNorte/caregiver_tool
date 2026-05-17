import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The always-visible "I need help right now" safety link.
///
/// Mounted as the first child of the top-level column on onboarding, Home,
/// and the session screen. Deliberately not an AppBar: no fill, no
/// elevation, no title — it must not read as chrome on the calm screens.
/// The crisis screen does not mount this (it would self-route); it has its
/// own explicit return control instead.
class CrisisHeader extends StatelessWidget {
  const CrisisHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: TextButton(
                onPressed: () => context.go('/crisis'),
                child: const Text('I need help right now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
