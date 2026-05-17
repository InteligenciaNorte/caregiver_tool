import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';
import 'onboarding_state.dart';

// Lead-owned copy. Draft examples lifted verbatim from architecture.md; they
// are explicitly iterable later — do not reword without asking.
const _heading = 'Other caregivers come here with things like this';

const _examples = [
  'We had to call the ambulance for dad today. When they rolled his stretcher out the door I felt this massive weight lift off my chest. I handed my sick father over to strangers and just felt so relieved he was out of my house. What is wrong with me.',
  "Yelled at mom again. She just wanted her sweater. I'm a monster.",
  "Mom had a really bad night and for about an hour I genuinely wished she would die in her sleep. I don't recognize myself.",
  'She hit me today. I froze and then cried in the bathroom for twenty minutes.',
  "Couldn't make myself go in to change him this morning. Just stood at the door.",
];

const _privacyLine =
    'Nothing leaves your phone. Nothing is saved between sessions.';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          const CrisisHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_heading, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  for (final example in _examples)
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          example,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _privacyLine,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  // TODO(deferred): gate Begin on model-load splash
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(onboardedProvider.notifier)
                          .markComplete();
                      if (context.mounted) context.go('/home');
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('Begin'),
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
