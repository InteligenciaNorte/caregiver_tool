import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';

/// Placeholder for the 4-step witness session.
///
/// The real flow — MockGemmaClient/GemmaClient, the step state machine,
/// background generation, ChatML assembly — is the next (behavioral) build
/// phase and is intentionally not implemented here. Only the structural
/// shell exists: the always-visible crisis link and a calm body. No title,
/// no progress bar, no module name (architecture.md: "Calm").
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          const CrisisHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'The session flow is not built yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
