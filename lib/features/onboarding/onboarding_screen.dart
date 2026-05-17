import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';
import 'onboarding_state.dart';

// Lead-owned copy. Approved 2026-05-17 for the paged onboarding redesign.
// Do not reword without asking the project lead.
const _whatHeading = 'For the moments no one prepared you for';
const _whatBody =
    'Caring for someone with dementia brings thoughts that are hard to say '
    'out loud. Write one down here and be met with understanding — not '
    'advice, not fixing. About five minutes.';

const _examplesHeading = 'Other caregivers come here with things like this';
const _examples = [
  'snapped at mom again',
  'relieved when he was hospitalized',
  'wished it would end',
  'froze when she hit me',
  "couldn't go in this morning",
];

const _privacyHeading = 'What you write stays with you';
const _privacyBody =
    'It runs entirely on your phone, with no internet. Nothing is sent '
    'anywhere, no account, no cloud.';
const _privacyLine =
    'Nothing leaves your phone. Nothing is saved between sessions.';

const _readyHeading = 'Ready when you are';

const _pageCount = 4;

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

  bool get _isLast => _page == _pageCount - 1;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _begin() async {
    await ref.read(onboardedProvider.notifier).markComplete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CrisisHeader(),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [
                _WhatPage(),
                _ExamplesPage(),
                _PrivacyPage(),
                _ReadyPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dots(count: _pageCount, active: _page),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isLast ? _begin : _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    minimumSize: const Size.fromHeight(0),
                  ),
                  child: Text(_isLast ? 'Begin' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: child,
    );
  }
}

class _WhatPage extends StatelessWidget {
  const _WhatPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(_whatHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text(_whatBody, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ExamplesPage extends StatelessWidget {
  const _ExamplesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(_examplesHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final example in _examples) _ExampleBubble(example),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleBubble extends StatelessWidget {
  const _ExampleBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(_privacyHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text(_privacyBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _privacyLine,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          Text(
            _readyHeading,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: i == active ? 24 : 8,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
