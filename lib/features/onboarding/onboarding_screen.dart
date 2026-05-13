import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'onboarding_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardedProvider.notifier).markComplete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _PrivacyCard(),
                  const _PurposeCard(),
                  _CrisisCard(onContinue: _finish),
                ],
              ),
            ),
            _PageDots(count: 3, current: _page),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      child: Text(
        'Everything you type stays on this phone. There is no account, no email, no upload. You can wipe it any time.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      child: Text(
        "This is not therapy and not a chatbot. It's a structured tool for short decompression moments. 3 to 15 minutes.",
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CrisisCard extends StatelessWidget {
  const _CrisisCard({required this.onContinue});

  final Future<void> Function() onContinue;

  Future<void> _call(String number) async {
    await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "If you're in crisis, here are people who can help right now.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: "Call Alzheimer's Association, 1-800-272-3900",
            child: FilledButton(
              onPressed: () => _call('18002723900'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text("Call Alzheimer's Association: 1-800-272-3900"),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Call 988, U S Suicide and Crisis Lifeline',
            child: FilledButton(
              onPressed: () => _call('988'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text('Call 988 (US Suicide & Crisis Lifeline)'),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: onContinue,
            child: Text(
              'Continue to app',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyLarge,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
