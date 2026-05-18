import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';
import '../../ui/widgets/helpline_card.dart';
import '../home/home_state.dart';
import 'session_state.dart';

/// The session ended (Done, or Close for now): clear the conversation and
/// the typed situation, then go Home a fresh start. architecture.md
/// §Privacy: the situation "is gone when the session ends". Without this,
/// Home reopens pre-filled and the user can re-run a session on the same
/// text — the "loop" it looked like.
void _endSession(BuildContext context, WidgetRef ref) {
  ref.read(sessionProvider.notifier).reset();
  ref.read(homeProvider.notifier).reset();
  context.go('/home');
}

/// The 4-step witness session (architecture.md §Session). One reflection
/// and one button at a time. No title, no progress bar, no module name —
/// calm. The always-visible crisis link stays in the header; for a
/// MEDIUM-classified session the helpline card is pinned below the step
/// content so it survives every step change (architecture.md §Safety).
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      body: Column(
        children: [
          const CrisisHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: switch (session.current) {
                StepPending() || StepGenerating() => const _Generating(),
                StepReady(:final text) => _Reflection(
                    text: text,
                    isLast: session.isLastStep,
                  ),
                StepFailed() => const _Failed(),
              },
            ),
          ),
          // Pinned: stays put while the step content above changes. MEDIUM
          // only — NONE/LOW sessions never see it.
          if (session.showHelplineCard)
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

/// Step 0's wait, or the brief gap when the user out-paces pre-generation.
/// A quiet spinner, nothing else (architecture.md §Generation strategy).
class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Reflection extends ConsumerWidget {
  const _Reflection({required this.text, required this.isLast});

  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Steps 0–2 advance the session; step 3's button is Done and
            // returns Home (architecture.md §Session).
            onPressed: isLast
                ? () => _endSession(context, ref)
                : () => ref.read(sessionProvider.notifier).advance(),
            child: Text(isLast ? 'Done' : 'Continue'),
          ),
        ),
      ],
    );
  }
}

/// Shown only after a step failed twice (the first failure was retried
/// silently). Calm, honest, no faked reflection (CLAUDE.md §Session failure
/// behavior). The two button labels are dictated verbatim by that spec.
///
/// ⚠️ NEW COPY for project-lead review: [_message] (the only new string;
/// the button labels "Try again" / "Close for now" are spec-mandated, not
/// authored here). Tone aimed to match the app: short, warm, non-clinical,
/// non-alarming, takes no blame-laden stance.
class _Failed extends ConsumerWidget {
  const _Failed();

  static const _message =
      'Something interrupted this. We can try once more, or stop here for '
      'now — whatever feels right.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => ref.read(sessionProvider.notifier).retry(),
            child: const Text('Try again'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _endSession(context, ref),
          child: Text('Close for now', style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
