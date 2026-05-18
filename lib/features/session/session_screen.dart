import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';
import '../../ui/widgets/helpline_card.dart';
import 'session_state.dart';

/// Placeholder for the 4-step witness session.
///
/// The real flow — MockGemmaClient/GemmaClient, the step state machine,
/// background generation, ChatML assembly — is the next (behavioral) build
/// phase and is intentionally not implemented here. Only the structural
/// shell exists: the always-visible crisis link, a calm body, and — for a
/// MEDIUM-classified session — the helpline card pinned below the step
/// content so it stays on every step (architecture.md §Safety). No title,
/// no progress bar, no module name ("Calm").
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showHelpline = ref.watch(sessionProvider).showHelplineCard;
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
          // Pinned: stays put while step content above changes. MEDIUM
          // only — NONE/LOW sessions never see it.
          if (showHelpline)
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: HelplineCard(),
              ),
            ),
        ],
      ),
    );
  }
}
